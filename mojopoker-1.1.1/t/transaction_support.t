#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Temp;
use File::Path qw(make_path);
use DBI;
use lib 'lib';

# Test transaction support
# Requirements: 3.5

# Setup: Create a temporary database for testing
my $temp_dir = File::Temp->newdir();
local $ENV{DATABASE_TYPE} = 'sqlite';
local $ENV{SQLITE_PATH} = $temp_dir->dirname;

# Create the database schema (safe method without shell injection)
my $db_file = $temp_dir->dirname . '/fb.db';
my $schema_file = 'db/fb.schema';
if (-f $schema_file) {
    open(my $schema_fh, '<', $schema_file) or die "Cannot open schema file: $!";
    my $schema_sql = do { local $/; <$schema_fh> };
    close($schema_fh);
    
    my $temp_dbh = DBI->connect("dbi:SQLite:dbname=$db_file", '', '', { RaiseError => 0, PrintError => 0 });
    # Execute each statement separately (schema may have multiple statements)
    foreach my $statement (split /;/, $schema_sql) {
        next unless $statement =~ /\S/;  # Skip empty statements
        $temp_dbh->do($statement);
    }
    $temp_dbh->disconnect();
}

require FB::Db;

# Test 1: Begin transaction
{
    my $db = FB::Db->new();
    ok($db, 'Created FB::Db instance');
    
    # Initially AutoCommit should be on
    ok($db->dbh->{AutoCommit}, 'AutoCommit is initially enabled');
    
    # Begin transaction
    my $result = $db->begin_transaction();
    ok($result, 'begin_transaction returns success');
    ok(!$db->dbh->{AutoCommit}, 'AutoCommit is disabled after begin_transaction');
    
    # Cleanup
    $db->rollback_transaction();
}

# Test 2: Commit transaction
{
    my $db = FB::Db->new();
    
    # Begin transaction
    $db->begin_transaction();
    
    # Insert a test user
    my $user = $db->new_user({
        username => 'test_commit_user',
        password => 'test123',
        email => 'commit@test.com',
        chips => 1000,
        invested => 1000,
    });
    
    ok($user, 'Created user within transaction');
    
    # Commit transaction
    my $result = $db->commit_transaction();
    ok($result, 'commit_transaction returns success');
    ok($db->dbh->{AutoCommit}, 'AutoCommit is re-enabled after commit');
    
    # Verify user was persisted
    my $fetched_user = $db->fetch_user({ username => 'test_commit_user' });
    ok($fetched_user, 'User persisted after commit');
    is($fetched_user->username, 'test_commit_user', 'User data is correct');
}

# Test 3: Rollback transaction
{
    my $db = FB::Db->new();
    
    # Begin transaction
    $db->begin_transaction();
    
    # Insert a test user
    my $user = $db->new_user({
        username => 'test_rollback_user',
        password => 'test123',
        email => 'rollback@test.com',
        chips => 1000,
        invested => 1000,
    });
    
    ok($user, 'Created user within transaction');
    
    # Rollback transaction
    my $result = $db->rollback_transaction();
    ok($result, 'rollback_transaction returns success');
    ok($db->dbh->{AutoCommit}, 'AutoCommit is re-enabled after rollback');
    
    # Verify user was NOT persisted
    my $fetched_user = $db->fetch_user({ username => 'test_rollback_user' });
    ok(!$fetched_user, 'User not persisted after rollback');
}

# Test 4: Multiple operations in transaction
{
    my $db = FB::Db->new();
    
    # Create initial user
    my $user1 = $db->new_user({
        username => 'multi_op_user1',
        password => 'test123',
        email => 'multi1@test.com',
        chips => 1000,
        invested => 1000,
    });
    
    # Begin transaction
    $db->begin_transaction();
    
    # Perform multiple operations
    $db->debit_chips($user1->id, 500);
    
    my $user2 = $db->new_user({
        username => 'multi_op_user2',
        password => 'test123',
        email => 'multi2@test.com',
        chips => 500,
        invested => 500,
    });
    
    # Commit
    $db->commit_transaction();
    
    # Verify both operations persisted
    my $chips = $db->fetch_chips($user1->id);
    is($chips, 500, 'Chip debit persisted');
    
    my $fetched_user2 = $db->fetch_user({ username => 'multi_op_user2' });
    ok($fetched_user2, 'Second user persisted');
}

# Test 5: Rollback multiple operations
{
    my $db = FB::Db->new();
    
    # Create initial user
    my $user1 = $db->new_user({
        username => 'rollback_multi_user1',
        password => 'test123',
        email => 'rollback1@test.com',
        chips => 1000,
        invested => 1000,
    });
    
    my $initial_chips = $db->fetch_chips($user1->id);
    
    # Begin transaction
    $db->begin_transaction();
    
    # Perform multiple operations
    $db->debit_chips($user1->id, 500);
    
    my $user2 = $db->new_user({
        username => 'rollback_multi_user2',
        password => 'test123',
        email => 'rollback2@test.com',
        chips => 500,
        invested => 500,
    });
    
    # Rollback
    $db->rollback_transaction();
    
    # Verify operations were rolled back
    my $chips = $db->fetch_chips($user1->id);
    is($chips, $initial_chips, 'Chip debit rolled back');
    
    my $fetched_user2 = $db->fetch_user({ username => 'rollback_multi_user2' });
    ok(!$fetched_user2, 'Second user not persisted after rollback');
}

# Test 6: Nested transaction warning
{
    my $db = FB::Db->new();
    
    # Begin first transaction
    $db->begin_transaction();
    
    # Try to begin another transaction (should warn)
    my $result = $db->begin_transaction();
    ok(!$result, 'begin_transaction returns false when transaction already in progress');
    
    # Cleanup
    $db->rollback_transaction();
}

# Test 7: Commit without transaction warning
{
    my $db = FB::Db->new();
    
    # Try to commit without beginning transaction
    my $result = $db->commit_transaction();
    ok(!$result, 'commit_transaction returns false when no transaction in progress');
}

# Test 8: Rollback without transaction warning
{
    my $db = FB::Db->new();
    
    # Try to rollback without beginning transaction
    my $result = $db->rollback_transaction();
    ok(!$result, 'rollback_transaction returns false when no transaction in progress');
}

done_testing();
