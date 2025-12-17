#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";

# Test module loading
BEGIN {
    use_ok('FB::Poker::Strategy::Config');
}

# Test default configuration
subtest 'Default configuration' => sub {
    my $config = FB::Poker::Strategy::Config->new;
    ok($config, 'Config object created');
    
    is($config->aggression, 5, 'Default aggression is 5');
    is($config->tightness, 5, 'Default tightness is 5');
    is($config->bluff_frequency, 0.10, 'Default bluff_frequency is 0.10');
    is($config->randomization_factor, 0.15, 'Default randomization_factor is 0.15');
    is($config->slow_play_threshold, 0.85, 'Default slow_play_threshold is 0.85');
    
    ok($config->validate, 'Default config is valid');
};

# Test valid configurations
subtest 'Valid configurations' => sub {
    # Test minimum valid values
    my $min_config = FB::Poker::Strategy::Config->new(
        aggression      => 1,
        tightness       => 1,
        bluff_frequency => 0.05,
    );
    ok($min_config->validate, 'Minimum valid values pass validation');
    
    # Test maximum valid values
    my $max_config = FB::Poker::Strategy::Config->new(
        aggression      => 10,
        tightness       => 10,
        bluff_frequency => 0.15,
    );
    ok($max_config->validate, 'Maximum valid values pass validation');
    
    # Test mid-range values
    my $mid_config = FB::Poker::Strategy::Config->new(
        aggression      => 7,
        tightness       => 3,
        bluff_frequency => 0.08,
    );
    ok($mid_config->validate, 'Mid-range values pass validation');
};

# Test invalid configurations
subtest 'Invalid configurations' => sub {
    # Aggression out of range
    my $low_aggression = FB::Poker::Strategy::Config->new(aggression => 0);
    ok(!$low_aggression->validate, 'Aggression below 1 fails validation');
    
    my $high_aggression = FB::Poker::Strategy::Config->new(aggression => 11);
    ok(!$high_aggression->validate, 'Aggression above 10 fails validation');
    
    # Tightness out of range
    my $low_tightness = FB::Poker::Strategy::Config->new(tightness => 0);
    ok(!$low_tightness->validate, 'Tightness below 1 fails validation');
    
    my $high_tightness = FB::Poker::Strategy::Config->new(tightness => 11);
    ok(!$high_tightness->validate, 'Tightness above 10 fails validation');
    
    # Bluff frequency out of range
    my $low_bluff = FB::Poker::Strategy::Config->new(bluff_frequency => 0.04);
    ok(!$low_bluff->validate, 'Bluff frequency below 0.05 fails validation');
    
    my $high_bluff = FB::Poker::Strategy::Config->new(bluff_frequency => 0.16);
    ok(!$high_bluff->validate, 'Bluff frequency above 0.15 fails validation');
    
    # Negative randomization factor
    my $neg_rand = FB::Poker::Strategy::Config->new(randomization_factor => -0.1);
    ok(!$neg_rand->validate, 'Negative randomization_factor fails validation');
    
    # Slow play threshold out of range
    my $low_slow = FB::Poker::Strategy::Config->new(slow_play_threshold => -0.1);
    ok(!$low_slow->validate, 'Slow play threshold below 0 fails validation');
    
    my $high_slow = FB::Poker::Strategy::Config->new(slow_play_threshold => 1.1);
    ok(!$high_slow->validate, 'Slow play threshold above 1 fails validation');
};

# Test from_hash factory method
subtest 'from_hash factory method' => sub {
    # Valid hash
    my $valid_config = FB::Poker::Strategy::Config->from_hash({
        aggression      => 7,
        tightness       => 4,
        bluff_frequency => 0.12,
    });
    ok($valid_config, 'from_hash returns config for valid params');
    is($valid_config->aggression, 7, 'Aggression set correctly');
    
    # Invalid hash
    my $invalid_config = FB::Poker::Strategy::Config->from_hash({
        aggression => 15,  # Invalid
    });
    ok(!$invalid_config, 'from_hash returns undef for invalid params');
};

# Test update method
subtest 'update method' => sub {
    my $config = FB::Poker::Strategy::Config->new;
    
    # Valid update
    ok($config->update({ aggression => 8 }), 'Valid update succeeds');
    is($config->aggression, 8, 'Aggression updated');
    
    # Invalid update should rollback
    my $old_tightness = $config->tightness;
    ok(!$config->update({ tightness => 15 }), 'Invalid update fails');
    is($config->tightness, $old_tightness, 'Tightness unchanged after failed update');
    
    # Multiple valid updates
    ok($config->update({
        aggression      => 3,
        tightness       => 7,
        bluff_frequency => 0.08,
    }), 'Multiple valid updates succeed');
    is($config->aggression, 3, 'Aggression updated');
    is($config->tightness, 7, 'Tightness updated');
    is($config->bluff_frequency, 0.08, 'Bluff frequency updated');
};

done_testing();
