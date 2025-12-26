package FB::Poker::Strategy::Evaluator::Stud;
use Moo;
use FB::Poker::Score::High;
use Algorithm::Combinatorics qw(combinations);

# 7-Card Stud hand evaluator
# Requirements: 5.1, 5.2 - Evaluate stud hands using all 7 cards
#
# In 7-card stud, players receive 7 cards (3 down, 4 up)
# Best 5-card hand from any combination of the 7 cards

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

# evaluate_hand - Evaluate 7-card stud hand strength
# Args:
#   $hole_cards - arrayref of FB::Poker::Card objects (all player's cards in stud)
#   $community_cards - arrayref (unused in stud, but kept for interface compatibility)
# Returns: normalized strength score 0.0-1.0
#
# Requirement 5.2: Consider all 7 cards to find the best 5-card hand
sub evaluate_hand {
    my ($self, $hole_cards, $community_cards) = @_;
    
    # Handle missing or invalid input
    return 0.0 unless defined $hole_cards && ref($hole_cards) eq 'ARRAY';
    
    # In stud, all cards are "hole" cards (no community cards)
    my @all_cards = @$hole_cards;
    
    # Need at least 5 cards to evaluate
    return 0.0 unless @all_cards >= 5;
    
    my $best_score = 0;
    
    # If exactly 5 cards, just score them directly
    if (@all_cards == 5) {
        $best_score = $self->_scorer->score(\@all_cards) // 0;
    }
    # If 6 cards, generate all 6 combinations of 5
    elsif (@all_cards == 6) {
        my $iter = combinations(\@all_cards, 5);
        while (my $combo = $iter->next) {
            my $score = $self->_scorer->score($combo) // 0;
            $best_score = $score if $score > $best_score;
        }
    }
    # If 7 cards, generate all 21 combinations of 5 from 7
    elsif (@all_cards == 7) {
        my $iter = combinations(\@all_cards, 5);
        while (my $combo = $iter->next) {
            my $score = $self->_scorer->score($combo) // 0;
            $best_score = $score if $score > $best_score;
        }
    }
    # More than 7 cards (shouldn't happen, but handle gracefully)
    else {
        my $iter = combinations(\@all_cards, 5);
        while (my $combo = $iter->next) {
            my $score = $self->_scorer->score($combo) // 0;
            $best_score = $score if $score > $best_score;
        }
    }
    
    # Normalize the score to 0.0-1.0 range
    return $self->normalize_score($best_score);
}

# evaluate_potential - Estimate hand improvement potential
# Args:
#   $hole_cards - arrayref of hole cards
#   $community_cards - arrayref (unused in stud)
# Returns: improvement potential 0.0-1.0
#
# In stud, potential is based on cards yet to be dealt
sub evaluate_potential {
    my ($self, $hole_cards, $community_cards) = @_;
    
    return 0.0 unless defined $hole_cards && ref($hole_cards) eq 'ARRAY';
    
    my @cards = @$hole_cards;
    
    # If we have all 7 cards, no improvement possible
    return 0.0 if @cards >= 7;
    
    # Get current hand strength
    my $current_strength = $self->evaluate_hand($hole_cards, []);
    
    # Cards remaining to come
    my $cards_to_come = 7 - scalar(@cards);
    
    # Base potential on inverse of current strength, scaled by cards to come
    my $base_potential = (1.0 - $current_strength) * 0.3;
    my $potential = $base_potential * ($cards_to_come / 4.0);
    
    # Check for flush draws
    my $flush_potential = $self->_check_flush_draw(\@cards);
    
    # Check for straight draws
    my $straight_potential = $self->_check_straight_draw(\@cards);
    
    # Use the highest potential
    $potential = $flush_potential if $flush_potential > $potential;
    $potential = $straight_potential if $straight_potential > $potential;
    
    # Clamp to [0.0, 1.0]
    $potential = 0.0 if $potential < 0.0;
    $potential = 1.0 if $potential > 1.0;
    
    return $potential;
}

# Check for flush draw potential
sub _check_flush_draw {
    my ($self, $cards) = @_;
    
    return 0.0 unless @$cards >= 4;
    
    # Count cards by suit
    my %suit_count;
    for my $card (@$cards) {
        $suit_count{$card->suit}++;
    }
    
    # Check for 4-card flush draw
    for my $count (values %suit_count) {
        return 0.35 if $count == 4;  # ~35% chance to hit flush
        return 0.20 if $count == 3 && @$cards <= 5;  # 3-flush with cards to come
    }
    
    return 0.0;
}

# Check for straight draw potential
sub _check_straight_draw {
    my ($self, $cards) = @_;
    
    return 0.0 unless @$cards >= 4;
    
    # Get unique ranks as numbers
    my %rank_map = (
        '2' => 2, '3' => 3, '4' => 4, '5' => 5, '6' => 6,
        '7' => 7, '8' => 8, '9' => 9, 'T' => 10, 'J' => 11,
        'Q' => 12, 'K' => 13, 'A' => 14,
    );
    
    my %ranks;
    for my $card (@$cards) {
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
            last if $i + $j > $#sorted_ranks;
            if ($sorted_ranks[$i + $j] == $sorted_ranks[$i] + $j) {
                $consecutive++;
            }
        }
        if ($consecutive >= 4) {
            return 0.31;  # Open-ended has ~31% chance
        }
    }
    
    # Check for gutshot (4 cards with one gap)
    for my $i (0 .. $#sorted_ranks - 3) {
        last if $i + 3 > $#sorted_ranks;
        my @window = @sorted_ranks[$i .. $i + 3];
        my $span = $window[3] - $window[0];
        if ($span == 4) {
            return 0.17;  # Gutshot draw
        }
    }
    
    return 0.0;
}

# select_discards - Not applicable for Stud
# Returns: empty arrayref (Stud has no discard phase)
sub select_discards {
    my ($self, $hand) = @_;
    return [];
}

1;
