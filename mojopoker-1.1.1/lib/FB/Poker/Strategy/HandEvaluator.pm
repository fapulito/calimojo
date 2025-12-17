package FB::Poker::Strategy::HandEvaluator;
use Moo::Role;

# Role for hand evaluators - defines required interface for strategy module
# Requirements: 1.2 - Hand strength evaluation returning 0.0-1.0 score
#
# This role defines the contract that all game-specific evaluators must implement.
# Each evaluator handles the specific rules for its poker variant.

# Required methods that consuming classes must implement:

# evaluate_hand($hole_cards, $community_cards)
#   Returns: normalized strength score 0.0-1.0
#   - 0.0 = weakest possible hand
#   - 1.0 = strongest possible hand (royal flush)
requires 'evaluate_hand';

# evaluate_potential($hole_cards, $community_cards)
#   Returns: improvement potential 0.0-1.0
#   - Estimates likelihood of hand improving with more cards
#   - Used for draw decisions and semi-bluff calculations
requires 'evaluate_potential';

# select_discards($hand)
#   Returns: arrayref of card indices to discard (0-based)
#   - For draw poker variants
#   - Returns empty arrayref for non-draw games
requires 'select_discards';

# Maximum possible score from FB::Poker::Score::High
# This is the index of the best possible hand (five-of-a-kind Aces)
# Used for normalizing raw scores to 0.0-1.0 range
use constant MAX_HAND_SCORE => 7462;

# Base implementation - normalize raw score to 0.0-1.0 range
# Args:
#   $raw_score - the score from FB::Poker::Score (higher = better)
#   $max_score - optional max score (defaults to MAX_HAND_SCORE)
# Returns: normalized score between 0.0 and 1.0
sub normalize_score {
    my ($self, $raw_score, $max_score) = @_;
    
    # Use default max if not provided
    $max_score //= MAX_HAND_SCORE;
    
    # Handle edge cases
    return 0.0 unless defined $raw_score;
    return 0.0 unless defined $max_score && $max_score > 0;
    
    my $normalized = $raw_score / $max_score;
    
    # Clamp to [0.0, 1.0]
    $normalized = 0.0 if $normalized < 0.0;
    $normalized = 1.0 if $normalized > 1.0;
    
    return $normalized;
}

# Helper method to create a scorer instance
# Returns: FB::Poker::Score::High instance
sub _get_scorer {
    my ($self) = @_;
    require FB::Poker::Score::High;
    return FB::Poker::Score::High->new;
}

1;
