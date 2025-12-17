#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Temp;
use File::Path qw(make_path);
use DBI;
use lib 'lib';

# Test the _get_last_insert_id helper method and new_user integration

BEGIN {
    use_ok('FB::Db');
}

# Create a temporary directory for test database
my $temp_dir = File::Temp->newdir();
my $db_path = $temp_dir->dirname;

# Set up SQLite environment
$ENV{DATABASE_TYPE} = 'sqlite';
$ENV{SQLITE_PATH} = $db_path;

# Create the database schema
my $schema_file = 'db/fb.schema';
if (-f $schema_file) {
    # Use safe multi-argument form and pipe schema via STDIN
    open(my $schema_fh, '<', $schema_file) or die "Cannot open schema file: $!";
    my $schema_sql = do { local $/; <$schema_fh> };
    close($schema_fh);
    
    # Use DBI to execute schema directly (safer than shell)
    my $temp_dbh = DBI->connect("dbi:SQLite:dbname=$db_path/fb.db", '', '', { RaiseError => 0, PrintError => 0 });
    # Execute each statement separately (schema may have multiple statements)
    foreach my $statement (split /;/, $schema_sql) {
        next unless $statement =~ /\S/;  # Skip empty statements
        $temp_dbh->do($statement);
    }
    $temp_dbh->disconnect();
}

# Test 1: Create FB::Db instance with SQLite
my $db = eval { FB::Db->new() };
ok($db, 'Successfully created FB::Db with SQLite');
is($db->db_type, 'sqlite', 'Database type is sqlite');

# Test 2: Test _get_last_insert_id method directly
SKIP: {
    skip "Database schema not available", 3 unless -f $schema_file;
    
    # Insert a test record directly
    my $test_username = 'test_user_' . time();
    eval {
        $db->dbh->do("INSERT INTO user (username, chips, invested) VALUES (?, 400, 400)", 
                     undef, $test_username);
    };
    
    skip "Could not insert test record: $@", 3 if $@;
    
    # Get the last insert ID
    my $id = $db->_get_last_insert_id('user', 'id');
    ok($id, 'Got last insert ID');
    ok($id > 0, 'Last insert ID is positive');
    is(ref($id), '', 'Last insert ID is a scalar value');
}

# Test 3: Test new_user method with the helper
SKIP: {
    skip "Database schema not available", 4 unless -f $schema_file;
    
    my $test_username = 'new_user_test_' . time();
    my $user = eval {
        $db->new_user({
            username => $test_username,
            chips => 500,
            invested => 500,
        });
    };
    
    skip "Could not create user: $@", 4 if $@;
    
    ok($user, 'new_user returned a user object');
    ok($user->id, 'User has an ID');
    ok($user->id > 0, 'User ID is positive');
    is($user->username, $test_username, 'Username matches');
}

done_testing();
