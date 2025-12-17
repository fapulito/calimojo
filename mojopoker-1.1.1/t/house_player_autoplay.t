#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';

# Test house player auto-play integration
use_ok('FB::Poker::Table');
use_ok('FB::Poker::Strategy::Manager');
use_ok('FB::Poker::Strategy::Evaluator::Holdem');
use_ok('FB::User');
use_ok('FB::Login::WebSocket::Mock');
use_ok('FB::Login::WebSocket');
use_ok('FB::Poker::Player');

# Test _is_house_player detection
subtest 'House player detection' => sub {
    # Create a mock table
    my $table = FB::Poker::Table->new(
        chair_count => 6,
        game_class => 'holdem',
    );
    
    # Test with no player
    ok(!$table->_is_house_player(0), 'Empty chair is not a house player');
    
    # Create a house player
    my $house_user = FB::User->new(
        id => 1,
        username => 'HousePlayer1',
    );
    
    my $mock_ws = FB::Login::WebSocket::Mock->new(
        remote_address => '127.0.0.1'
    );
    
    my $house_login = FB::Login::WebSocket->new({
        id => 'house1',
        websocket => $mock_ws,
    });
    $house_login->user($house_user);
    
    my $house_player = FB::Poker::Player->new(
        login => $house_login,
        chips => 200,
    );
    
    $table->sit(0, $house_player);
    
    ok($table->_is_house_player(0), 'HousePlayer1 is detected as house player');
    
    # Create a regular player
    my $regular_user = FB::User->new(
        id => 2,
        username => 'RegularPlayer',
    );
    
    my $regular_login = FB::Login::WebSocket->new({
        id => 'regular1',
        websocket => $mock_ws,
    });
    $regular_login->user($regular_user);
    
    my $regular_player = FB::Poker::Player->new(
        login => $regular_login,
        chips => 200,
    );
    
    $table->sit(1, $regular_player);
    
    ok(!$table->_is_house_player(1), 'RegularPlayer is not detected as house player');
    
    # Test edge cases
    my $house_user2 = FB::User->new(
        id => 3,
        username => 'HousePlayer99',
    );
    
    my $house_login2 = FB::Login::WebSocket->new({
        id => 'house2',
        websocket => $mock_ws,
    });
    $house_login2->user($house_user2);
    
    my $house_player2 = FB::Poker::Player->new(
        login => $house_login2,
        chips => 200,
    );
    
    $table->sit(2, $house_player2);
    
    ok($table->_is_house_player(2), 'HousePlayer99 is detected as house player');
    
    # Test non-matching pattern
    my $fake_house = FB::User->new(
        id => 4,
        username => 'HousePlayerX',
    );
    
    my $fake_login = FB::Login::WebSocket->new({
        id => 'fake1',
        websocket => $mock_ws,
    });
    $fake_login->user($fake_house);
    
    my $fake_player = FB::Poker::Player->new(
        login => $fake_login,
        chips => 200,
    );
    
    $table->sit(3, $fake_player);
    
    ok(!$table->_is_house_player(3), 'HousePlayerX does not match pattern');
};

done_testing();
