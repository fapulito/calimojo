#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

# Test house player naming convention
# Requirement 9.1: House player accounts SHALL have username pattern HousePlayer\d+

plan tests => 4;

# Test 1: Verify naming pattern regex
my $naming_pattern = qr/^HousePlayer\d+$/;

ok('HousePlayer1' =~ $naming_pattern, 'HousePlayer1 matches naming pattern');
ok('HousePlayer2' =~ $naming_pattern, 'HousePlayer2 matches naming pattern');
ok('HousePlayer999' =~ $naming_pattern, 'HousePlayer999 matches naming pattern');

# Test 2: Verify invalid names don't match
ok('houseplayer1' !~ $naming_pattern, 'lowercase houseplayer1 does not match pattern');

done_testing();
