#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Temp;
use lib 'lib';

# Test the _get_table_name helper method

use_ok('FB::Db');

# Test SQLite table name mapping
{
    local $ENV{DATABASE_TYPE} = 'sqlite';
    local $ENV{SQLITE_PATH} = File::Temp::tempdir(CLEANUP => 1);
    
    my $db = FB::Db->new();
    is($db->db_type, 'sqlite', 'Database type is sqlite');
    
    # Test users/user table name
    is($db->_get_table_name('users'), 'user', 'SQLite maps "users" to "user"');
    is($db->_get_table_name('user'), 'user', 'SQLite keeps "user" as "user"');
    
    # Test other table names pass through
    is($db->_get_table_name('logins'), 'logins', 'SQLite passes through other table names');
    is($db->_get_table_name('leaderboard'), 'leaderboard', 'SQLite passes through leaderboard');
}

# Test PostgreSQL table name mapping
{
    local $ENV{DATABASE_TYPE} = 'postgres';
    
    # Mock the connection to avoid needing actual PostgreSQL
    # We'll test the logic without actually connecting
    my $db = eval {
        FB::Db->new();
    };
    
    # If connection fails (expected without real DB), test the db_type at least
    if (!$db) {
        # Create a minimal object just to test the method
        $db = bless { db_type => 'postgres' }, 'FB::Db';
    }
    
    is($db->db_type, 'postgres', 'Database type is postgres');
    
    # Test users/user table name
    is($db->_get_table_name('users'), 'users', 'PostgreSQL keeps "users" as "users"');
    is($db->_get_table_name('user'), 'users', 'PostgreSQL maps "user" to "users"');
    
    # Test other table names pass through
    is($db->_get_table_name('logins'), 'logins', 'PostgreSQL passes through other table names');
    is($db->_get_table_name('leaderboard'), 'leaderboard', 'PostgreSQL passes through leaderboard');
}

done_testing();
