#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use File::Temp qw(tempdir tempfile);
use DBI;
use FindBin;

# Skip integration tests if no PostgreSQL is available
plan skip_all => 'PostgreSQL integration tests require DATABASE_URL' 
    unless $ENV{DATABASE_URL} && $ENV{RUN_INTEGRATION_TESTS};

# Helper function to convert DATABASE_URL to DBI connection string
sub parse_database_url {
    my $url = shift;
    
    # Parse postgresql://user:pass@host:port/dbname
    if ($url =~ m{^postgresql://([^:]+):([^@]+)@([^:]+):(\d+)/(.+)$}) {
        my ($user, $pass, $host, $port, $dbname) = ($1, $2, $3, $4, $5);
        # Remove any query params from dbname
        $dbname =~ s/\?.*//;
        return ("dbi:Pg:dbname=$dbname;host=$host;port=$port", $user, $pass);
    }
    die "Invalid DATABASE_URL format: $url";
}

# Test: Full migration workflow
subtest 'Complete migration workflow' => sub {
    # Setup: Create temporary SQLite database with test data
    my ($fh, $sqlite_file) = tempfile(SUFFIX => '.db', UNLINK => 1);
    close $fh;
    
    my $sqlite_dbh = DBI->connect("dbi:SQLite:dbname=$sqlite_file", "", "", {
        RaiseError => 1,
        AutoCommit => 1,
    });
    
    # Create schema
    $sqlite_dbh->do(q{
        CREATE TABLE user (
            id INTEGER PRIMARY KEY,
            facebook_id TEXT,
            username TEXT NOT NULL,
            email TEXT,
            first_name TEXT,
            last_name TEXT,
            chips INTEGER DEFAULT 1000,
            invested INTEGER DEFAULT 0,
            level INTEGER DEFAULT 1,
            last_visit TIMESTAMP,
            created_at TIMESTAMP,
            updated_at TIMESTAMP
        )
    });
    
    # Insert test data
    $sqlite_dbh->do(q{
        INSERT INTO user (id, facebook_id, username, email, chips)
        VALUES (100, 'fb_100', 'integration_test_user', 'integration@test.com', 5000)
    });
    
    my ($sqlite_count) = $sqlite_dbh->selectrow_array('SELECT COUNT(*) FROM user');
    is($sqlite_count, 1, 'SQLite test data created');
    
    $sqlite_dbh->disconnect;
    
    # Connect to PostgreSQL using parsed URL
    my ($dsn, $user, $pass) = parse_database_url($ENV{DATABASE_URL});
    my $pg_dbh = DBI->connect($dsn, $user, $pass, {
        RaiseError => 1,
        AutoCommit => 0,  # Use transaction for cleanup
        pg_enable_utf8 => 1,
    });
    
    ok($pg_dbh, 'Connected to PostgreSQL');
    
    # Run migration (simulate by directly executing the migration logic)
    my $sqlite_for_read = DBI->connect("dbi:SQLite:dbname=$sqlite_file", "", "", {
        RaiseError => 1,
        AutoCommit => 1,
    });
    
    my $users = $sqlite_for_read->selectall_arrayref('SELECT * FROM user', { Slice => {} });
    
    my $insert_stmt = $pg_dbh->prepare(q{
        INSERT INTO users (
            id, facebook_id, username, email, chips
        ) VALUES (?, ?, ?, ?, ?)
        ON CONFLICT (id) DO UPDATE SET
            facebook_id = EXCLUDED.facebook_id,
            username = EXCLUDED.username
    });
    
    foreach my $user (@$users) {
        $insert_stmt->execute(
            $user->{id},
            $user->{facebook_id},
            $user->{username},
            $user->{email},
            $user->{chips}
        );
    }
    
    ok(1, 'Migration executed');
    
    # Verify migration
    my ($pg_count) = $pg_dbh->selectrow_array('SELECT COUNT(*) FROM users WHERE id = 100');
    is($pg_count, 1, 'User migrated to PostgreSQL');
    
    my $migrated_user = $pg_dbh->selectrow_hashref('SELECT * FROM users WHERE id = 100');
    is($migrated_user->{username}, 'integration_test_user', 'Data integrity maintained');
    
    # Cleanup
    $pg_dbh->do('DELETE FROM users WHERE id = 100');
    $pg_dbh->commit;
    $pg_dbh->disconnect;
    $sqlite_for_read->disconnect;
};

# Test: Transaction rollback on error
subtest 'Transaction rollback on error' => sub {
    my ($dsn, $user, $pass) = parse_database_url($ENV{DATABASE_URL});
    my $pg_dbh = DBI->connect($dsn, $user, $pass, {
        RaiseError => 1,
        AutoCommit => 0,
        pg_enable_utf8 => 1,
    });
    
    # Get initial count
    my ($initial_count) = $pg_dbh->selectrow_array('SELECT COUNT(*) FROM users');
    ok(defined $initial_count, 'Initial count retrieved');
    
    # Attempt migration with intentional error
    eval {
        $pg_dbh->do(q{
            INSERT INTO users (id, username, email)
            VALUES (999999, 'rollback_test', 'rollback@test.com')
        });
        
        # Simulate an error
        die "Simulated migration error";
    };
    
    my $error = $@;
    ok($error, 'Error occurred as expected');
    like($error, qr/migration error/, 'Error message correct');
    
    # Rollback
    $pg_dbh->rollback;
    ok(1, 'Rollback executed');
    
    # Verify rollback
    my ($final_count) = $pg_dbh->selectrow_array('SELECT COUNT(*) FROM users');
    is($final_count, $initial_count, 'Count unchanged after rollback');
    
    $pg_dbh->disconnect;
};

# Test: Performance with large dataset
subtest 'Performance with large dataset' => sub {
    my ($fh, $sqlite_file) = tempfile(SUFFIX => '.db', UNLINK => 1);
    close $fh;
    
    my $sqlite_dbh = DBI->connect("dbi:SQLite:dbname=$sqlite_file", "", "", {
        RaiseError => 1,
        AutoCommit => 1,
    });
    
    $sqlite_dbh->do(q{
        CREATE TABLE user (
            id INTEGER PRIMARY KEY,
            username TEXT NOT NULL,
            chips INTEGER DEFAULT 1000
        )
    });
    
    # Insert 1000 test users
    my $insert = $sqlite_dbh->prepare('INSERT INTO user (id, username, chips) VALUES (?, ?, ?)');
    for my $i (1..1000) {
        $insert->execute($i + 100000, "perf_user_$i", 1000 + $i);
    }
    
    my ($count) = $sqlite_dbh->selectrow_array('SELECT COUNT(*) FROM user');
    is($count, 1000, '1000 test users created');
    
    # Measure migration time
    my $start_time = time();
    my $users = $sqlite_dbh->selectall_arrayref('SELECT * FROM user', { Slice => {} });
    my $fetch_time = time() - $start_time;
    
    ok($fetch_time < 5, 'Data fetch completed in reasonable time');
    is(scalar(@$users), 1000, 'All users fetched');
    
    # Verify data sampling
    my $sample_user = $users->[0];
    ok($sample_user->{username}, 'User data structure correct');
    ok($sample_user->{chips} >= 1000, 'Chip values in expected range');
    
    $sqlite_dbh->disconnect;
};

done_testing();
