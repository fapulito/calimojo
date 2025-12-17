#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";

use FB::Poker::Strategy::ActionDecider;
use FB::Poker::Strategy::Config;

# Test that multiple ActionDecider instances have independent RNG streams
# Requirement 3.4: Independent RNG per house player

subtest 'Independent RNG streams' => sub {
    my $config = FB::Poker::Strategy::Config->new;
    
    # Create two ActionDeciders with different seeds
    my $decider1 = FB::Poker::Strategy::ActionDecider->new(
        config => $config,
        rng_seed => 12345,
    );
    
    my $decider2 = FB::Poker::Strategy::ActionDecider->new(
        config => $config,
        rng_seed => 67890,
    );
    
    # Generate sequences of random numbers from each
    my @seq1 = map { $decider1->rng->() } (1..10);
    my @seq2 = map { $decider2->rng->() } (1..10);
    
    # Sequences should be different (not correlated)
    my $differences = 0;
    for my $i (0..9) {
        $differences++ if abs($seq1[$i] - $seq2[$i]) > 0.01;
    }
    
    ok($differences >= 8, "RNG sequences are independent (differ in $differences/10 positions)");
    
    # All values should be in [0, 1) range
    for my $val (@seq1, @seq2) {
        ok($val >= 0.0 && $val < 1.0, "Random value in valid range: $val");
    }
};

subtest 'Reproducible RNG with same seed' => sub {
    my $config = FB::Poker::Strategy::Config->new;
    
    # Create two ActionDeciders with the same seed
    my $decider1 = FB::Poker::Strategy::ActionDecider->new(
        config => $config,
        rng_seed => 42,
    );
    
    my $decider2 = FB::Poker::Strategy::ActionDecider->new(
        config => $config,
        rng_seed => 42,
    );
    
    # Generate sequences - they should be identical
    my @seq1 = map { $decider1->rng->() } (1..10);
    my @seq2 = map { $decider2->rng->() } (1..10);
    
    for my $i (0..9) {
        is($seq1[$i], $seq2[$i], "Same seed produces same sequence at position $i");
    }
};

subtest 'RNG does not affect global rand()' => sub {
    my $config = FB::Poker::Strategy::Config->new;
    
    # Set global RNG to known state
    srand(999);
    my $global1 = rand();
    
    # Create ActionDecider and use its RNG
    my $decider = FB::Poker::Strategy::ActionDecider->new(
        config => $config,
        rng_seed => 12345,
    );
    
    # Use the decider's RNG multiple times
    for (1..100) {
        $decider->rng->();
    }
    
    # Reset global RNG to same state
    srand(999);
    my $global2 = rand();
    
    # Global rand() should produce the same value
    is($global1, $global2, "ActionDecider RNG does not affect global rand()");
};

subtest 'Multiple house players at same table' => sub {
    my $config = FB::Poker::Strategy::Config->new;
    
    # Simulate 3 house players at a table
    my @deciders = map {
        FB::Poker::Strategy::ActionDecider->new(
            config => $config,
            rng_seed => 1000 + $_,
        )
    } (1..3);
    
    # Each makes 5 decisions
    my @sequences;
    for my $decider (@deciders) {
        push @sequences, [ map { $decider->rng->() } (1..5) ];
    }
    
    # Check that all three sequences are different
    for my $i (0..2) {
        for my $j ($i+1..2) {
            my $differences = 0;
            for my $k (0..4) {
                $differences++ if abs($sequences[$i][$k] - $sequences[$j][$k]) > 0.01;
            }
            ok($differences >= 4, "House player $i and $j have independent RNG ($differences/5 differences)");
        }
    }
};

done_testing();
