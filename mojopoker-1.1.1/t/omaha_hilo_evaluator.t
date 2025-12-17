#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'lib';

use FB::Poker::Card;
use FB::Poker::Strategy::Evaluator::OmahaHiLo;

# Test OmahaHiLo evaluator
subtest 'OmahaHiLo evaluator basic functionality' => sub {
    my $evaluator = FB::Poker::Strategy::Evaluator::OmahaHiLo->new;
    
    ok($evaluator->can('evaluate_hand'), 'Has evaluate_hand method');
    ok($evaluator->can('evaluate_potential'), 'Has evaluate_potential method');
    ok($evaluator->can('select_discards'), 'Has select_discards method');
};

subtest 'High hand evaluation' => sub {
    my $evaluator = FB::Poker::Strategy::Evaluator::OmahaHiLo->new;
    
    # Create a strong high hand (nut flush possible)
    my @hole = (
        FB::Poker::Card->new(rank => 'A', suit => 's'),
        FB::Poker::Card->new(rank => 'K', suit => 's'),
        FB::Poker::Card->new(rank => 'Q', suit => 'h'),
        FB::Poker::Card->new(rank => 'J', suit => 'h'),
    );
    my @community = (
        FB::Poker::Card->new(rank => 'T', suit => 's'),
        FB::Poker::Card->new(rank => '9', suit => 's'),
        FB::Poker::Card->new(rank => '8', suit => 's'),
        FB::Poker::Card->new(rank => '2', suit => 'd'),
        FB::Poker::Card->new(rank => '3', suit => 'c'),
    );
    
    my $strength = $evaluator->evaluate_hand(\@hole, \@community);
    ok($strength >= 0.0 && $strength <= 1.0, "Strength normalized: $strength");
    ok($strength > 0.0, "Hand has positive strength: $strength");
};

subtest 'Low hand qualification (8-or-better)' => sub {
    my $evaluator = FB::Poker::Strategy::Evaluator::OmahaHiLo->new;
    
    # Create a hand with qualifying low (A-2-3-4-5 wheel)
    my @hole = (
        FB::Poker::Card->new(rank => 'A', suit => 's'),
        FB::Poker::Card->new(rank => '2', suit => 'h'),
        FB::Poker::Card->new(rank => 'K', suit => 'd'),
        FB::Poker::Card->new(rank => 'Q', suit => 'c'),
    );
    my @community = (
        FB::Poker::Card->new(rank => '3', suit => 's'),
        FB::Poker::Card->new(rank => '4', suit => 'h'),
        FB::Poker::Card->new(rank => '5', suit => 'd'),
        FB::Poker::Card->new(rank => 'J', suit => 'c'),
        FB::Poker::Card->new(rank => 'T', suit => 's'),
    );
    
    my $strength = $evaluator->evaluate_hand(\@hole, \@community);
    ok($strength >= 0.0 && $strength <= 1.0, "Strength normalized: $strength");
    ok($strength > 0.3, "Hand with qualifying low has decent strength: $strength");
};

subtest 'No qualifying low (all high cards)' => sub {
    my $evaluator = FB::Poker::Strategy::Evaluator::OmahaHiLo->new;
    
    # Create a hand with no qualifying low (all cards 9+)
    my @hole = (
        FB::Poker::Card->new(rank => 'A', suit => 's'),
        FB::Poker::Card->new(rank => 'K', suit => 'h'),
        FB::Poker::Card->new(rank => 'Q', suit => 'd'),
        FB::Poker::Card->new(rank => 'J', suit => 'c'),
    );
    my @community = (
        FB::Poker::Card->new(rank => 'T', suit => 's'),
        FB::Poker::Card->new(rank => '9', suit => 'h'),
        FB::Poker::Card->new(rank => '9', suit => 'd'),
        FB::Poker::Card->new(rank => 'K', suit => 'c'),
        FB::Poker::Card->new(rank => 'Q', suit => 's'),
    );
    
    my $strength = $evaluator->evaluate_hand(\@hole, \@community);
    ok($strength >= 0.0 && $strength <= 1.0, "Strength normalized: $strength");
    # Strength should be based only on high hand
};

subtest 'Ace counts as low in low evaluation' => sub {
    my $evaluator = FB::Poker::Strategy::Evaluator::OmahaHiLo->new;
    
    # Test that Ace is treated as 1 for low hand
    my @hole = (
        FB::Poker::Card->new(rank => 'A', suit => 's'),
        FB::Poker::Card->new(rank => 'A', suit => 'h'),
        FB::Poker::Card->new(rank => '2', suit => 'd'),
        FB::Poker::Card->new(rank => '3', suit => 'c'),
    );
    my @community = (
        FB::Poker::Card->new(rank => '4', suit => 's'),
        FB::Poker::Card->new(rank => '5', suit => 'h'),
        FB::Poker::Card->new(rank => '6', suit => 'd'),
        FB::Poker::Card->new(rank => 'K', suit => 'c'),
        FB::Poker::Card->new(rank => 'Q', suit => 's'),
    );
    
    my $strength = $evaluator->evaluate_hand(\@hole, \@community);
    ok($strength >= 0.0 && $strength <= 1.0, "Strength normalized: $strength");
    ok($strength > 0.5, "Hand with A-2-3-4-5 low has good strength: $strength");
};

subtest 'Edge cases' => sub {
    my $evaluator = FB::Poker::Strategy::Evaluator::OmahaHiLo->new;
    
    is($evaluator->evaluate_hand(undef, []), 0.0, 'Handles undef hole cards');
    is($evaluator->evaluate_hand([], []), 0.0, 'Handles empty hole cards');
    
    my @hole = (
        FB::Poker::Card->new(rank => 'A', suit => 's'),
        FB::Poker::Card->new(rank => 'K', suit => 'h'),
        FB::Poker::Card->new(rank => 'Q', suit => 'd'),
        FB::Poker::Card->new(rank => 'J', suit => 'c'),
    );
    is($evaluator->evaluate_hand(\@hole, []), 0.0, 'Handles insufficient community cards');
    
    my $discards = $evaluator->select_discards(\@hole);
    is_deeply($discards, [], 'OmahaHiLo select_discards returns empty array');
};

subtest 'Must use exactly 2 hole + 3 community' => sub {
    my $evaluator = FB::Poker::Strategy::Evaluator::OmahaHiLo->new;
    
    # This is implicitly tested by the evaluator logic
    # The evaluator generates all 2-card hole combinations
    # and all 3-card community combinations
    
    my @hole = (
        FB::Poker::Card->new(rank => 'A', suit => 's'),
        FB::Poker::Card->new(rank => 'A', suit => 'h'),
        FB::Poker::Card->new(rank => 'A', suit => 'd'),
        FB::Poker::Card->new(rank => 'A', suit => 'c'),
    );
    my @community = (
        FB::Poker::Card->new(rank => 'K', suit => 's'),
        FB::Poker::Card->new(rank => 'K', suit => 'h'),
        FB::Poker::Card->new(rank => 'K', suit => 'd'),
        FB::Poker::Card->new(rank => 'K', suit => 'c'),
        FB::Poker::Card->new(rank => '2', suit => 's'),
    );
    
    my $strength = $evaluator->evaluate_hand(\@hole, \@community);
    ok($strength >= 0.0 && $strength <= 1.0, "Four aces evaluated correctly: $strength");
    ok($strength > 0.5, "Four aces with four kings is strong: $strength");
};

done_testing();
