#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Temp;
use FindBin;
use lib "$FindBin::Bin/../lib";

# Test timestamp handling for both SQLite and PostgreSQL

# Test SQLite timestamp handling
{
    # Create temporary database
    my $temp_dir = File::Temp->newdir();
    my $db_path = $temp_dir->dirname;
    
    $ENV{DATABASE_TYPE} = 'sqlite';
    $ENV{SQLITE_PATH} = $db_path;
    delete $ENV{VALIDATE_SCHEMA};
    
    # Create database schema
    require DBI;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$db_path/fb.db", '', '', {
        RaiseError => 1,
        AutoCommit => 1,
    });
    
    $dbh->do(q{
        CREATE TABLE user (
            id INTEGER PRIMARY KEY NOT NULL,
            username VARCHAR(255),
            chips INTEGER DEFAULT 400,
            invested INTEGER DEFAULT 400,
            reg_date INTEGER,
            last_visit INTEGER,
            facebook_deleted INTEGER
        )
    });
    
    require FB::Db;
    my $db = FB::Db->new();
    
    ok($db, 'Created FB::Db with SQLite');
    is($db->db_type, 'sqlite', 'Database type is sqlite');
    
    # Test _format_timestamp for SQLite
    my $unix_time = 1734480000; # 2024-12-18 00:00:00 UTC
    my $formatted = $db->_format_timestamp($unix_time);
    is($formatted, $unix_time, 'SQLite timestamp formatted as Unix timestamp');
    ok($formatted =~ /^\d+$/, 'SQLite timestamp is an integer');
    
    # Test _parse_timestamp for SQLite
    my $parsed = $db->_parse_timestamp($unix_time);
    is($parsed, $unix_time, 'SQLite timestamp parsed correctly');
    
    # Test new_user with timestamp
    my $user = $db->new_user({
        username => 'testuser',
        chips => 500,
        invested => 500,
    });
    
    ok($user, 'Created new user');
    ok($user->id, 'User has ID');
    ok($user->reg_date, 'User has reg_date');
    ok($user->last_visit, 'User has last_visit');
    ok($user->reg_date =~ /^\d+$/, 'reg_date is Unix timestamp');
    ok($user->last_visit =~ /^\d+$/, 'last_visit is Unix timestamp');
    
    # Verify timestamp was stored correctly in database
    my $sth = $dbh->prepare('SELECT reg_date, last_visit FROM user WHERE id = ?');
    $sth->execute($user->id);
    my ($db_reg_date, $db_last_visit) = $sth->fetchrow_array;
    
    ok($db_reg_date =~ /^\d+$/, 'Database reg_date is integer');
    ok($db_last_visit =~ /^\d+$/, 'Database last_visit is integer');
    
    # Test fetch_user with timestamp parsing
    my $fetched_user = $db->fetch_user({ id => $user->id });
    ok($fetched_user, 'Fetched user');
    is($fetched_user->id, $user->id, 'Fetched correct user');
    ok($fetched_user->reg_date =~ /^\d+$/, 'Fetched reg_date is Unix timestamp');
    ok($fetched_user->last_visit =~ /^\d+$/, 'Fetched last_visit is Unix timestamp');
    
    # Test update_user with timestamp
    my $before_update = time();
    sleep 1; # Ensure timestamp changes
    my $result = $db->update_user({ chips => 600 }, $user->id);
    ok($result, 'Updated user');
    
    # Verify last_visit was updated
    $fetched_user = $db->fetch_user({ id => $user->id });
    ok($fetched_user->last_visit >= $before_update, 'last_visit updated');
    ok($fetched_user->last_visit =~ /^\d+$/, 'Updated last_visit is Unix timestamp');
    
    # Verify timestamp was stored correctly in database
    $sth = $dbh->prepare('SELECT last_visit FROM user WHERE id = ?');
    $sth->execute($user->id);
    ($db_last_visit) = $sth->fetchrow_array;
    ok($db_last_visit =~ /^\d+$/, 'Database last_visit is integer after update');
}

# Test PostgreSQL timestamp handling (if available)
SKIP: {
    skip "PostgreSQL tests require DB environment variables", 20 unless (
        $ENV{DB_HOST} && $ENV{DB_USER} && $ENV{DB_PASSWORD}
    ) || $ENV{DATABASE_URL};
    
    $ENV{DATABASE_TYPE} = 'postgres';
    delete $ENV{SQLITE_PATH};
    delete $ENV{VALIDATE_SCHEMA};
    
    require FB::Db;
    my $db = eval { FB::Db->new() };
    
    skip "PostgreSQL connection failed: $@", 20 if $@;
    
    ok($db, 'Created FB::Db with PostgreSQL');
    is($db->db_type, 'postgres', 'Database type is postgres');
    
    # Test _format_timestamp for PostgreSQL
    my $unix_time = 1734480000; # 2024-12-18 00:00:00 UTC
    my $formatted = $db->_format_timestamp($unix_time);
    like($formatted, qr/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/, 
         'PostgreSQL timestamp formatted as ISO 8601');
    is($formatted, '2024-12-18 00:00:00', 'PostgreSQL timestamp correct value');
    
    # Test _parse_timestamp for PostgreSQL
    my $parsed = $db->_parse_timestamp('2024-12-18 00:00:00');
    is($parsed, $unix_time, 'PostgreSQL timestamp parsed to Unix timestamp');
    
    # Test that already-Unix timestamps are preserved
    my $parsed_unix = $db->_parse_timestamp($unix_time);
    is($parsed_unix, $unix_time, 'PostgreSQL preserves Unix timestamps');
    
    # Create test table if it doesn't exist
    eval {
        $db->dbh->do(q{
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                username VARCHAR(255),
                chips INTEGER DEFAULT 400,
                invested INTEGER DEFAULT 400,
                reg_date TIMESTAMP,
                last_visit TIMESTAMP,
                facebook_deleted TIMESTAMP,
                bookmark VARCHAR(40)
            )
        });
    };
    
    # Test new_user with timestamp
    my $user = $db->new_user({
        username => 'testuser_pg_' . time(),
        chips => 500,
        invested => 500,
    });
    
    ok($user, 'Created new user in PostgreSQL');
    ok($user->id, 'User has ID');
    ok($user->reg_date, 'User has reg_date');
    ok($user->last_visit, 'User has last_visit');
    ok($user->reg_date =~ /^\d+$/, 'reg_date is Unix timestamp in application');
    ok($user->last_visit =~ /^\d+$/, 'last_visit is Unix timestamp in application');
    
    # Verify timestamp was stored as TIMESTAMP in database
    my $sth = $db->dbh->prepare('SELECT reg_date, last_visit FROM users WHERE id = ?');
    $sth->execute($user->id);
    my ($db_reg_date, $db_last_visit) = $sth->fetchrow_array;
    
    like($db_reg_date, qr/^\d{4}-\d{2}-\d{2}/, 'Database reg_date is TIMESTAMP format');
    like($db_last_visit, qr/^\d{4}-\d{2}-\d{2}/, 'Database last_visit is TIMESTAMP format');
    
    # Test fetch_user with timestamp parsing
    my $fetched_user = $db->fetch_user({ id => $user->id });
    ok($fetched_user, 'Fetched user from PostgreSQL');
    is($fetched_user->id, $user->id, 'Fetched correct user');
    ok($fetched_user->reg_date =~ /^\d+$/, 'Fetched reg_date is Unix timestamp');
    ok($fetched_user->last_visit =~ /^\d+$/, 'Fetched last_visit is Unix timestamp');
    
    # Test update_user with timestamp
    my $before_update = time();
    sleep 1; # Ensure timestamp changes
    my $result = $db->update_user({ chips => 600 }, $user->id);
    ok($result, 'Updated user in PostgreSQL');
    
    # Verify last_visit was updated
    $fetched_user = $db->fetch_user({ id => $user->id });
    ok($fetched_user->last_visit >= $before_update, 'last_visit updated in PostgreSQL');
    
    # Cleanup
    eval {
        $db->dbh->do('DELETE FROM users WHERE id = ?', undef, $user->id);
    };
}

done_testing();
