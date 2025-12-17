package FB::Poker::Strategy::Evaluator::Draw;
use Moo;
use FB::Poker::Score::High;
use Algorithm::Combinatorics qw(combinations);

# Draw poker hand evaluator
# Requirements: 2.3 - Evaluate which cards to discard based on hand improvement potential
#
# Draw poker uses 5 cards with discard/draw mechanics
# Strategy focuses on identifying which cards to keep vs discard

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

# Rank value mapping
has '_rank_map' => (
    is      => 'ro',
    default => sub {
        return {
            '2' => 2, '3' => 3, '4' => 4, '5' => 5, '6' => 6,
            '7' => 7, '8' => 8, '9' => 9, 'T' => 10, 'J' => 11,
            'Q' => 12, 'K' => 13, 'A' => 14,
        };
    },
);

# evaluate_hand - Evaluate 5-card draw hand strength
# Args:
#   $hand - arrayref of 5 FB::Poker::Card objects
#   $community_cards - ignored for draw poker (for interface compatibility)
# Returns: normalized strength score 0.0-1.0
sub evaluate_hand {
    my ($self, $hand, $community_cards) = @_;
    
    # Handle missing or invalid input
    return 0.0 unless defined $hand && ref($hand) eq 'ARRAY';
    return 0.0 unless @$hand >= 5;
    
    # Score the hand directly (5-card hand)
    my @hand_cards = @$hand[0..4];  # Take first 5 cards
    my $score = $self->_scorer->score(\@hand_cards);
    
    return 0.0 unless defined $score;
    
    # Normalize the score to 0.0-1.0 range
    return $self->normalize_score($score);
}

# evaluate_potential - Estimate hand improvement potential
# Args:
#   $hand - arrayref of cards
#   $community_cards - ignored for draw poker
# Returns: improvement potential 0.0-1.0
sub evaluate_potential {
    my ($self, $hand, $community_cards) = @_;
    
    return 0.0 unless defined $hand && @$hand >= 5;
    
    # Analyze the hand structure
    my $analysis = $self->_analyze_hand($hand);
    
    # Calculate potential based on what we have
    my $potential = 0.0;
    
    # Already have a strong hand - low potential for improvement
    if ($analysis->{has_straight} || $analysis->{has_flush}) {
        return 0.05;
    }
    
    # Four to a flush - high potential
    if ($analysis->{flush_draw}) {
        $potential = 0.19;  # ~19% to hit flush
    }
    
    # Four to a straight - good potential
    if ($analysis->{straight_draw}) {
        $potential = 0.17 if $potential < 0.17;
    }
    
    # Three of a kind - potential for full house or quads
    if ($analysis->{trips}) {
        $potential = 0.10 if $potential < 0.10;
    }
    
    # Two pair - potential for full house
    if ($analysis->{two_pair}) {
        $potential = 0.09 if $potential < 0.09;
    }
    
    # One pair - potential for trips or better
    if ($analysis->{pair}) {
        $potential = 0.12 if $potential < 0.12;
    }
    
    return $potential;
}

# select_discards - Select which cards to discard
# Args:
#   $hand - arrayref of 5 FB::Poker::Card objects
# Returns: arrayref of card indices (0-4) to discard
#
# Requirements: 2.3 - Return valid card indices for discard
sub select_discards {
    my ($self, $hand) = @_;
    
    # Handle missing or invalid input
    return [] unless defined $hand && ref($hand) eq 'ARRAY';
    return [] unless @$hand >= 5;
    
    # Analyze the hand
    my $analysis = $self->_analyze_hand($hand);
    
    # Determine which cards to keep based on hand analysis
    my @keep_indices = $self->_determine_keeps($hand, $analysis);
    
    # Return indices NOT in keep list (these are discards)
    my %keep_set = map { $_ => 1 } @keep_indices;
    my @discards;
    
    for my $i (0 .. 4) {
        push @discards, $i unless exists $keep_set{$i};
    }
    
    return \@discards;
}

# Analyze hand structure
sub _analyze_hand {
    my ($self, $hand) = @_;
    
    my %analysis = (
        has_straight  => 0,
        has_flush     => 0,
        flush_draw    => 0,
        straight_draw => 0,
        quads         => 0,
        trips         => 0,
        two_pair      => 0,
        pair          => 0,
        high_cards    => [],
        rank_groups   => {},
        suit_counts   => {},
    );
    
    # Count ranks and suits
    my %rank_count;
    my %suit_count;
    my @ranks;
    
    for my $card (@$hand[0..4]) {
        my $rank = $card->rank;
        my $suit = $card->suit;
        my $rank_val = $self->_rank_map->{$rank} // 0;
        
        $rank_count{$rank}++;
        $suit_count{$suit}++;
        push @ranks, $rank_val;
    }
    
    $analysis{rank_groups} = \%rank_count;
    $analysis{suit_counts} = \%suit_count;
    
    # Check for flush/flush draw
    for my $count (values %suit_count) {
        $analysis{has_flush} = 1 if $count == 5;
        $analysis{flush_draw} = 1 if $count == 4;
    }
    
    # Check for straight/straight draw
    @ranks = sort { $a <=> $b } @ranks;
    push @ranks, 1 if $ranks[4] == 14;  # Ace can be low
    
    $analysis{has_straight} = $self->_is_straight(\@ranks);
    $analysis{straight_draw} = $self->_is_straight_draw(\@ranks) unless $analysis{has_straight};
    
    # Check for pairs, trips, quads
    my @counts = sort { $b <=> $a } values %rank_count;
    
    if ($counts[0] == 4) {
        $analysis{quads} = 1;
    } elsif ($counts[0] == 3) {
        $analysis{trips} = 1;
        $analysis{two_pair} = 1 if $counts[1] == 2;  # Full house
    } elsif ($counts[0] == 2) {
        $analysis{pair} = 1;
        $analysis{two_pair} = 1 if $counts[1] == 2;
    }
    
    # Track high cards (J, Q, K, A)
    for my $i (0 .. 4) {
        my $rank_val = $self->_rank_map->{$hand->[$i]->rank} // 0;
        push @{$analysis{high_cards}}, $i if $rank_val >= 11;
    }
    
    return \%analysis;
}

# Check if ranks form a straight
sub _is_straight {
    my ($self, $ranks) = @_;
    
    # Check for 5 consecutive
    for my $start (0 .. @$ranks - 5) {
        my $is_straight = 1;
        for my $i (1 .. 4) {
            if ($ranks->[$start + $i] != $ranks->[$start] + $i) {
                $is_straight = 0;
                last;
            }
        }
        return 1 if $is_straight;
    }
    
    return 0;
}

# Check for straight draw (4 consecutive or gutshot)
sub _is_straight_draw {
    my ($self, $ranks) = @_;
    
    my @unique = do { my %seen; grep { !$seen{$_}++ } @$ranks };
    @unique = sort { $a <=> $b } @unique;
    
    return 0 if @unique < 4;
    
    # Check for 4 consecutive (open-ended)
    for my $i (0 .. @unique - 4) {
        if ($unique[$i + 3] - $unique[$i] == 3) {
            return 1;
        }
    }
    
    # Check for gutshot (4 cards with one gap)
    for my $i (0 .. @unique - 4) {
        if ($unique[$i + 3] - $unique[$i] == 4) {
            return 1;
        }
    }
    
    return 0;
}

# Determine which card indices to keep
sub _determine_keeps {
    my ($self, $hand, $analysis) = @_;
    
    my @keeps;
    
    # Keep all cards for made hands (straight, flush, full house, quads)
    if ($analysis->{has_straight} || $analysis->{has_flush} || 
        $analysis->{quads} || ($analysis->{trips} && $analysis->{two_pair})) {
        return (0, 1, 2, 3, 4);
    }
    
    # Four to a flush - keep the 4 suited cards
    if ($analysis->{flush_draw}) {
        my $flush_suit;
        for my $suit (keys %{$analysis->{suit_counts}}) {
            if ($analysis->{suit_counts}{$suit} == 4) {
                $flush_suit = $suit;
                last;
            }
        }
        for my $i (0 .. 4) {
            push @keeps, $i if $hand->[$i]->suit eq $flush_suit;
        }
        return @keeps;
    }
    
    # Quads - keep all 4 of a kind
    if ($analysis->{quads}) {
        my $quad_rank;
        for my $rank (keys %{$analysis->{rank_groups}}) {
            if ($analysis->{rank_groups}{$rank} == 4) {
                $quad_rank = $rank;
                last;
            }
        }
        for my $i (0 .. 4) {
            push @keeps, $i if $hand->[$i]->rank eq $quad_rank;
        }
        return @keeps;
    }
    
    # Trips - keep the three of a kind
    if ($analysis->{trips}) {
        my $trip_rank;
        for my $rank (keys %{$analysis->{rank_groups}}) {
            if ($analysis->{rank_groups}{$rank} == 3) {
                $trip_rank = $rank;
                last;
            }
        }
        for my $i (0 .. 4) {
            push @keeps, $i if $hand->[$i]->rank eq $trip_rank;
        }
        return @keeps;
    }
    
    # Two pair - keep both pairs
    if ($analysis->{two_pair}) {
        for my $rank (keys %{$analysis->{rank_groups}}) {
            if ($analysis->{rank_groups}{$rank} == 2) {
                for my $i (0 .. 4) {
                    push @keeps, $i if $hand->[$i]->rank eq $rank;
                }
            }
        }
        return @keeps;
    }
    
    # One pair - keep the pair
    if ($analysis->{pair}) {
        my $pair_rank;
        for my $rank (keys %{$analysis->{rank_groups}}) {
            if ($analysis->{rank_groups}{$rank} == 2) {
                $pair_rank = $rank;
                last;
            }
        }
        for my $i (0 .. 4) {
            push @keeps, $i if $hand->[$i]->rank eq $pair_rank;
        }
        return @keeps;
    }
    
    # No made hand - keep high cards (J, Q, K, A)
    if (@{$analysis->{high_cards}}) {
        return @{$analysis->{high_cards}};
    }
    
    # Keep highest card
    my $highest_idx = 0;
    my $highest_val = 0;
    for my $i (0 .. 4) {
        my $val = $self->_rank_map->{$hand->[$i]->rank} // 0;
        if ($val > $highest_val) {
            $highest_val = $val;
            $highest_idx = $i;
        }
    }
    
    return ($highest_idx);
}

1;
