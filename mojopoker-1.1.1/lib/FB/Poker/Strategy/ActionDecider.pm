package FB::Poker::Strategy::ActionDecider;
use Moo;

# Determines optimal action based on hand strength and game state
# Requirements: 1.3, 1.4, 3.1, 3.2, 3.3, 3.4

has 'config' => (
    is => 'rw',
);

has 'rng_seed' => (
    is      => 'ro',
    default => sub { int(rand(2**31)) },
);

has 'rng' => (
    is      => 'lazy',
    builder => '_build_rng',
);

sub _build_rng {
    my ($self) = @_;
    # Initialize RNG with seed for reproducibility
    # Requirement 3.4: Independent RNG per house player
    srand($self->rng_seed);
    return sub { rand() };
}

# Main decision method
# Requirement 1.3: Select from legal actions
# Requirement 3.1: Apply randomization factor
# Requirement 3.2: Implement slow-play logic
sub decide {
    my ($self, $hand_strength, $game_state) = @_;
    
    # Extract game state parameters
    my $pot_size       = $game_state->{pot_size} || 0;
    my $call_amount    = $game_state->{call_amount} || 0;
    my $valid_actions  = $game_state->{valid_actions} || [];
    my $min_bet        = $game_state->{min_bet} || 0;
    my $max_bet        = $game_state->{max_bet} || 0;
    my $betting_round  = $game_state->{betting_round} || 1;
    
    # Convert valid_actions to hash for quick lookup
    my %valid = map { $_ => 1 } @$valid_actions;
    
    # Get configuration parameters
    my $config = $self->config;
    my $aggression = $config ? $config->aggression : 5;
    my $tightness = $config ? $config->tightness : 5;
    my $randomization = $config ? $config->randomization_factor : 0.15;
    my $slow_play_threshold = $config ? $config->slow_play_threshold : 0.85;
    
    # Apply randomization to hand strength (±15% variance)
    # Requirement 3.1: ±15% threshold variation
    my $variance = ($self->rng->() - 0.5) * 2 * $randomization;
    my $adjusted_strength = $hand_strength * (1 + $variance);
    $adjusted_strength = 0.0 if $adjusted_strength < 0.0;
    $adjusted_strength = 1.0 if $adjusted_strength > 1.0;
    
    # Calculate decision thresholds based on tightness
    # Higher tightness = higher threshold to play
    my $play_threshold = 0.2 + ($tightness / 10) * 0.3;  # 0.2-0.5 range
    my $raise_threshold = 0.5 + ($tightness / 10) * 0.2; # 0.5-0.7 range
    
    # Requirement 3.2: Slow-play logic for strong hands
    my $should_slow_play = 0;
    if ($adjusted_strength >= $slow_play_threshold) {
        # 30% chance to slow-play very strong hands
        $should_slow_play = ($self->rng->() < 0.3);
    }
    
    # Requirement 3.3: Bluffing logic
    my $pot_odds = $call_amount > 0 ? $call_amount / ($pot_size + $call_amount) : 0;
    my $should_bluff = $self->should_bluff($pot_odds);
    
    # Decision logic
    my $action;
    my $amount = 0;
    
    # Very weak hand - fold unless we can check or should bluff
    if ($adjusted_strength < $play_threshold && !$should_bluff) {
        if ($call_amount == 0 && $valid{check}) {
            $action = 'check';
        } elsif ($valid{fold}) {
            $action = 'fold';
        } elsif ($valid{check}) {
            $action = 'check';
        } else {
            # No good option, take first valid action
            $action = $valid_actions->[0] || 'fold';
        }
    }
    # Strong hand - bet or raise (unless slow-playing)
    elsif ($adjusted_strength >= $raise_threshold && !$should_slow_play) {
        if ($valid{bet} || $valid{raise}) {
            $action = $valid{bet} ? 'bet' : 'raise';
            $amount = $self->calculate_bet_amount($adjusted_strength, $pot_size, $min_bet, $max_bet);
        } elsif ($valid{call} && $call_amount > 0) {
            $action = 'call';
            $amount = $call_amount;
        } elsif ($valid{check}) {
            $action = 'check';
        } else {
            $action = $valid_actions->[0] || 'check';
        }
    }
    # Medium hand or slow-playing - call or check
    else {
        if ($call_amount == 0 && $valid{check}) {
            $action = 'check';
        } elsif ($valid{call} && $call_amount > 0) {
            # Call if pot odds are favorable
            my $pot_odds_favorable = $adjusted_strength > $pot_odds;
            if ($pot_odds_favorable) {
                $action = 'call';
                $amount = $call_amount;
            } elsif ($valid{fold}) {
                $action = 'fold';
            } else {
                $action = 'call';
                $amount = $call_amount;
            }
        } elsif ($valid{check}) {
            $action = 'check';
        } elsif ($valid{fold}) {
            $action = 'fold';
        } else {
            $action = $valid_actions->[0] || 'check';
        }
    }
    
    # Bluffing override - occasionally bet with weak hands
    if ($should_bluff && ($valid{bet} || $valid{raise})) {
        $action = $valid{bet} ? 'bet' : 'raise';
        # Smaller bluff bets
        $amount = $self->calculate_bet_amount(0.3, $pot_size, $min_bet, $max_bet);
    }
    
    return {
        action     => $action,
        amount     => $amount,
        reasoning  => $should_bluff ? 'bluff' : 
                      $should_slow_play ? 'slow_play' : 
                      $adjusted_strength >= $raise_threshold ? 'strong_hand' :
                      $adjusted_strength < $play_threshold ? 'weak_hand' : 'medium_hand',
        confidence => $adjusted_strength,
    };
}

# Calculate bet amount within bounds
# Requirement 1.4: Bet amount within min/max limits
sub calculate_bet_amount {
    my ($self, $strength, $pot, $min, $max) = @_;
    
    return $min if $min >= $max;  # Edge case
    
    my $config = $self->config;
    my $aggression = $config ? $config->aggression : 5;
    
    # Base bet as fraction of pot, scaled by aggression
    # Aggression 1 = 0.3x pot, Aggression 10 = 1.2x pot
    my $aggression_multiplier = 0.3 + ($aggression / 10) * 0.9;
    
    # Strength influences bet size
    # Stronger hands bet more (0.5x to 1.5x the aggression base)
    my $strength_multiplier = 0.5 + $strength;
    
    my $bet = $pot * $aggression_multiplier * $strength_multiplier;
    
    # Apply bounds checking
    $bet = $min if $bet < $min;
    $bet = $max if $bet > $max;
    
    # Round to integer
    return int($bet + 0.5);
}

# Determine if should bluff based on pot odds
# Requirement 3.3: Bluff with 5-15% probability
sub should_bluff {
    my ($self, $pot_odds) = @_;
    
    my $config = $self->config;
    my $bluff_frequency = $config ? $config->bluff_frequency : 0.10;
    
    # Bluff more often when pot odds are favorable (pot is large relative to call)
    my $adjusted_frequency = $bluff_frequency * (1 + $pot_odds);
    
    # Cap at 20% to avoid excessive bluffing
    $adjusted_frequency = 0.20 if $adjusted_frequency > 0.20;
    
    return $self->rng->() < $adjusted_frequency;
}

1;
