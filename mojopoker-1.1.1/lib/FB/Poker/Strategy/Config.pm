package FB::Poker::Strategy::Config;
use Moo;

# Configuration management for strategy parameters
# Requirements: 5.1, 5.2, 5.4

# Aggression level: 1-10 scale
# Higher values = more frequent and larger bets
has 'aggression' => (
    is      => 'rw',
    default => sub { 5 },
);

# Tightness level: 1-10 scale  
# Higher values = stricter hand requirements to enter pots
has 'tightness' => (
    is      => 'rw',
    default => sub { 5 },
);

# Bluff frequency: 0.05-0.15 (5-15%)
# Probability of bluffing with weak hands
has 'bluff_frequency' => (
    is      => 'rw',
    default => sub { 0.10 },
);

# Randomization factor: ±15% variance in decision thresholds
has 'randomization_factor' => (
    is      => 'rw',
    default => sub { 0.15 },
);

# Hand strength threshold for slow-playing
has 'slow_play_threshold' => (
    is      => 'rw',
    default => sub { 0.85 },
);

# Validate all configuration parameters
# Returns 1 if valid, 0 otherwise
# Requirement 5.4: Invalid values should be rejected
sub validate {
    my ($self) = @_;
    
    # Validate aggression: must be 1-10
    my $aggression = $self->aggression;
    return 0 unless defined $aggression;
    return 0 unless $aggression >= 1 && $aggression <= 10;
    
    # Validate tightness: must be 1-10
    my $tightness = $self->tightness;
    return 0 unless defined $tightness;
    return 0 unless $tightness >= 1 && $tightness <= 10;
    
    # Validate bluff_frequency: must be 0.05-0.15
    my $bluff = $self->bluff_frequency;
    return 0 unless defined $bluff;
    return 0 unless $bluff >= 0.05 && $bluff <= 0.15;
    
    # Validate randomization_factor: must be non-negative
    my $rand_factor = $self->randomization_factor;
    return 0 unless defined $rand_factor;
    return 0 unless $rand_factor >= 0;
    
    # Validate slow_play_threshold: must be 0.0-1.0
    my $slow_play = $self->slow_play_threshold;
    return 0 unless defined $slow_play;
    return 0 unless $slow_play >= 0.0 && $slow_play <= 1.0;
    
    return 1;
}

# Create a new config from a hash, validating before applying
# Returns undef if validation fails
sub from_hash {
    my ($class, $params) = @_;
    
    my $config = $class->new(%$params);
    return undef unless $config->validate;
    return $config;
}

# Update config from hash, only if new values are valid
# Returns 1 on success, 0 on failure (keeps previous values)
sub update {
    my ($self, $params) = @_;
    
    # Store current values
    my %backup = (
        aggression           => $self->aggression,
        tightness            => $self->tightness,
        bluff_frequency      => $self->bluff_frequency,
        randomization_factor => $self->randomization_factor,
        slow_play_threshold  => $self->slow_play_threshold,
    );
    
    # Apply new values
    $self->aggression($params->{aggression}) 
        if exists $params->{aggression};
    $self->tightness($params->{tightness}) 
        if exists $params->{tightness};
    $self->bluff_frequency($params->{bluff_frequency}) 
        if exists $params->{bluff_frequency};
    $self->randomization_factor($params->{randomization_factor}) 
        if exists $params->{randomization_factor};
    $self->slow_play_threshold($params->{slow_play_threshold}) 
        if exists $params->{slow_play_threshold};
    
    # Validate new configuration
    if ($self->validate) {
        return 1;
    }
    
    # Restore previous values on validation failure
    $self->aggression($backup{aggression});
    $self->tightness($backup{tightness});
    $self->bluff_frequency($backup{bluff_frequency});
    $self->randomization_factor($backup{randomization_factor});
    $self->slow_play_threshold($backup{slow_play_threshold});
    
    return 0;
}

1;
