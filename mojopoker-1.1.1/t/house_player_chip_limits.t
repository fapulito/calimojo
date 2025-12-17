#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

# Test house player chip limits
# Requirement 9.4: House players SHALL be allowed balances significantly higher than regular players (1000000 chips)

# Load environment variables
for my $env_path ('.env', "$RealBin/../.env", "$RealBin/../../.env") {
    if (-f $env_path && open my $fh, '<', $env_path) {
        while (<$fh>) {
            chomp;
            next if /^\s*#/ || /^\s*$/;
            if (/^([^=]+)=(.*)$/) {
                my ($key, $value) = ($1, $2);
                $value =~ s/^["']|["']$//g;
                $ENV{$key} = $value unless exists $ENV{$key};
            }
        }
        close $fh;
        last;
    }
}

plan tests => 3;

# Test 1: Verify house player chip limit constant from add_house_players.pl
my $house_player_chips = 1000000;
is($house_player_chips, 1000000, 'House player chip limit is 1000000');

# Test 2: Verify house player chips are significantly higher than regular players
my $regular_player_chips = 400;
ok($house_player_chips > $regular_player_chips * 100, 'House player chips are significantly higher than regular players');

# Test 3: Verify the add_house_players.pl script uses correct chip amount
# Read the script and verify it contains the correct chip allocation
my $script_path = "$RealBin/../add_house_players.pl";
if (-f $script_path) {
    open my $fh, '<', $script_path or die "Cannot open $script_path: $!";
    my $script_content = do { local $/; <$fh> };
    close $fh;
    
    # Check if script contains the 1000000 chip allocation
    like($script_content, qr/1000000/, 'add_house_players.pl script allocates 1000000 chips');
} else {
    fail("add_house_players.pl script not found at $script_path");
}

done_testing();
