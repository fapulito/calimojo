#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'lib';

use FB::Poker::Card;
use FB::Poker::Strategy::Evaluator::Holdem;
use FB::Poker::Strategy::Evaluator::Omaha;
use FB::Poker::Strategy::Evaluator::Draw;

# Test HandEvaluator role is properly consumed
subtest 'HandEvaluator role' => sub {
    my $holdem = FB::Poker::Strategy::Evaluator::Holdem->new;
    my $omaha = FB::Poker::Strategy::Evaluator::Omaha->new;
    my $draw = FB::Poker::Strategy::Evaluator::Draw->new;
    
    ok($holdem->can('evaluate_hand'), 'Holdem has evaluate_hand');
    ok($holdem->can('evaluate_potential'), 'Holdem has evaluate_potential');
    ok($holdem->can('select_discards'), 'Holdem has select_discards');
    ok($holdem->can('normalize_score'), 'Holdem has normalize_score');
    
    ok($omaha->can('evaluate_hand'), 'Omaha has evaluate_hand');
    ok($draw->can('select_discards'), 'Draw has select_discards');
};

# Test Holdem evaluator
subtest 'Holdem evaluator' => sub {
    my $holdem = FB::Poker::Strategy::Evaluator::Holdem->new;
    
    # Create a royal flush
    my @hole = (
        FB::Poker::Card->new(rank => 'A', suit => 's'),
        FB::Poker::Card->new(rank => 'K', suit => 's'),
    );
    my @community = (
        FB::Poker::Card->new(rank => 'Q', suit => 's'),
        FB::Poker::Card->new(rank => 'J', suit => 's'),
        FB::Poker::Card->new(rank => 'T', suit => 's'),
    );
    
    my $strength = $holdem->evaluate_hand(\@hole, \@community);
    ok($strength >= 0.0 && $strength <= 1.0, "Strength is normalized: $strength");
    ok($strength > 0.9, "Royal flush is very strong: $strength");
    
    # Test with weak hand
    my @weak_hole = (
        FB::Poker::Card->new(rank => '2', suit => 's'),
        FB::Poker::Card->new(rank => '7', suit => 'h'),
    );
    my @weak_community = (
        FB::Poker::Card->new(rank => '4', suit => 'd'),
        FB::Poker::Card->new(rank => '9', suit => 'c'),
        FB::Poker::Card->new(rank => 'K', suit => 's'),
    );
    
    my $weak_strength = $holdem->evaluate_hand(\@weak_hole, \@weak_community);
    ok($weak_strength >= 0.0 && $weak_strength <= 1.0, "Weak hand normalized: $weak_strength");
    ok($weak_strength < $strength, "Weak hand is weaker than royal flush");
    
    # Test edge cases
    is($holdem->evaluate_hand(undef, []), 0.0, 'Handles undef hole cards');
    is($holdem->evaluate_hand([], []), 0.0, 'Handles empty hole cards');
    
    # Test select_discards returns empty for Holdem
    my $discards = $holdem->select_discards(\@hole);
    is_deeply($discards, [], 'Holdem select_discards returns empty array');
};

# Test Omaha evaluator
subtest 'Omaha evaluator' => sub {
    my $omaha = FB::Poker::Strategy::Evaluator::Omaha->new;
    
    # Create 4 hole cards and 5 community cards
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
    
    my $strength = $omaha->evaluate_hand(\@hole, \@community);
    ok($strength >= 0.0 && $strength <= 1.0, "Omaha strength normalized: $strength");
    
    # Test edge cases
    is($omaha->evaluate_hand(undef, []), 0.0, 'Handles undef hole cards');
    is($omaha->evaluate_hand([], []), 0.0, 'Handles empty hole cards');
    is($omaha->evaluate_hand(\@hole, []), 0.0, 'Handles insufficient community cards');
    
    # Test select_discards returns empty for Omaha
    my $discards = $omaha->select_discards(\@hole);
    is_deeply($discards, [], 'Omaha select_discards returns empty array');
};

# Test Draw evaluator
subtest 'Draw evaluator' => sub {
    my $draw = FB::Poker::Strategy::Evaluator::Draw->new;
    
    # Create a pair of Aces
    my @pair_hand = (
        FB::Poker::Card->new(rank => 'A', suit => 's'),
        FB::Poker::Card->new(rank => 'A', suit => 'h'),
        FB::Poker::Card->new(rank => '7', suit => 'd'),
        FB::Poker::Card->new(rank => '4', suit => 'c'),
        FB::Poker::Card->new(rank => '2', suit => 's'),
    );
    
    my $strength = $draw->evaluate_hand(\@pair_hand);
    ok($strength >= 0.0 && $strength <= 1.0, "Draw strength normalized: $strength");
    
    # Test discard selection - should keep the pair (indices 0, 1)
    my $discards = $draw->select_discards(\@pair_hand);
    ok(ref($discards) eq 'ARRAY', 'select_discards returns arrayref');
    
    # Discards should be indices 2, 3, 4 (the non-pair cards)
    my %discard_set = map { $_ => 1 } @$discards;
    ok(!exists $discard_set{0}, 'First Ace not discarded');
    ok(!exists $discard_set{1}, 'Second Ace not discarded');
    ok(scalar(@$discards) == 3, 'Three cards discarded for pair');
    
    # Test with a flush - should keep all
    my @flush_hand = (
        FB::Poker::Card->new(rank => 'A', suit => 's'),
        FB::Poker::Card->new(rank => 'K', suit => 's'),
        FB::Poker::Card->new(rank => 'Q', suit => 's'),
        FB::Poker::Card->new(rank => 'J', suit => 's'),
        FB::Poker::Card->new(rank => '9', suit => 's'),
    );
    
    my $flush_discards = $draw->select_discards(\@flush_hand);
    is_deeply($flush_discards, [], 'No discards for flush');
    
    # Test edge cases
    is($draw->evaluate_hand(undef), 0.0, 'Handles undef hand');
    is($draw->evaluate_hand([]), 0.0, 'Handles empty hand');
    is_deeply($draw->select_discards(undef), [], 'select_discards handles undef');
    is_deeply($draw->select_discards([]), [], 'select_discards handles empty');
};

# Test normalize_score helper
subtest 'normalize_score' => sub {
    my $holdem = FB::Poker::Strategy::Evaluator::Holdem->new;
    
    is($holdem->normalize_score(0, 100), 0.0, 'Zero score normalizes to 0.0');
    is($holdem->normalize_score(100, 100), 1.0, 'Max score normalizes to 1.0');
    is($holdem->normalize_score(50, 100), 0.5, 'Half score normalizes to 0.5');
    is($holdem->normalize_score(undef, 100), 0.0, 'Undef score returns 0.0');
    is($holdem->normalize_score(50, 0), 0.0, 'Zero max returns 0.0');
    # When max is undef, it uses the default MAX_HAND_SCORE (7462)
    ok($holdem->normalize_score(50, undef) > 0, 'Undef max uses default MAX_HAND_SCORE');
    
    # Test clamping
    is($holdem->normalize_score(150, 100), 1.0, 'Over max clamps to 1.0');
    is($holdem->normalize_score(-10, 100), 0.0, 'Negative clamps to 0.0');
};

done_testing();
