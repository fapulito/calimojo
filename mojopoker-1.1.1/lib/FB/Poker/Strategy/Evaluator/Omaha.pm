package FB::Poker::Strategy::Evaluator::Omaha;
use Moo;
use FB::Poker::Score::High;
use Algorithm::Combinatorics qw(combinations);

# Omaha hand evaluator
# Requirements: 2.2 - Use exactly 2 hole cards and 3 community cards
#
# Omaha uses 4 hole cards + 5 community cards
# MUST use exactly 2 hole cards + exactly 3 community cards for final hand

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

# evaluate_hand - Evaluate Omaha hand strength
# Args:
#   $hole_cards - arrayref of 4 FB::Poker::Card objects (player's hole cards)
#   $community_cards - arrayref of 3-5 FB::Poker::Card objects (board cards)
# Returns: normalized strength score 0.0-1.0
#
# Key Omaha rule: MUST use exactly 2 hole cards + exactly 3 community cards
sub evaluate_hand {
    my ($self, $hole_cards, $community_cards) = @_;
    
    # Handle missing or invalid input
    return 0.0 unless defined $hole_cards && ref($hole_cards) eq 'ARRAY';
    $community_cards //= [];
    
    # Need at least 4 hole cards and 3 community cards for Omaha
    return 0.0 unless @$hole_cards >= 4;
    return 0.0 unless @$community_cards >= 3;
    
    my $best_score = 0;
    
    # Generate all combinations of 2 hole cards
    my $hole_iter = combinations($hole_cards, 2);
    
    # Pre-generate all combinations of 3 community cards
    my @community_combos = combinations($community_cards, 3);
    
    # Evaluate all valid combinations (2 hole + 3 community)
    while (my $hole_combo = $hole_iter->next) {
        for my $comm_combo (@community_combos) {
            # Form the 5-card hand
            my @hand = (@$hole_combo, @$comm_combo);
            
            # Score this hand
            my $score = $self->_scorer->score(\@hand);
            
            # Track best score
            if (defined $score && $score > $best_score) {
                $best_score = $score;
            }
        }
    }
    
    # Normalize the score to 0.0-1.0 range
    return $self->normalize_score($best_score);
}

# evaluate_potential - Estimate hand improvement potential
# Args:
#   $hole_cards - arrayref of hole cards
#   $community_cards - arrayref of community cards
# Returns: improvement potential 0.0-1.0
sub evaluate_potential {
    my ($self, $hole_cards, $community_cards) = @_;
    
    return 0.0 unless defined $hole_cards && @$hole_cards >= 4;
    $community_cards //= [];
    
    # If we have all 5 community cards, no improvement possible
    return 0.0 if @$community_cards >= 5;
    
    # Need at least 3 community cards to evaluate
    return 0.3 if @$community_cards < 3;  # High potential pre-flop
    
    # Get current hand strength
    my $current_strength = $self->evaluate_hand($hole_cards, $community_cards);
    
    # Cards remaining to come
    my $cards_to_come = 5 - scalar(@$community_cards);
    
    # Omaha has more potential due to 4 hole cards
    # Base potential on inverse of current strength
    my $base_potential = (1.0 - $current_strength) * 0.4;
    my $potential = $base_potential * ($cards_to_come / 2.0);
    
    # Check for wrap straight draws (Omaha specialty)
    my $wrap_potential = $self->_check_wrap_draw($hole_cards, $community_cards);
    
    # Check for flush draws with backup
    my $flush_potential = $self->_check_flush_draw($hole_cards, $community_cards);
    
    # Combine potentials
    $potential = $wrap_potential if $wrap_potential > $potential;
    $potential = $flush_potential if $flush_potential > $potential;
    
    # Clamp to [0.0, 1.0]
    $potential = 0.0 if $potential < 0.0;
    $potential = 1.0 if $potential > 1.0;
    
    return $potential;
}

# Check for flush draw potential in Omaha
sub _check_flush_draw {
    my ($self, $hole_cards, $community_cards) = @_;
    
    # Count hole cards by suit
    my %hole_suits;
    for my $card (@$hole_cards) {
        push @{$hole_suits{$card->suit}}, $card;
    }
    
    # Count community cards by suit
    my %comm_suits;
    for my $card (@$community_cards) {
        $comm_suits{$card->suit}++;
    }
    
    # Check for flush draws (need 2 hole + 2 community of same suit)
    for my $suit (keys %hole_suits) {
        my $hole_count = scalar(@{$hole_suits{$suit}});
        my $comm_count = $comm_suits{$suit} // 0;
        
        # 2 hole + 2 community = flush draw
        if ($hole_count >= 2 && $comm_count >= 2) {
            return 0.35;  # Good flush draw
        }
    }
    
    return 0.0;
}

# Check for wrap straight draws (Omaha specialty)
sub _check_wrap_draw {
    my ($self, $hole_cards, $community_cards) = @_;
    
    my %rank_map = (
        '2' => 2, '3' => 3, '4' => 4, '5' => 5, '6' => 6,
        '7' => 7, '8' => 8, '9' => 9, 'T' => 10, 'J' => 11,
        'Q' => 12, 'K' => 13, 'A' => 14,
    );
    
    # Get hole card ranks
    my @hole_ranks;
    for my $card (@$hole_cards) {
        my $rank_val = $rank_map{$card->rank} // 0;
        push @hole_ranks, $rank_val if $rank_val > 0;
    }
    
    # Get community card ranks
    my @comm_ranks;
    for my $card (@$community_cards) {
        my $rank_val = $rank_map{$card->rank} // 0;
        push @comm_ranks, $rank_val if $rank_val > 0;
    }
    
    # Count how many straight outs we have
    # Wrap draws in Omaha can have 13-20 outs
    my $outs = $self->_count_straight_outs(\@hole_ranks, \@comm_ranks);
    
    # Convert outs to potential (rough approximation)
    # 20 outs = ~45% chance, 13 outs = ~30% chance
    return 0.0 if $outs < 4;
    return ($outs / 45.0);  # Normalize to max ~0.45
}

# Count straight outs for Omaha
sub _count_straight_outs {
    my ($self, $hole_ranks, $comm_ranks) = @_;
    
    # Simplified: count consecutive cards between hole and community
    my %all_ranks = map { $_ => 1 } (@$hole_ranks, @$comm_ranks);
    
    # Add Ace as 1 for wheel
    $all_ranks{1} = 1 if exists $all_ranks{14};
    
    my @sorted = sort { $a <=> $b } keys %all_ranks;
    return 0 if @sorted < 4;
    
    # Count longest run of consecutive cards
    my $max_run = 1;
    my $current_run = 1;
    
    for my $i (1 .. $#sorted) {
        if ($sorted[$i] == $sorted[$i-1] + 1) {
            $current_run++;
            $max_run = $current_run if $current_run > $max_run;
        } else {
            $current_run = 1;
        }
    }
    
    # Estimate outs based on run length
    return 0 if $max_run < 4;
    return 8 if $max_run == 4;   # Open-ended
    return 13 if $max_run == 5;  # Wrap
    return 17 if $max_run >= 6;  # Big wrap
}

# select_discards - Not applicable for Omaha
# Returns: empty arrayref (Omaha has no discard phase)
sub select_discards {
    my ($self, $hand) = @_;
    return [];
}

1;
