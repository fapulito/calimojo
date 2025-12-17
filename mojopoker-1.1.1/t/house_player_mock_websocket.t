#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use FB::Login::WebSocket::Mock;

# Test mock WebSocket usage for house players
# Requirement 9.2: House players SHALL use mock WebSocket connections
# Requirement 9.3: Mock WebSocket send() SHALL not transmit network data

plan tests => 6;

# Test 1: Create mock WebSocket
my $mock_ws = FB::Login::WebSocket::Mock->new(
    remote_address => '127.0.0.1'
);

isa_ok($mock_ws, 'FB::Login::WebSocket::Mock', 'Mock WebSocket created');

# Test 2: Verify remote_address
is($mock_ws->remote_address, '127.0.0.1', 'Mock WebSocket has correct remote address');

# Test 3: Verify connection returns an ID
ok($mock_ws->connection, 'Mock WebSocket has connection ID');

# Test 4: Verify send() doesn't transmit (returns success without error)
my $result = $mock_ws->send(['test_message', { data => 'test' }]);
ok($result, 'Mock WebSocket send() returns success');

# Test 5: Verify is_websocket returns true
ok($mock_ws->is_websocket, 'Mock WebSocket identifies as WebSocket');

# Test 6: Verify is_finished returns false (house players never disconnect)
ok(!$mock_ws->is_finished, 'Mock WebSocket is never finished');

done_testing();
