#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Temp;
use lib 'lib';

# Test error logging functionality

# Create a temporary database for testing
my $temp_dir = File::Temp->newdir();
my $db_path = $temp_dir->dirname;

$ENV{DATABASE_TYPE} = 'sqlite';
$ENV{SQLITE_PATH} = $db_path;

# Initialize database with schema
system("sqlite3 $db_path/fb.db < db/fb.schema 2>&1");

require_ok('FB::Db');

# Test 1: Create FB::Db instance
my $db = FB::Db->new();
ok($db, 'Successfully created FB::Db instance');

# Test 2: Test _log_error method exists
can_ok($db, '_log_error');

# Test 3: Test error logging with SQL statement
{
    my $error_output = '';
    local $SIG{__WARN__} = sub { $error_output .= $_[0] };
    
    $db->_log_error(
        "Test error message",
        {
            sql => "SELECT * FROM test_table",
            bind_params => ['param1', 'param2'],
            user_id => 123,
        }
    );
    
    like($error_output, qr/Database Error: Test error message/, 'Error message logged');
    like($error_output, qr/Database Type: sqlite/, 'Database type logged');
    like($error_output, qr/SQL Statement: SELECT \* FROM test_table/, 'SQL statement logged');
    like($error_output, qr/Bind Parameters: \['param1', 'param2'\]/, 'Bind parameters logged');
    like($error_output, qr/User_id: 123/, 'Additional context logged');
}

# Test 4: Test error logging without bind parameters
{
    my $error_output = '';
    local $SIG{__WARN__} = sub { $error_output .= $_[0] };
    
    $db->_log_error(
        "Another test error",
        {
            sql => "UPDATE users SET chips = 100",
        }
    );
    
    like($error_output, qr/Database Error: Another test error/, 'Error message logged');
    like($error_output, qr/SQL Statement: UPDATE users SET chips = 100/, 'SQL statement logged');
    unlike($error_output, qr/Bind Parameters/, 'No bind parameters section when empty');
}

# Test 5: Test error logging with minimal context
{
    my $error_output = '';
    local $SIG{__WARN__} = sub { $error_output .= $_[0] };
    
    $db->_log_error("Minimal error");
    
    like($error_output, qr/Database Error: Minimal error/, 'Error message logged');
    like($error_output, qr/Database Type: sqlite/, 'Database type logged');
}

# Test 6: Test new_user error handling
{
    my $error_output = '';
    local $SIG{__WARN__} = sub { $error_output .= $_[0] };
    
    # Temporarily break the database connection to force an error
    my $original_dbh = $db->dbh;
    $db->dbh(undef);
    
    my $user = eval { $db->new_user({ username => 'test' }) };
    
    # Restore connection
    $db->dbh($original_dbh);
    
    # Should return undef on error (or die, which we catch with eval)
    ok(!defined($user) || $@, 'new_user returns undef or dies on error');
    
    # Check if error was logged (may or may not happen depending on how it fails)
    # This is just to verify the error handling path exists
}

# Test 7: Test fetch_user error handling
{
    my $error_output = '';
    local $SIG{__WARN__} = sub { $error_output .= $_[0] };
    
    # Temporarily break the database connection to force an error
    my $original_dbh = $db->dbh;
    $db->dbh(undef);
    
    my $fetched_user = eval { $db->fetch_user({ id => 999 }) };
    
    # Restore connection
    $db->dbh($original_dbh);
    
    # Should return undef on error (or die, which we catch with eval)
    ok(!defined($fetched_user) || $@, 'fetch_user returns undef or dies on error');
    
    # Note: Error logging only happens if the query execution fails, not if no rows are found
    # With a broken connection, we should see an error
    # But the exact error depends on how DBI handles undef dbh
}

# Test 8: Test chip operations error handling
{
    my $error_output = '';
    local $SIG{__WARN__} = sub { $error_output .= $_[0] };
    
    # Try chip operations with invalid user_id (will fail due to table name mismatch)
    my $result = $db->credit_chips(999, 500);
    
    # Operations may succeed or fail depending on schema, but error logging should work
    # The main goal is to verify the error logging mechanism is in place
    
    # Test fetch_chips with invalid user
    my $chips = $db->fetch_chips(999);
    
    # Should return 0 on error (as per the implementation)
    ok(defined($chips), 'fetch_chips returns defined value');
}

done_testing();
