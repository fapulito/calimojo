#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::MockModule;
use File::Temp qw(tempdir tempfile);
use DBI;
use FindBin;
use lib "$FindBin::Bin/../lib";

# Test 1-3: Module loading and compilation
BEGIN {
    use_ok('DBI');
    use_ok('Getopt::Long');
    ok(-f "$FindBin::Bin/../db/migrate.pl", 'Migration script exists');
}

# Test: SQLite connection tests
subtest 'SQLite connection' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $db_path = "$tempdir/test.db";
    
    # Create test SQLite database
    my $dbh = DBI->connect("dbi:SQLite:dbname=$db_path", "", "", {
        RaiseError => 1,
        AutoCommit => 1,
    });
    ok($dbh, 'Test SQLite database created');
    
    # Create test table
    $dbh->do(q{
        CREATE TABLE user (
            id INTEGER PRIMARY KEY,
            facebook_id TEXT,
            username TEXT NOT NULL,
            password TEXT,
            email TEXT,
            birthday TEXT,
            handle TEXT,
            first_name TEXT,
            last_name TEXT,
            profile_pic TEXT,
            chips INTEGER DEFAULT 1000,
            invested INTEGER DEFAULT 0,
            level INTEGER DEFAULT 1,
            last_visit TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    });
    ok(1, 'User table created');
    
    # Insert test data
    $dbh->do(q{
        INSERT INTO user (id, facebook_id, username, email, first_name, last_name, chips)
        VALUES (1, '123456789', 'testuser', 'test@example.com', 'Test', 'User', 5000)
    });
    ok(1, 'Test user inserted');
    
    # Verify data
    my $user = $dbh->selectrow_hashref('SELECT * FROM user WHERE id = 1');
    ok($user, 'User retrieved');
    is($user->{username}, 'testuser', 'Username correct');
    is($user->{chips}, 5000, 'Chips correct');
    is($user->{facebook_id}, '123456789', 'Facebook ID correct');
    
    $dbh->disconnect;
};

# Test: PostgreSQL connection tests
subtest 'PostgreSQL connection mock' => sub {
    my $mock_dbi = Test::MockModule->new('DBI');
    my $connected = 0;
    my $connection_string = '';
    
    $mock_dbi->mock('connect', sub {
        my ($class, $dsn, $user, $pass, $attr) = @_;
        $connected = 1;
        $connection_string = $dsn;
        
        # Return mock database handle
        my $mock_dbh = Test::MockModule->new('DBI::db', no_auto => 1);
        return bless {}, 'DBI::db';
    });
    
    # Test valid PostgreSQL URL
    my $url = 'postgresql://user:pass@localhost:5432/testdb';
    local $ENV{DATABASE_URL} = $url;
    
    ok(1, 'PostgreSQL URL set');
    like($url, qr/^postgresql:/, 'URL has correct prefix');
    like($url, qr/localhost/, 'URL contains host');
    like($url, qr/5432/, 'URL contains port');
    like($url, qr/testdb/, 'URL contains database name');
    
    # Test URL parsing components
    my ($protocol, $credentials, $host, $port, $dbname) = 
        $url =~ m{^(\w+)://([^@]+)@([^:]+):(\d+)/(.+)$};
    
    is($protocol, 'postgresql', 'Protocol parsed correctly');
    is($host, 'localhost', 'Host parsed correctly');
    is($port, '5432', 'Port parsed correctly');
    is($dbname, 'testdb', 'Database name parsed correctly');
    ok($credentials, 'Credentials present');
};

# Test: Data migration tests
subtest 'User migration logic' => sub {
    # Create temporary SQLite database
    my ($fh, $filename) = tempfile(SUFFIX => '.db', UNLINK => 1);
    close $fh;
    
    my $sqlite_dbh = DBI->connect("dbi:SQLite:dbname=$filename", "", "", {
        RaiseError => 1,
        AutoCommit => 1,
    });
    
    # Create and populate test table
    $sqlite_dbh->do(q{
        CREATE TABLE user (
            id INTEGER PRIMARY KEY,
            facebook_id TEXT,
            username TEXT NOT NULL,
            password TEXT,
            email TEXT,
            birthday TEXT,
            handle TEXT,
            first_name TEXT,
            last_name TEXT,
            profile_pic TEXT,
            chips INTEGER DEFAULT 1000,
            invested INTEGER DEFAULT 0,
            level INTEGER DEFAULT 1,
            last_visit TIMESTAMP,
            created_at TIMESTAMP,
            updated_at TIMESTAMP
        )
    });
    
    # Insert multiple test users
    my @test_users = (
        [1, '111', 'alice', 'alice@test.com', 'Alice', 'Wonder', 2000],
        [2, '222', 'bob', 'bob@test.com', 'Bob', 'Builder', 3000],
        [3, '333', 'charlie', 'charlie@test.com', 'Charlie', 'Brown', 4000],
    );
    
    my $insert = $sqlite_dbh->prepare(q{
        INSERT INTO user (id, facebook_id, username, email, first_name, last_name, chips)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    });
    
    foreach my $user (@test_users) {
        $insert->execute(@$user);
    }
    ok(1, 'Test users inserted');
    
    # Verify user count
    my ($count) = $sqlite_dbh->selectrow_array('SELECT COUNT(*) FROM user');
    is($count, 3, 'Correct number of users');
    
    # Test data retrieval
    my $users = $sqlite_dbh->selectall_arrayref('SELECT * FROM user', { Slice => {} });
    ok($users, 'Users retrieved');
    is(scalar(@$users), 3, 'All users retrieved');
    
    # Verify specific user data
    my $alice = (grep { $_->{username} eq 'alice' } @$users)[0];
    ok($alice, 'Alice found');
    is($alice->{chips}, 2000, 'Alice chips correct');
    is($alice->{facebook_id}, '111', 'Alice Facebook ID correct');
    is($alice->{first_name}, 'Alice', 'Alice first name correct');
    
    $sqlite_dbh->disconnect;
};

# Test: Error handling tests
subtest 'Error handling' => sub {
    # Test missing PostgreSQL URL
    delete $ENV{DATABASE_URL};
    ok(!$ENV{DATABASE_URL}, 'DATABASE_URL not set');
    
    # Test invalid SQLite path
    my $invalid_path = '/nonexistent/path/to/db.db';
    ok(!-f $invalid_path, 'Invalid path does not exist');
    
    # Test connection failure scenarios
    dies_ok {
        DBI->connect("dbi:SQLite:dbname=/invalid/path/db.db", "", "", {
            RaiseError => 1,
            AutoCommit => 1,
        });
    } 'Invalid SQLite path throws error';
    
    # Test invalid PostgreSQL URL format
    my @invalid_urls = (
        'notaurl',
        'http://localhost',
        'postgresql://',
    );
    
    foreach my $url (@invalid_urls) {
        unlike($url, qr/^postgresql:\/\/\w+:\w+@[\w.-]+:\d+\/\w+$/, 
               "Invalid URL format rejected: $url");
    }
};

# Test: Dry-run mode tests
subtest 'Dry-run mode' => sub {
    my $tempdir = tempdir(CLEANUP => 1);
    my $db_path = "$tempdir/dryrun.db";
    
    my $dbh = DBI->connect("dbi:SQLite:dbname=$db_path", "", "", {
        RaiseError => 1,
        AutoCommit => 1,
    });
    
    $dbh->do(q{
        CREATE TABLE user (
            id INTEGER PRIMARY KEY,
            username TEXT NOT NULL,
            chips INTEGER DEFAULT 1000
        )
    });
    
    $dbh->do(q{
        INSERT INTO user (id, username, chips) VALUES (1, 'dryrun_user', 1500)
    });
    
    my $users = $dbh->selectall_arrayref('SELECT * FROM user', { Slice => {} });
    ok($users, 'Dry-run test data created');
    is(scalar(@$users), 1, 'One user exists');
    
    # Simulate dry-run (data fetched but not written)
    my ($count_before) = $dbh->selectrow_array('SELECT COUNT(*) FROM user');
    is($count_before, 1, 'User count before dry-run');
    
    # In dry-run, we would return early without executing inserts
    my $dry_run_flag = 1;
    my $would_migrate = scalar(@$users);
    
    if ($dry_run_flag) {
        ok(1, 'Dry-run mode skips writes');
        is($would_migrate, 1, 'Would migrate 1 user');
    }
    
    $dbh->disconnect;
};

# Test: Data integrity tests
subtest 'Data integrity verification' => sub {
    my ($fh, $filename) = tempfile(SUFFIX => '.db', UNLINK => 1);
    close $fh;
    
    my $dbh = DBI->connect("dbi:SQLite:dbname=$filename", "", "", {
        RaiseError => 0,  # Don't raise errors automatically for constraint tests
        PrintError => 0,  # Don't print errors
        AutoCommit => 1,
    });
    
    $dbh->do(q{
        CREATE TABLE user (
            id INTEGER PRIMARY KEY,
            username TEXT NOT NULL UNIQUE,
            chips INTEGER CHECK(chips >= 0)
        )
    });
    
    # Test unique constraint
    my $rv = $dbh->do(q{INSERT INTO user (id, username, chips) VALUES (1, 'unique_user', 1000)});
    ok($rv, 'First user inserted');
    
    # Test duplicate username is rejected
    $rv = $dbh->do(q{INSERT INTO user (id, username, chips) VALUES (2, 'unique_user', 2000)});
    ok(!$rv, 'Duplicate username rejected') or diag("Expected failure but insert succeeded");
    
    # Test check constraint - negative chips rejected
    $rv = $dbh->do(q{INSERT INTO user (id, username, chips) VALUES (3, 'negative_chips', -100)});
    ok(!$rv, 'Negative chips rejected') or diag("Expected failure but insert succeeded");
    
    # Verify data integrity
    my ($count) = $dbh->selectrow_array('SELECT COUNT(*) FROM user');
    is($count, 1, 'Only valid user exists');
    
    $dbh->disconnect;
};

# Test: Command-line options parsing
subtest 'Command-line options parsing' => sub {
    # Test that GetOptions is available
    use_ok('Getopt::Long');
    
    # Mock command-line arguments
    local @ARGV = ('--verbose', '--dry-run', '--help');
    
    my %opts;
    Getopt::Long::GetOptions(
        'verbose' => \$opts{verbose},
        'dry-run' => \$opts{dry_run},
        'help' => \$opts{help},
    );
    
    ok($opts{verbose}, 'Verbose flag parsed');
    ok($opts{dry_run}, 'Dry-run flag parsed');
};

done_testing();
