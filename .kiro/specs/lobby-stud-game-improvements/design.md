# Design Document: Lobby Stud Game Improvements

## Overview

This design document describes the implementation of improvements to the MojoPoker lobby experience, focusing on ensuring a 7-card stud game is always available, enhancing house player behavior to provide more engaging opponents, and documenting how to create additional demo games. The improvements address timing issues where house players allow the clock to expire and behavioral issues where they fold too frequently.

## Architecture

```mermaid
graph TB
    subgraph "Server Startup"
        BUILD[FB::BUILD]
        CTT[_create_test_tables]
        AHP[_add_house_players_to_table]
        INIT[_init_house_players]
    end
    
    subgraph "House Player Management"
        HPM[House Player Manager]
        HPPool[House Player Pool]
        HPTracker[Seated Tracker]
    end
    
    subgraph "Strategy Module"
        SM[Strategy::Manager]
        SE[Strategy::Evaluator::Stud]
        AD[Strategy::ActionDecider]
        Config[Strategy::Config]
    end
    
    subgraph "Table Events"
        Join[Player Join Event]
        Action[Action Required Event]
        Timer[House Action Timer]
    end
    
    BUILD --> INIT
    BUILD --> CTT
    CTT --> AHP
    INIT --> HPPool
    
    Join --> HPM
    HPM --> HPPool
    HPM --> HPTracker
    HPM --> AHP
    
    Action --> Timer
    Timer --> SM
    SM --> SE
    SM --> AD
    AD --> Config


## Components and Interfaces

### 1. House Player Pool Manager

Manages the pool of available house players and tracks which are seated at tables.

```perl
# In FB.pm - new attributes and methods

has 'house_player_pool' => (
    is      => 'rw',
    default => sub { [] },  # Array of available house player logins
);

has 'house_player_seated' => (
    is      => 'rw',
    default => sub { {} },  # table_id => [house_login_ids]
);

# Initialize house player pool at startup
sub _init_house_players {
    my $self = shift;
    
    for my $i (1..7) {
        my $username = "HousePlayer$i";
        my $user = $self->db->fetch_user({username => $username});
        next unless $user;
        
        my $mock_ws = FB::Login::WebSocket::Mock->new(
            remote_address => '127.0.0.1'
        );
        
        my $login = FB::Login::WebSocket->new({
            id => "house_${i}",
            websocket => $mock_ws,
            db => $self->db,
        });
        $login->user($user);
        
        push @{$self->house_player_pool}, $login;
        $self->login_list->{$login->id} = $login;
    }
}

# Get available house players not seated at any table
sub _get_available_house_players {
    my ($self, $count) = @_;
    
    my %seated;
    for my $table_players (values %{$self->house_player_seated}) {
        $seated{$_} = 1 for @$table_players;
    }
    
    my @available;
    for my $hp (@{$self->house_player_pool}) {
        next if $seated{$hp->id};
        push @available, $hp;
        last if scalar @available >= $count;
    }
    
    return @available;
}
```

### 2. Dynamic House Player Addition

Adds house players when a human player joins a table.

```perl
# In FB::Poker - modified join_ring method

sub join_ring {
    my ( $self, $login, $opts ) = @_;
    # ... existing validation ...
    
    $response->[1] = $table->join( $login, $opts );
    
    # After successful join, add house players if needed
    if ($response->[1]->{success}) {
        $self->_add_house_players_on_join($table, $login);
    }
    
    # ... rest of method ...
}

sub _add_house_players_on_join {
    my ($self, $table, $human_login) = @_;
    
    # Count current players
    my $current_count = 0;
    for my $chair (@{$table->chairs}) {
        $current_count++ if $chair->has_player;
    }
    
    # Target 7 players total
    my $target = 7;
    my $needed = $target - $current_count;
    
    return if $needed <= 0;
    
    # Get available house players
    my @house_players = $self->_get_available_house_players($needed);
    
    # Find available chairs (distributed, not clustered)
    my @available_chairs = $self->_get_distributed_chairs($table, scalar @house_players);
    
    # Add house players with slight delay
    for my $i (0..$#house_players) {
        my $hp = $house_players[$i];
        my $chair_idx = $available_chairs[$i];
        
        # Schedule addition with small delay
        FB::Compat::Timer::timer(0.5 + ($i * 0.3), 0, sub {
            $table->join($hp, {
                chair => $chair_idx,
                chips => 200,
            });
            push @{$self->house_player_seated->{$table->table_id}}, $hp->id;
        });
    }
}

sub _get_distributed_chairs {
    my ($self, $table, $count) = @_;
    
    my @empty_chairs;
    for my $i (0..$#{$table->chairs}) {
        push @empty_chairs, $i unless $table->chairs->[$i]->has_player;
    }
    
    # Distribute evenly across available chairs
    return @empty_chairs[0..($count-1)] if $count >= scalar @empty_chairs;
    
    my @selected;
    my $step = scalar(@empty_chairs) / $count;
    for my $i (0..$count-1) {
        push @selected, $empty_chairs[int($i * $step)];
    }
    
    return @selected;
}
```

### 3. House Player Action Timer

Ensures house players act within 2 seconds.

```perl
# In FB::Poker::Table - modified _house_player_action

has 'house_action_timer' => ( is => 'rw' );

sub _house_player_action {
    my $self = shift;
    return unless defined $self->action && $self->fb;
    
    my $chair = $self->chairs->[ $self->action ];
    return unless $chair && $chair->has_player;
    
    # Clear any existing timer
    $self->house_action_timer(undef);
    
    # Set a timer to ensure action completes within 2 seconds
    $self->house_action_timer(
        FB::Compat::Timer::timer(0.5, 0, sub {
            $self->_execute_house_action($chair);
        })
    );
}

sub _execute_house_action {
    my ($self, $chair) = @_;
    
    # Get strategy manager from FB instance
    my $strategy_manager = $self->fb->strategy_manager;
    
    my $decision;
    if ($strategy_manager) {
        $decision = $strategy_manager->decide_action($self, $chair);
    }
    
    # Default action if strategy fails
    unless ($decision && ref $decision eq 'HASH' && $decision->{action}) {
        $decision = {
            action => $self->legal_action('check') ? 'check' : 'fold',
            amount => 0,
        };
    }
    
    # Execute the action
    my $action = $decision->{action};
    
    if ($action eq 'fold') {
        $self->fold;
    }
    elsif ($action eq 'check' && $self->legal_action('check')) {
        $self->check;
    }
    elsif ($action eq 'bet' || $action eq 'call' || $action eq 'raise') {
        my $amount = $decision->{amount} || $self->_fetch_call_amt || $self->small_bet || 2;
        $self->bet($amount) || $self->check || $self->fold;
    }
    else {
        # Fallback
        $self->legal_action('check') ? $self->check : $self->fold;
    }
    
    $self->action_done;
}
```

### 4. Stud Hand Evaluator

Evaluates 7-card stud hands.

```perl
package FB::Poker::Strategy::Evaluator::Stud;
use Moo;
with 'FB::Poker::Strategy::HandEvaluator';

use FB::Poker::Eval;

# Evaluate best 5-card hand from 7 cards
# Requirement 5.2: Consider all 7 cards
sub evaluate_hand {
    my ($self, $hole_cards, $community_cards) = @_;
    
    # In stud, all cards are "hole" cards (no community)
    my @all_cards = @{$hole_cards || []};
    
    return 0.5 unless @all_cards >= 5;  # Need at least 5 cards
    
    # Use existing evaluator for best 5-card hand
    my $eval = FB::Poker::Eval->new;
    my $best_score = 0;
    
    # If 7 cards, find best 5-card combination
    if (@all_cards == 7) {
        # Generate all 21 combinations of 5 from 7
        for my $combo ($self->_combinations(\@all_cards, 5)) {
            my $score = $eval->score($combo);
            $best_score = $score if $score > $best_score;
        }
    }
    else {
        $best_score = $eval->score(\@all_cards);
    }
    
    # Normalize to 0.0-1.0 range
    return $self->normalize_score($best_score, 7462);  # Max hand rank
}

sub _combinations {
    my ($self, $arr, $k) = @_;
    return ([]) if $k == 0;
    return () if @$arr < $k;
    
    my @result;
    my $first = $arr->[0];
    my @rest = @$arr[1..$#$arr];
    
    # Combinations including first element
    for my $combo ($self->_combinations(\@rest, $k - 1)) {
        push @result, [$first, @$combo];
    }
    
    # Combinations excluding first element
    push @result, $self->_combinations(\@rest, $k);
    
    return @result;
}

sub evaluate_potential {
    my ($self, $hole_cards, $community_cards) = @_;
    return 0;  # Stud doesn't have draw potential in same way
}

sub select_discards {
    my ($self, $hand) = @_;
    return [];  # Stud doesn't have discards
}

1;
```

### 5. Updated Strategy Config

More aggressive default settings.

```perl
# In FB::Poker::Strategy::Config - updated defaults

has 'aggression' => (
    is      => 'rw',
    default => sub { 7 },  # Increased from 5 to 7
    isa     => sub { die unless $_[0] >= 1 && $_[0] <= 10 },
);

has 'tightness' => (
    is      => 'rw',
    default => sub { 4 },  # Decreased from 5 to 4 (looser play)
    isa     => sub { die unless $_[0] >= 1 && $_[0] <= 10 },
);

has 'call_threshold' => (
    is      => 'rw',
    default => sub { 0.25 },  # Call with hands above 25% strength
);

has 'bet_raise_frequency' => (
    is      => 'rw',
    default => sub { 0.40 },  # Bet/raise 40% of playable hands
);
```

### 6. Demo Game Configuration

```perl
# In FB.pm - updated _create_test_tables

sub _create_test_tables {
    my $self = shift;
    
    # Demo game configurations
    my @demo_games = (
        {
            game_class => 'holdem',
            limit => 'NL',
            chair_count => 6,
            small_blind => 1,
            big_blind => 2,
            house_players => 2,
        },
        {
            game_class => 'omaha',
            limit => 'PL',
            chair_count => 6,
            small_blind => 1,
            big_blind => 2,
            house_players => 2,
        },
        {
            game_class => 'sevenstud',  # 7-card stud
            limit => 'PL',
            chair_count => 8,
            ante => 1,
            bring => 2,
            house_players => 2,
        },
    );
    
    for my $config (@demo_games) {
        my $table_opts = {
            table_id => $self->table_count + 1,
            chair_count => $config->{chair_count},
            game_class => $config->{game_class},
            limit => $config->{limit},
            small_blind => $config->{small_blind} || 0,
            big_blind => $config->{big_blind} || 0,
            ante => $config->{ante} || 0,
            auto_start => 1,
            db => $self->db,
            fb => $self,
        };
        
        my $table = $self->table_maker->ring_table($table_opts);
        if ($table) {
            $self->table_list->{$table->table_id} = $table;
            $self->table_count($self->table_count + 1);
            
            # Add initial house players
            $self->_add_initial_house_players($table, $config->{house_players});
            
            $self->_notify_lobby(
                ['notify_create_ring', $self->_fetch_table_opts($table)]
            );
        }
    }
}
```

## Data Models

### House Player Pool Entry

```perl
{
    login_id => 'house_1',
    user_id => 101,
    username => 'HousePlayer1',
    chips => 1000000,
    seated_at => undef,  # table_id or undef if available
}
```

### Demo Game Configuration

```perl
{
    game_class => 'sevenstud',
    limit => 'PL',
    chair_count => 8,
    ante => 1,
    bring => 2,
    house_players => 2,  # Initial house players
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Stud Table Chair Count

*For any* 7-card stud table created by the system, the chair_count SHALL be 8.

**Validates: Requirements 1.2**

### Property 2: House Player Addition on Join

*For any* table where a human player joins and the total player count is less than 7, the system SHALL add house players until 7 players are seated.

**Validates: Requirements 2.1**

### Property 3: House Player Addition Timing

*For any* human player join event, house players SHALL be added within 5 seconds.

**Validates: Requirements 2.2**

### Property 4: House Player Seat Distribution

*For any* table where house players are added, the house players SHALL not occupy more than 2 consecutive seats when alternatives exist.

**Validates: Requirements 2.3**

### Property 5: House Player Action Timing

*For any* house player turn, the action SHALL be executed within 2 seconds of the turn beginning.

**Validates: Requirements 3.1, 3.2**

### Property 6: House Player Action Fallback

*For any* house player action that fails to execute normally, the system SHALL default to check if legal, otherwise fold.

**Validates: Requirements 3.4**

### Property 7: Bet/Raise Frequency

*For any* set of playable hands (strength > 0.25) across many decisions, the proportion of bet/raise actions SHALL be at least 40%.

**Validates: Requirements 4.3**

### Property 8: Medium Hand Call Rate

*For any* set of medium-strength hands (0.25 < strength < 0.6) facing a bet, the call rate SHALL be higher than the fold rate.

**Validates: Requirements 4.4**

### Property 9: Stud Evaluator Selection

*For any* house player in a sevenstud game, the Strategy_Module SHALL use the Stud evaluator.

**Validates: Requirements 5.1**

### Property 10: Stud Hand Evaluation

*For any* 7-card stud hand, the evaluator SHALL find the best 5-card combination from all 7 cards.

**Validates: Requirements 5.2**

### Property 11: Demo Game Creation

*For any* demo game configuration with a specified game_class, the system SHALL create a table with that game variant.

**Validates: Requirements 6.2**

### Property 12: House Player Chip Balance

*For any* house player account, the initial chip balance SHALL be 1000000.

**Validates: Requirements 7.2**

### Property 13: House Player Naming

*For any* house player account, the username SHALL match the pattern /^HousePlayer\d+$/.

**Validates: Requirements 7.3**

### Property 14: House Player Uniqueness

*For any* point in time, no house player SHALL be seated at more than one table simultaneously.

**Validates: Requirements 7.4**

## Error Handling

| Error Condition | Handling | Recovery |
|----------------|----------|----------|
| Strategy decision timeout | Use fallback action (check/fold) | Continue game |
| No available house players | Skip adding more house players | Game continues with fewer players |
| House player join fails | Log warning, try next house player | Continue with available players |
| Stud evaluator not found | Fall back to default evaluator | Continue with basic evaluation |
| Invalid demo game config | Skip that config, log error | Create other valid tables |

## Testing Strategy

### Property-Based Testing Framework

The module will use **Test::QuickCheck** (Perl) for property-based testing, configured to run a minimum of 100 iterations per property.

### Unit Tests

Unit tests will cover:
- Stud hand evaluation with known hands
- House player pool management
- Demo game configuration parsing
- Action timer behavior

### Property-Based Tests

Each correctness property will have a corresponding property-based test:

```perl
# Example: Property 5 - House Player Action Timing
# **Feature: lobby-stud-game-improvements, Property 5: House Player Action Timing**
sub prop_house_action_timing {
    my ($game_state) = @_;
    my $start_time = time();
    # Trigger house player action
    # Measure completion time
    my $elapsed = time() - $start_time;
    return $elapsed <= 2.0;
}

# Example: Property 10 - Stud Hand Evaluation
# **Feature: lobby-stud-game-improvements, Property 10: Stud Hand Evaluation**
sub prop_stud_best_hand {
    my ($seven_cards) = @_;
    my $evaluator = FB::Poker::Strategy::Evaluator::Stud->new;
    my $result = $evaluator->evaluate_hand($seven_cards, []);
    # Verify result is best possible from all 21 combinations
    return $result == expected_best_hand($seven_cards);
}
```

## Documentation: Creating Demo Games

### Method 1: Modify _create_test_tables in FB.pm

Add entries to the `@demo_games` array in the `_create_test_tables` method:

```perl
{
    game_class => 'razz',      # Game variant
    limit => 'FL',             # NL, PL, or FL
    chair_count => 8,          # Number of seats
    ante => 1,                 # Ante amount (for stud games)
    bring => 2,                # Bring-in (for stud games)
    house_players => 2,        # Initial house players
}
```

### Method 2: Use the Admin Script

```bash
perl script/mpadmin.pl create_ring \
    --game_class=sevenstud \
    --limit=PL \
    --chair_count=8 \
    --ante=1
```

### Available Game Classes

- `holdem` - Texas Hold'em
- `omaha` - Omaha
- `omahahilo` - Omaha Hi-Lo
- `sevenstud` - 7-Card Stud
- `sevenstudhilo` - 7-Card Stud Hi-Lo
- `sevenstudjokers` - 7-Card Stud Jokers Wild
- `razz` - Razz (7-Card Stud Low)
- `draw` - 5-Card Draw
- `badugi` - Badugi
- And more (see mpadmin.pl --help)
