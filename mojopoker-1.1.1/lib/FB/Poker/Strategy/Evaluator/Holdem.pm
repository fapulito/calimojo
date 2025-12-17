package FB::Poker::Strategy::Evaluator::Holdem;
use Moo;
use FB::Poker::Eval::Community;
use FB::Poker::Score::High;
use Algorithm::Combinatorics qw(combinations);

# Texas Hold'em hand evaluator
# Requirements: 2.1 - Use hole cards and community cards to evaluate hand strength
#
# Hold'em uses 2 hole cards + up to 5 community cards
# Best 5-card hand from any combination of available cards

with 'FB::Poker::Strategy::HandEvaluator';

# Cached scorer instance for performance
has '_scorer' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_scorer',
);

sub _build_scorer {
    return FB::Poker::Score::High->new;
}

# Cached evaluator instance
has '_evaluator' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_evaluator',
);

sub _build_evaluator {
    my ($self) = @_;
    return FB::Poker::Eval::Community->new(
        scorer => $self->_scorer,
    );
}

# evaluate_hand - Evaluate Texas Hold'em hand strength
# Args:
#   $hole_cards - arrayref of 2 FB::Poker::Card objects (player's hole cards)
#   $community_cards - arrayref of 0-5 FB::Poker::Card objects (board cards)
# Returns: normalized strength score 0.0-1.0
sub evaluate_hand {
    my ($self, $hole_cards, $community_cards) = @_;
    
    # Handle missing or invalid input
    return 0.0 unless defined $hole_cards && ref($hole_cards) eq 'ARRAY';
    $community_cards //= [];
    
    # Need at least hole cards to evaluate
    return 0.0 unless @$hole_cards >= 2;
    
    # Set community cards on evaluator
    $self->_evaluator->community_cards($community_cards);
    
    # Get best hand using Community evaluator
    my $result = $self->_evaluator->best_hand($hole_cards);
    
    # Handle case where no valid hand could be formed
    return 0.0 unless $result && defined $result->{score};
    
    # Normalize the score to 0.0-1.0 range
    return $self->normalize_score($result->{score});
}

# evaluate_potential - Estimate hand improvement potential
# Args:
#   $hole_cards - arrayref of hole cards
#   $community_cards - arrayref of community cards
# Returns: improvement potential 0.0-1.0
#
# This estimates how likely the hand is to improve with more cards.
# Used for drawing decisions and semi-bluff calculations.
sub evaluate_potential {
    my ($self, $hole_cards, $community_cards) = @_;
    
    return 0.0 unless defined $hole_cards && @$hole_cards >= 2;
    $community_cards //= [];
    
    # If we have all 5 community cards, no improvement possible
    return 0.0 if @$community_cards >= 5;
    
    # Get current hand strength
    my $current_strength = $self->evaluate_hand($hole_cards, $community_cards);
    
    # Simple heuristic based on current strength and cards to come
    # Strong hands have less room to improve, weak hands have more potential
    my $cards_to_come = 5 - scalar(@$community_cards);
    
    # Base potential on inverse of current strength, scaled by cards to come
    my $base_potential = (1.0 - $current_strength) * 0.3;
    my $potential = $base_potential * ($cards_to_come / 5.0);
    
    # Check for flush draws (4 cards of same suit)
    my $flush_potential = $self->_check_flush_draw($hole_cards, $community_cards);
    
    # Check for straight draws (4 consecutive cards)
    my $straight_potential = $self->_check_straight_draw($hole_cards, $community_cards);
    
    # Combine potentials (max of individual potentials)
    $potential = $flush_potential if $flush_potential > $potential;
    $potential = $straight_potential if $straight_potential > $potential;
    
    # Clamp to [0.0, 1.0]
    $potential = 0.0 if $potential < 0.0;
    $potential = 1.0 if $potential > 1.0;
    
    return $potential;
}

# Check for flush draw potential
sub _check_flush_draw {
    my ($self, $hole_cards, $community_cards) = @_;
    
    my @all_cards = (@$hole_cards, @$community_cards);
    return 0.0 unless @all_cards >= 4;
    
    # Count cards by suit
    my %suit_count;
    for my $card (@all_cards) {
        $suit_count{$card->suit}++;
    }
    
    # Check for 4-card flush draw
    for my $count (values %suit_count) {
        return 0.35 if $count == 4;  # ~35% chance to hit flush with one card
    }
    
    return 0.0;
}

# Check for straight draw potential
sub _check_straight_draw {
    my ($self, $hole_cards, $community_cards) = @_;
    
    my @all_cards = (@$hole_cards, @$community_cards);
    return 0.0 unless @all_cards >= 4;
    
    # Get unique ranks as numbers
    my %rank_map = (
        '2' => 2, '3' => 3, '4' => 4, '5' => 5, '6' => 6,
        '7' => 7, '8' => 8, '9' => 9, 'T' => 10, 'J' => 11,
        'Q' => 12, 'K' => 13, 'A' => 14,
    );
    
    my %ranks;
    for my $card (@all_cards) {
        my $rank_val = $rank_map{$card->rank} // 0;
        $ranks{$rank_val} = 1 if $rank_val > 0;
    }
    
    # Also count Ace as 1 for wheel straights
    $ranks{1} = 1 if exists $ranks{14};
    
    my @sorted_ranks = sort { $a <=> $b } keys %ranks;
    
    # Check for open-ended straight draw (4 consecutive)
    for my $i (0 .. $#sorted_ranks - 3) {
        my $consecutive = 1;
        for my $j (1 .. 3) {
            if ($sorted_ranks[$i + $j] == $sorted_ranks[$i] + $j) {
                $consecutive++;
            }
        }
        if ($consecutive >= 4) {
            # Open-ended has ~31% chance, gutshot has ~17%
            return 0.31;
        }
    }
    
    # Check for gutshot (4 cards with one gap)
    for my $i (0 .. $#sorted_ranks - 3) {
        my @window = @sorted_ranks[$i .. $i + 3];
        my $span = $window[3] - $window[0];
        if ($span == 4) {
            return 0.17;  # Gutshot draw
        }
    }
    
    return 0.0;
}

# select_discards - Not applicable for Hold'em
# Returns: empty arrayref (Hold'em has no discard phase)
sub select_discards {
    my ($self, $hand) = @_;
    return [];
}

1;
