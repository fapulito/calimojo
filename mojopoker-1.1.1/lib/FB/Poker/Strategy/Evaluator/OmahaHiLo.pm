package FB::Poker::Strategy::Evaluator::OmahaHiLo;
use Moo;
use FB::Poker::Eval::Community;
use FB::Poker::Score::High;
use Algorithm::Combinatorics qw(combinations);

with 'FB::Poker::Strategy::HandEvaluator';

# Omaha Hi-Lo evaluator
# Evaluates both high and low hands separately
# Low hand must qualify (8-or-better)
# Aces count as low (1) for low evaluation
# Pairs, straights, and flushes are ignored for low

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

# Maximum hand score (worst hand)
use constant MAX_HAND_SCORE => 7462;

sub evaluate_hand {
    my ($self, $hole_cards, $community_cards) = @_;
    
    # Validate inputs
    return 0.0 unless $hole_cards && ref($hole_cards) eq 'ARRAY' && @$hole_cards >= 4;
    return 0.0 unless $community_cards && ref($community_cards) eq 'ARRAY' && @$community_cards >= 5;
    
    # Omaha Hi-Lo: must use exactly 2 hole cards + 3 community cards
    # Evaluate both high and low hands
    my ($high_strength, $low_strength) = $self->_evaluate_high_low($hole_cards, $community_cards);
    
    # Return combined strength (weighted average)
    # In Hi-Lo, both hands matter, so we average them
    # If no qualifying low, high hand is worth more
    if ($low_strength > 0) {
        return ($high_strength + $low_strength) / 2.0;
    } else {
        return $high_strength;
    }
}

sub _evaluate_high_low {
    my ($self, $hole_cards, $community_cards) = @_;
    
    my $best_high_score = MAX_HAND_SCORE;  # Worst possible
    my $best_low_score = undef;  # No qualifying low yet
    
    # Generate all combinations of 2 hole cards
    my $hole_iter = combinations($hole_cards, 2);
    
    while (my $hole_combo = $hole_iter->next) {
        # Generate all combinations of 3 community cards
        my $comm_iter = combinations($community_cards, 3);
        
        while (my $comm_combo = $comm_iter->next) {
            # Evaluate high hand using Community evaluator
            $self->_evaluator->community_cards($comm_combo);
            my $result = $self->_evaluator->best_hand($hole_combo);
            
            if ($result && defined $result->{score}) {
                my $high_score = $result->{score};
                $best_high_score = $high_score if $high_score < $best_high_score;
            }
            
            # Evaluate low hand (8-or-better)
            my @hand = (@$hole_combo, @$comm_combo);
            my $low_score = $self->_evaluate_low_hand(\@hand);
            if (defined $low_score) {
                $best_low_score = $low_score if !defined($best_low_score) || $low_score < $best_low_score;
            }
        }
    }
    
    # Normalize scores to 0.0-1.0
    my $high_strength = $self->normalize_score($best_high_score);
    my $low_strength = defined($best_low_score) ? $self->_normalize_low_score($best_low_score) : 0.0;
    
    return ($high_strength, $low_strength);
}

sub _evaluate_low_hand {
    my ($self, $hand) = @_;
    
    # Low hand rules:
    # - Must have 5 cards 8 or lower (A counts as 1)
    # - Pairs, straights, and flushes are IGNORED
    # - Best low is A-2-3-4-5 (wheel)
    
    my @ranks;
    for my $card (@$hand) {
        my $rank = $card->rank;
        
        # Convert ranks to numeric values for low evaluation
        my $value;
        if ($rank eq 'A') {
            $value = 1;  # Ace is low
        } elsif ($rank eq 'T') {
            $value = 10;
        } elsif ($rank eq 'J') {
            $value = 11;
        } elsif ($rank eq 'Q') {
            $value = 12;
        } elsif ($rank eq 'K') {
            $value = 13;
        } else {
            $value = int($rank);
        }
        
        # Only cards 8 or lower qualify for low
        push @ranks, $value if $value <= 8;
    }
    
    # Need at least 5 qualifying cards
    return undef if @ranks < 5;
    
    # Sort ascending and take the 5 lowest unique ranks
    @ranks = sort { $a <=> $b } @ranks;
    
    # Remove duplicates (pairs don't count against low)
    my %seen;
    my @unique_ranks = grep { !$seen{$_}++ } @ranks;
    
    # Need 5 unique ranks 8-or-better
    return undef if @unique_ranks < 5;
    
    # Take the 5 lowest
    @unique_ranks = @unique_ranks[0..4];
    
    # Calculate low score (lower is better)
    # Score is built in descending rank order (highest rank first)
    # A-2-3-4-5 (5-4-3-2-A) = 54321 (best)
    # 8-7-6-5-4 = 87654 (worst qualifying)
    # Build score from highest rank to lowest (descending order)
    my $score = 0;
    for my $i (reverse 0..4) {
        $score = $score * 10 + $unique_ranks[$i];
    }
    
    return $score;
}

sub _normalize_low_score {
    my ($self, $score) = @_;
    
    return 0.0 unless defined $score;
    
    # Best low: A-2-3-4-5 (5-4-3-2-A) = 54321
    # Worst low: 8-7-6-5-4 = 87654
    my $best = 54321;
    my $worst = 87654;
    
    # Invert: lower score = higher strength
    my $normalized = 1.0 - (($score - $best) / ($worst - $best));
    
    # Clamp to [0.0, 1.0]
    $normalized = 0.0 if $normalized < 0.0;
    $normalized = 1.0 if $normalized > 1.0;
    
    return $normalized;
}

sub evaluate_potential {
    my ($self, $hole_cards, $community_cards) = @_;
    
    # For Omaha Hi-Lo, potential is complex
    # Consider both high and low draw potential
    # Simplified: return moderate potential
    return 0.3;
}

sub select_discards {
    my ($self, $hand) = @_;
    
    # Omaha Hi-Lo doesn't have discards (it's not a draw game)
    return [];
}

1;

__END__

=head1 NAME

FB::Poker::Strategy::Evaluator::OmahaHiLo - Omaha Hi-Lo hand evaluator

=head1 DESCRIPTION

Evaluates Omaha Hi-Lo (Omaha Eight-or-Better) hands according to split-pot rules:

=over 4

=item * Must use exactly 2 hole cards + 3 community cards

=item * Evaluates both high and low hands separately

=item * Low hand must qualify (8-or-better)

=item * Aces count as 1 for low evaluation

=item * Pairs, straights, and flushes are ignored for low hand

=item * Best low is A-2-3-4-5 (wheel)

=item * Pot is split between best high and best qualifying low

=back

=head1 METHODS

=head2 evaluate_hand($hole_cards, $community_cards)

Returns normalized strength (0.0-1.0) considering both high and low hands.

=head2 evaluate_potential($hole_cards, $community_cards)

Returns draw potential for improving either high or low hand.

=head2 select_discards($hand)

Returns empty array (Omaha Hi-Lo is not a draw game).

=cut
