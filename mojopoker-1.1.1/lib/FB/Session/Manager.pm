package FB::Session::Manager;
use Moo;
use FB::Compat::Timer;

has 'grace_period' => (
    is      => 'rw',
    default => sub { 60 },  # seconds
);

has 'disconnected_sessions' => (
    is      => 'rw',
    default => sub { {} },  # login_id => { timestamp, table_id, chair_index, chips, auto_action, auto_call_limit }
);

has 'grace_timers' => (
    is      => 'rw',
    default => sub { {} },  # login_id => timer
);

has 'fb' => (
    is       => 'rw',
    weak_ref => 1,
    isa      => sub { die "Not a FB!" unless $_[0]->isa('FB') },
);

# Called when a player disconnects
# Requirements: 10.1, 10.2, 10.4
sub on_disconnect {
    my ($self, $login) = @_;
    
    return unless $login->has_user;
    
    my $login_id = $login->id;
    my $user_id = $login->user->id;
    
    # Find if player is seated at any table
    my $table_id;
    my $chair_index;
    my $chair;
    
    for my $tid (keys %{ $self->fb->tables }) {
        my $table = $self->fb->tables->{$tid};
        for my $i (0 .. $#{ $table->chairs }) {
            my $c = $table->chairs->[$i];
            if ($c->has_player && $c->player->has_login && $c->player->login->id eq $login_id) {
                $table_id = $tid;
                $chair_index = $i;
                $chair = $c;
                last;
            }
        }
        last if defined $table_id;
    }
    
    # Only save session if player is seated at a table
    return unless defined $table_id;
    
    # Save session state
    $self->disconnected_sessions->{$login_id} = {
        timestamp      => time,
        table_id       => $table_id,
        chair_index    => $chair_index,
        user_id        => $user_id,
        chips          => $chair->chips,
        auto_action    => $chair->auto_action || 'check_fold',
        auto_call_limit => $chair->auto_call_limit || 0,
    };
    
    # Mark chair as disconnected
    $chair->disconnected(1);
    
    # Start grace period timer
    my $timer = FB::Compat::Timer::timer(
        $self->grace_period,
        0,
        sub {
            $self->grace_expired($login_id);
        }
    );
    
    $self->grace_timers->{$login_id} = $timer;
    
    return 1;
}

# Called when a player reconnects within grace period
# Requirements: 10.1, 10.2
sub on_reconnect {
    my ($self, $login) = @_;
    
    return unless $login->has_user;
    
    my $login_id = $login->id;
    my $session = $self->disconnected_sessions->{$login_id};
    
    return unless $session;
    
    # Cancel grace timer
    if (my $timer = $self->grace_timers->{$login_id}) {
        FB::Compat::Timer::cancel_timer($timer);
        delete $self->grace_timers->{$login_id};
    }
    
    # Restore session
    my $table = $self->fb->tables->{ $session->{table_id} };
    if ($table) {
        my $chair = $table->chairs->[ $session->{chair_index} ];
        
        # Clear disconnected flag
        $chair->disconnected(0);
        
        # Update player's login reference
        if ($chair->has_player) {
            $chair->player->login($login);
        }
        
        # Add login back to watch list
        $self->fb->login_watch->{$login_id} = $session->{table_id};
        
        # Send table snapshot to reconnected player
        $self->fb->_send_table_summary($login, $table);
        
        # Notify player of any auto-actions taken during disconnection
        if ($session->{auto_actions_taken}) {
            $login->send(['reconnect_info', { 
                message => 'You were disconnected. Auto-actions were taken on your behalf.',
                actions => $session->{auto_actions_taken}
            }]);
        }
    }
    
    # Clean up session
    delete $self->disconnected_sessions->{$login_id};
    
    return 1;
}

# Called when grace period expires without reconnection
# Requirements: 10.4
sub grace_expired {
    my ($self, $login_id) = @_;
    
    my $session = $self->disconnected_sessions->{$login_id};
    return unless $session;
    
    my $table = $self->fb->tables->{ $session->{table_id} };
    if ($table) {
        my $chair = $table->chairs->[ $session->{chair_index} ];
        
        # If player is in hand, fold them
        if ($chair->is_in_hand) {
            # Mark for fold at next action
            $chair->check_fold(1);
        }
        
        # Mark seat as standing up after current hand
        $chair->stand_flag(1);
        $chair->disconnected(0);
    }
    
    # Clean up
    delete $self->grace_timers->{$login_id};
    delete $self->disconnected_sessions->{$login_id};
    
    return 1;
}

# Check if a login is currently disconnected
sub is_disconnected {
    my ($self, $login_id) = @_;
    return exists $self->disconnected_sessions->{$login_id};
}

# Record an auto-action taken during disconnection
sub record_auto_action {
    my ($self, $login_id, $action) = @_;
    
    my $session = $self->disconnected_sessions->{$login_id};
    return unless $session;
    
    $session->{auto_actions_taken} ||= [];
    push @{ $session->{auto_actions_taken} }, $action;
}

1;
