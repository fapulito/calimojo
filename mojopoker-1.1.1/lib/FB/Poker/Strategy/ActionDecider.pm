package FB::Poker::Strategy::ActionDecider;
use Moo;

has 'config' => (
    is => 'rw',
);

has 'rng_seed' => (
    is      => 'ro',
    default => sub { 
        return int(rand(0x7FFFFFFF));
    },
);

has 'rng' => (
    is      => 'lazy',
    builder => '_build_rng',
);

sub _build_rng {
    my ($self) = @_;
    my $state = $self->rng_seed;
    
    return sub {
        $state = (1664525 * $state + 1013904223) & 0xFFFFFFFF;
        return $state / 0xFFFFFFFF;
    };
}

sub decide {
    my ($self, $hand_strength, $game_state) = @_;
    
    my $pot_size       = $game_state->{pot_size} || 0;
    my $call_amount    = $game_state->{call_amount} || 0;
    my $valid_actions  = $game_state->{valid_actions} || [];
    my $min_bet        = $game_state->{min_bet} || 0;
    my $max_bet        = $game_state->{max_bet} || 0;
    my $betting_round  = $game_state->{betting_round} || 1;
    
    my %valid = map { $_ => 1 } @$valid_actions;
    
    my $config = $self->config;
    my $aggression = $config ? $config->aggression : 7;
    my $tightness = $config ? $config->tightness : 4;
    my $randomization = $config ? $config->randomization_factor : 0.15;
    my $slow_play_threshold = $config ? $config->slow_play_threshold : 0.85;
    my $call_threshold = $config ? $config->call_threshold : 0.25;
    my $bet_raise_frequency = $config ? $config->bet_raise_frequency : 0.40;

    my $variance = ($self->rng->() - 0.5) * 2 * $randomization;
    my $adjusted_strength = $hand_strength * (1 + $variance);
    $adjusted_strength = 0.0 if $adjusted_strength < 0.0;
    $adjusted_strength = 1.0 if $adjusted_strength > 1.0;
    
    my $play_threshold = 0.15 + ($tightness / 10) * 0.25;
    my $raise_threshold = 0.45 + ($tightness / 10) * 0.15;
    
    my $should_slow_play = 0;
    if ($adjusted_strength >= $slow_play_threshold) {
        $should_slow_play = ($self->rng->() < 0.3);
    }
    
    my $pot_odds = $call_amount > 0 ? $call_amount / ($pot_size + $call_amount) : 0;
    my $should_bluff = $self->should_bluff($pot_odds);
    my $should_bet_raise = ($self->rng->() < $bet_raise_frequency);
    
    my $action;
    my $amount = 0;
    
    if ($adjusted_strength < $call_threshold && !$should_bluff) {
        if ($call_amount == 0 && $valid{check}) {
            $action = 'check';
        } elsif ($valid{fold}) {
            $action = 'fold';
        } elsif ($valid{check}) {
            $action = 'check';
        } else {
            $action = $valid_actions->[0] || 'fold';
        }
    }
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
    else {
        if ($should_bet_raise && $adjusted_strength >= $play_threshold && !$should_slow_play) {
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
        elsif ($call_amount == 0 && $valid{check}) {
            $action = 'check';
        } elsif ($valid{call} && $call_amount > 0) {
            if ($adjusted_strength >= $call_threshold) {
                $action = 'call';
                $amount = $call_amount;
            } else {
                $action = $valid{fold} ? 'fold' : 'call';
                $amount = $call_amount if $action eq 'call';
            }
        } elsif ($valid{check}) {
            $action = 'check';
        } elsif ($valid{fold}) {
            $action = 'fold';
        } else {
            $action = $valid_actions->[0] || 'check';
        }
    }
    
    if ($should_bluff && ($valid{bet} || $valid{raise})) {
        $action = $valid{bet} ? 'bet' : 'raise';
        $amount = $self->calculate_bet_amount(0.3, $pot_size, $min_bet, $max_bet);
    }
    
    return {
        action     => $action,
        amount     => $amount,
        reasoning  => $should_bluff ? 'bluff' : 
                      $should_slow_play ? 'slow_play' : 
                      $adjusted_strength >= $raise_threshold ? 'strong_hand' :
                      $adjusted_strength < $call_threshold ? 'weak_hand' : 'medium_hand',
        confidence => $adjusted_strength,
    };
}

sub calculate_bet_amount {
    my ($self, $strength, $pot, $min, $max) = @_;
    
    return $min if $min >= $max;
    
    my $config = $self->config;
    my $aggression = $config ? $config->aggression : 7;
    
    my $aggression_multiplier = 0.3 + ($aggression / 10) * 0.9;
    my $strength_multiplier = 0.5 + $strength;
    
    my $bet = $pot * $aggression_multiplier * $strength_multiplier;
    
    $bet = $min if $bet < $min;
    $bet = $max if $bet > $max;
    
    return int($bet + 0.5);
}

sub should_bluff {
    my ($self, $pot_odds) = @_;
    
    my $config = $self->config;
    my $bluff_frequency = $config ? $config->bluff_frequency : 0.10;
    
    my $adjusted_frequency = $bluff_frequency * (1 + $pot_odds);
    $adjusted_frequency = 0.20 if $adjusted_frequency > 0.20;
    
    return $self->rng->() < $adjusted_frequency;
}

1;
