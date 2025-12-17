#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Temp;
use File::Path qw(make_path remove_tree);
use lib 'lib';

# Test SQLite connection builder
# Requirements: 1.3, 1.4, 6.2, 6.4, 1.5, 4.3

# Test 1: Connect to SQLite with default path
{
    local $ENV{DATABASE_TYPE} = 'sqlite';
    local $ENV{SQLITE_PATH} = './db';
    
    # Ensure db directory exists
    make_path('./db') unless -d './db';
    
    require FB::Db;
    my $db = eval { FB::Db->new() };
    
    ok($db, 'Successfully created FB::Db with SQLite');
    ok($db->dbh, 'Database handle created');
    is($db->db_type, 'sqlite', 'Database type is sqlite');
    
    # Test that foreign keys are enabled
    my $fk_result = $db->dbh->selectrow_arrayref('PRAGMA foreign_keys');
    is($fk_result->[0], 1, 'Foreign keys are enabled');
    
    # Test that WAL mode is enabled
    my $wal_result = $db->dbh->selectrow_arrayref('PRAGMA journal_mode');
    is($wal_result->[0], 'wal', 'WAL mode is enabled');
}

# Test 2: Connect to SQLite with custom path
{
    my $temp_dir = File::Temp->newdir();
    local $ENV{DATABASE_TYPE} = 'sqlite';
    local $ENV{SQLITE_PATH} = $temp_dir->dirname;
    
    require FB::Db;
    my $db = eval { FB::Db->new() };
    
    ok($db, 'Successfully created FB::Db with custom SQLite path');
    ok($db->dbh, 'Database handle created with custom path');
    ok(-f $temp_dir->dirname . '/fb.db', 'Database file created at custom path');
}

# Test 3: Error when directory does not exist
{
    local $ENV{DATABASE_TYPE} = 'sqlite';
    local $ENV{SQLITE_PATH} = '/nonexistent/path/that/does/not/exist';
    
    require FB::Db;
    my $db = eval { FB::Db->new() };
    
    ok(!$db, 'Failed to create FB::Db with nonexistent directory');
    like($@, qr/SQLite database directory does not exist/, 'Error message mentions directory does not exist');
    like($@, qr/nonexistent/, 'Error message includes the path');
}

# Test 4: Error when directory is not writable (skip on Windows)
SKIP: {
    skip "Permission tests not reliable on Windows", 1 if $^O eq 'MSWin32';
    
    my $temp_dir = File::Temp->newdir();
    chmod 0555, $temp_dir->dirname;  # Read-only
    
    local $ENV{DATABASE_TYPE} = 'sqlite';
    local $ENV{SQLITE_PATH} = $temp_dir->dirname;
    
    require FB::Db;
    my $db = eval { FB::Db->new() };
    
    ok(!$db, 'Failed to create FB::Db with non-writable directory');
    like($@, qr/not writable/, 'Error message mentions directory is not writable');
    
    chmod 0755, $temp_dir->dirname;  # Restore permissions for cleanup
}

done_testing();
