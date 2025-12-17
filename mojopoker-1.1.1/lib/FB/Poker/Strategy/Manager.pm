package FB::Poker::Strategy::Manager;
use Moo;
use FB::Poker::Strategy::ActionDecider;
use FB::Poker::Strategy::Config;

# Central coordinator for house player strategy
# Requirements: 1.1, 2.4

has 'evaluators' => (
    is      => 'ro',
    default => sub { {} },  # game_class => evaluator mapping
);

has 'config' => (
    is  => 'rw',
    isa => sub { 
        die "Not a FB::Poker::Strategy::Config" 
            unless $_[0]->isa('FB::Poker::Strategy::Config') 
    },
    builder => '_build_config',
);

sub _build_config {
    return FB::Poker::Strategy::Config->new;
}

has 'action_decider' => (
    is      => 'lazy',
    builder => '_build_action_decider',
);

sub _build_action_decider {
    my ($self) = @_;
    return FB::Poker::Strategy::ActionDecider->new(
        config => $self->config,
    );
}

# Register a game-specific evaluator
# Requirement 2.4: Load appropriate evaluation rules for each variant
sub register_evaluator {
    my ($self, $game_class, $evaluator) = @_;
    
    die "game_class is required" unless defined $game_class;
    die "evaluator is required" unless defined $evaluator;
    
    # Store evaluator in registry
    $self->evaluators->{$game_class} = $evaluator;
    
    return 1;
}

# Get evaluator for a specific game class
sub get_evaluator {
    my ($self, $game_class) = @_;
    
    return unless defined $game_class;
    return $self->evaluators->{$game_class};
}

# Main entry point - called when house player's turn arrives
# Requirement 1.1: Evaluate game state and return valid action
# Returns: { action => 'bet|check|fold|draw', amount => N, cards => [] }
sub decide_action {
    my ($self, $table, $chair) = @_;
    
    # Validate inputs
    return $self->_default_action unless defined $table && defined $chair;
    return $self->_default_action unless $chair->has_player;
    
    # Get game class from table
    my $game_class = $table->game_class;
    return $self->_default_action unless defined $game_class;
    
    # Get appropriate evaluator for this game variant
    my $evaluator = $self->get_evaluator($game_class);
    
    # If no evaluator registered, use default safe action
    unless ($evaluator) {
        warn "No evaluator registered for game class: $game_class";
        return $self->_default_action;
    }
    
    # Extract hand information
    my $hole_cards = $chair->cards || [];
    my $community_cards = $table->community_cards || [];
    
    # Evaluate hand strength
    my $hand_strength = $evaluator->evaluate_hand($hole_cards, $community_cards);
    
    # Build game state for decision making
    my $game_state = $self->_build_game_state($table, $chair);
    
    # Get action decision from ActionDecider
    my $decision = $self->action_decider->decide($hand_strength, $game_state);
    
    # For draw games, add discard selection if needed
    if ($decision->{action} eq 'draw' || $decision->{action} eq 'discard') {
        my $discards = $evaluator->select_discards($hole_cards);
        $decision->{cards} = $discards;
    }
    
    return $decision;
}

# Build game state hash from table and chair
sub _build_game_state {
    my ($self, $table, $chair) = @_;
    
    # Calculate call amount
    my $call_amount = $table->_fetch_call_amt || 0;
    
    # Get valid actions based on table state
    my @valid_actions = $self->_get_valid_actions($table, $call_amount);
    
    # Calculate pot size
    my $pot_size = $table->pot || 0;
    for my $c (@{ $table->chairs }) {
        $pot_size += $c->in_pot_this_round if $c->in_pot_this_round;
    }
    
    # Get betting limits
    my $min_bet = $table->small_bet || 0;
    my $max_bet = $table->_fetch_max_bet || $chair->chips || 0;
    
    # Determine position (simplified)
    my $position = $self->_determine_position($table, $chair);
    
    # Count players still in hand
    my $players_in_hand = $table->live_chair_count || 0;
    
    return {
        table_id        => $table->table_id,
        game_class      => $table->game_class,
        betting_round   => $table->round || 1,
        pot_size        => $pot_size,
        call_amount     => $call_amount,
        min_bet         => $min_bet,
        max_bet         => $max_bet,
        position        => $position,
        players_in_hand => $players_in_hand,
        valid_actions   => \@valid_actions,
        community_cards => $table->community_cards || [],
        hole_cards      => $chair->cards || [],
    };
}

# Get list of valid actions for current game state
sub _get_valid_actions {
    my ($self, $table, $call_amount) = @_;
    
    my @actions;
    
    # Check which actions are legal
    push @actions, 'fold' if $table->legal_action('fold');
    push @actions, 'check' if $table->legal_action('check');
    push @actions, 'call' if $call_amount > 0;
    push @actions, 'bet' if $table->legal_action('bet');
    push @actions, 'raise' if $table->legal_action('raise');
    push @actions, 'draw' if $table->legal_action('draw');
    push @actions, 'discard' if $table->legal_action('discard');
    
    # If no actions available, default to check/fold
    unless (@actions) {
        push @actions, 'check', 'fold';
    }
    
    return @actions;
}

# Determine player position at table
sub _determine_position {
    my ($self, $table, $chair) = @_;
    
    my $button = $table->button;
    my $chair_index = $chair->index;
    
    # Simple position determination
    if ($chair_index == $button) {
        return 'button';
    }
    
    my $next_after_button = $table->next_chair($button);
    if ($chair_index == $next_after_button) {
        return 'sb';  # small blind
    }
    
    # For more complex position logic, would need to track more state
    return 'middle';
}

# Default safe action when we can't make a decision
sub _default_action {
    my ($self) = @_;
    
    return {
        action     => 'check',
        amount     => 0,
        cards      => [],
        reasoning  => 'default',
        confidence => 0.0,
    };
}

1;
