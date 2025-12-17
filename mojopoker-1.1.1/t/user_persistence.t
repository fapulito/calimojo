#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use FindBin;
use lib "$FindBin::Bin/../lib";

# Skip tests if no PostgreSQL is available
plan skip_all => 'PostgreSQL tests require DB environment variables' 
    unless $ENV{DB_HOST} && $ENV{DB_USER} && $ENV{DB_PASSWORD};

use FB::Db;
use FB::User;
use FB;
use FB::Login::WebSocket::Mock;

# Test: 9.1 Verify returning user retrieval
# Requirements: 7.1, 7.2
subtest 'Returning user retrieval' => sub {
    my $db = FB::Db->new;
    
    # Create a test user with facebook_id
    my $test_facebook_id = 'test_fb_' . time() . '_' . $$;
    my $initial_chips = 1500;
    
    my $user = $db->new_user({
        facebook_id => $test_facebook_id,
        username => 'test_user_' . time(),
        chips => $initial_chips,
        invested => 400,
    });
    
    ok($user, 'Test user created');
    ok($user->id, 'User has ID');
    is($user->facebook_id, $test_facebook_id, 'Facebook ID set correctly');
    
    # Requirement 7.1: fetch_user returns existing user by facebook_id
    my $fetched_user = $db->fetch_user({ facebook_id => $test_facebook_id });
    
    ok($fetched_user, 'User fetched by facebook_id');
    isa_ok($fetched_user, 'FB::User', 'Fetched object is FB::User');
    is($fetched_user->id, $user->id, 'User ID matches');
    is($fetched_user->facebook_id, $test_facebook_id, 'Facebook ID preserved');
    
    # Requirement 7.2: Chip balance is preserved
    my $chips = $db->fetch_chips($fetched_user->id);
    is($chips, $initial_chips, 'Chip balance preserved');
    
    # Test multiple fetches return same user
    my $fetched_again = $db->fetch_user({ facebook_id => $test_facebook_id });
    is($fetched_again->id, $user->id, 'Multiple fetches return same user');
    
    # Cleanup
    $db->dbh->do('DELETE FROM users WHERE id = ?', undef, $user->id);
};

# Test: 9.3 Verify logout persistence
# Requirements: 7.3
subtest 'Logout persistence' => sub {
    my $db = FB::Db->new;
    
    # Create a test user
    my $test_facebook_id = 'test_fb_logout_' . time() . '_' . $$;
    my $initial_chips = 2000;
    
    my $user = $db->new_user({
        facebook_id => $test_facebook_id,
        username => 'test_logout_user_' . time(),
        chips => $initial_chips,
        invested => 400,
    });
    
    ok($user, 'Test user created for logout test');
    
    # Simulate chip changes during gameplay
    my $new_chips = 2500;
    $db->credit_chips($user->id, 500);
    
    # Verify chips were updated
    my $chips_after_credit = $db->fetch_chips($user->id);
    is($chips_after_credit, $new_chips, 'Chips credited correctly');
    
    # Requirement 7.3: update_user saves chips and last_visit on logout
    my $before_update_time = time();
    my $update_result = $db->update_user({
        chips => $new_chips,
    }, $user->id);
    
    ok($update_result, 'update_user succeeded');
    
    # Fetch user again to verify persistence
    my $fetched_user = $db->fetch_user({ facebook_id => $test_facebook_id });
    my $final_chips = $db->fetch_chips($fetched_user->id);
    is($final_chips, $new_chips, 'Chips persisted after update_user');
    
    # Verify last_visit was updated
    ok($fetched_user->last_visit >= $before_update_time, 'last_visit updated on logout');
    
    # Cleanup
    $db->dbh->do('DELETE FROM users WHERE id = ?', undef, $user->id);
};

# Test: 9.4 Verify game reconnection
# Requirements: 7.4
subtest 'Game reconnection' => sub {
    TODO: {
        local $TODO = 'Integration test requires full table/game infrastructure';
        
        # This test requires:
        # 1. Create a poker table with FB->table_maker->ring_table()
        # 2. Create a user and login with FB::Login::WebSocket::Mock
        # 3. Seat the player at the table with chips
        # 4. Record initial state: chair position, chip count
        # 5. Simulate disconnect by clearing player->login reference
        # 6. Call FB::Poker::watch_table() to reconnect
        # 7. Assert:
        #    - chair->player->login is restored
        #    - chair->chips unchanged
        #    - table_snap and player_snap messages sent
        #
        # Code review confirms FB::Poker::watch_table (FB/Poker.pm):
        # - Finds existing chairs via _find_chairs($login)
        # - Clears temporary flags (check_fold, stand_flag)
        # - Restores player->login reference
        # - Sends table_snap and player_snap to restore game state
        
        fail('TODO: Implement full integration test for watch_table reconnection');
        fail('TODO: Verify seat position preserved after reconnect');
        fail('TODO: Verify chip stack preserved after reconnect');
        fail('TODO: Verify table_snap and player_snap sent on reconnect');
    }
};

done_testing();
