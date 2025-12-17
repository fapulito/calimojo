#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";

use_ok('FB::Poker::Strategy::ActionDecider');
use_ok('FB::Poker::Strategy::Config');

# Test basic instantiation
my $config = FB::Poker::Strategy::Config->new(
    aggression      => 5,
    tightness       => 5,
    bluff_frequency => 0.10,
);

my $decider = FB::Poker::Strategy::ActionDecider->new(
    config   => $config,
    rng_seed => 12345,  # Fixed seed for reproducibility
);

isa_ok($decider, 'FB::Poker::Strategy::ActionDecider');
ok($decider->config, 'Config is set');
ok($decider->rng_seed, 'RNG seed is set');

# Test calculate_bet_amount with bounds checking
{
    my $amount = $decider->calculate_bet_amount(0.8, 100, 10, 200);
    ok($amount >= 10 && $amount <= 200, "Bet amount within bounds: $amount");
    
    # Test min bound
    my $min_amount = $decider->calculate_bet_amount(0.1, 5, 50, 100);
    is($min_amount, 50, "Bet amount respects minimum");
    
    # Test max bound
    my $max_amount = $decider->calculate_bet_amount(1.0, 10000, 10, 100);
    is($max_amount, 100, "Bet amount respects maximum");
}

# Test should_bluff
{
    my $bluff_count = 0;
    for (1..100) {
        $bluff_count++ if $decider->should_bluff(0.5);
    }
    # Should be roughly 10-15% (pot odds adjustment increases frequency)
    # With pot_odds=0.5, adjusted frequency is ~15%
    ok($bluff_count >= 5 && $bluff_count <= 25, 
       "Bluff frequency in expected range: $bluff_count/100");
}

# Test decide method with valid actions
{
    my $game_state = {
        pot_size      => 100,
        call_amount   => 0,
        valid_actions => ['check', 'bet', 'fold'],
        min_bet       => 10,
        max_bet       => 200,
        betting_round => 1,
    };
    
    # Strong hand should bet or check
    my $decision = $decider->decide(0.9, $game_state);
    ok($decision->{action}, "Decision has action");
    ok(grep { $_ eq $decision->{action} } @{$game_state->{valid_actions}},
       "Action is valid: $decision->{action}");
    
    # Weak hand should check or fold
    $decision = $decider->decide(0.1, $game_state);
    ok(grep { $_ eq $decision->{action} } @{$game_state->{valid_actions}},
       "Weak hand action is valid: $decision->{action}");
}

# Test with call required
{
    my $game_state = {
        pot_size      => 100,
        call_amount   => 20,
        valid_actions => ['call', 'raise', 'fold'],
        min_bet       => 10,
        max_bet       => 200,
        betting_round => 2,
    };
    
    my $decision = $decider->decide(0.7, $game_state);
    ok(grep { $_ eq $decision->{action} } @{$game_state->{valid_actions}},
       "Action with call required is valid: $decision->{action}");
}

done_testing();
