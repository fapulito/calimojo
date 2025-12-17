package FB::Poker;
use Moo::Role;
use FB::Poker::Table::Maker;

#use FB::Poker::Tournament::Freezeout;
#use FB::Poker::Tournament::Shootout;
#use FB::Poker::Tournament::Fifty50;
#use FB::Poker::Tournament::Bounty;

has 'table_maker' => (
    is      => 'rw',
    builder => '_build_table_maker',
);

sub _build_table_maker {
    my $self = shift;
    return FB::Poker::Table::Maker->new( lobby_watch => $self->lobby_watch, );
}

=pod
has 'pdb' => (
    is      => 'rw',
    builder => '_build_pdb',
);

sub _build_pdb {
    my $self = shift;
    return DBI->connect( "dbi:SQLite:dbname=/opt/mojopoker/db/poker.db", "",
        "" );
}
=cut

has 'table_count' => (
    is      => 'rw',
    default => sub { return 0 },
);

has 'lobby_watch' => (
    is      => 'rw',
    isa     => sub { die "Not a hash.\n" unless ref( $_[0] ) eq 'HASH' },
    builder => '_build_lobby_watch',
);

sub _build_lobby_watch {
    return {};
}

has 'table_option' => (
    is      => 'rw',
    isa     => sub { die "Not a hash.\n" unless ref( $_[0] ) eq 'HASH' },
    builder => '_build_table_option',
);

sub _build_table_option {
    return {
        wait_bb    => 0,
        auto_rebuy => 0,
        auto_muck  => 0,
        sit_out    => 0,
    };
}

=pod
has 'tour_option' => (
  is      => 'rw',
  isa     => sub { die "Not a hash.\n" unless ref( $_[0] ) eq 'HASH' },
  builder => '_build_tour_option',
);

sub _build_tour_option {
  return {
    start_time      => 0,
    open_time       => 0,
    seats_per_table => 0,
    max_players     => 0,
    min_players     => 0,
    start_when_full => 0,
    turn_clock      => 0,
    time_bank       => 0,
    level_duration  => 0,
    late_reg        => 0,
    start_chips     => 0,
    entry_fee       => 0,
    buy_in          => 0,
    payout_struct   => 0,
    reseat_limit    => 0,
    tour_class      => 0,
    game_class      => 1,
    limit           => 0,
    level_info      => 0,
  };
}
=cut

has 'game_option' => (
    is      => 'rw',
    isa     => sub { die "Not a hash.\n" unless ref( $_[0] ) eq 'HASH' },
    builder => '_build_game_option',
);

sub _build_game_option {
    return {
        chair_count => 0,
        small_blind => 0,
        big_blind   => 0,
        ante        => 0,
        turn_clock  => 0,
        time_bank   => 0,
        hi_mult     => 0,
        low_mult    => 0,
        auto_start  => 0,
        table_min   => 0,
        fix_limit   => 0,
        pot_cap     => 0,
        small_bet   => 0,
        limit       => 0,

        #director_id => 0,
        game_class => 1,
    };
}

has 'poker_command' => (
    is      => 'rw',
    isa     => sub { die "Not a hash.\n" unless ref( $_[0] ) eq 'HASH' },
    lazy    => 1,
    builder => '_build_poker_command',
);

sub _build_poker_command {
    my $self = shift;
    return {
        'create_ring' => [ \&create_ring, $self->game_option, 4 ],
        'destroy_ring' => [ \&destroy_ring, { table_id => 1 }, 4 ],
        'join_ring'    => [
            \&join_ring,
            { %{ $self->table_option }, table_id => 1, chair => 0, chips => 0 }, 2
        ],
        'fetch_cashier'  => [ \&fetch_cashier ],
        'reload'         => [ \&reload, {}, 2 ],


        'auto_match'    => [ \&auto_match,   { }, 2 ],
        'unjoin_ring'   => [ \&unjoin_ring,   { table_id => 1, chair   => 0 }, 2 ],
#        'wait_ring'     => [ \&wait_ring,     { table_id => 1 } ],
#        'unwait_ring'   => [ \&unwait_ring,   { table_id => 1 } ],
        'watch_table'   => [ \&watch_table,   { table_id => 1, auto_seat => 0, chair_id => 0 } ],
        'unwatch_table' => [ \&unwatch_table, { table_id => 1, tour_id => 0 } ],
        'table_chips' =>
          [ \&table_chips, { table_id => 1, chair => 0, chips => 0, deposit => 0 }, 2 ],
        'watch_lobby'   => [ \&watch_lobby,   {} ],
        'unwatch_lobby' => [ \&unwatch_lobby, {} ],
        'table_info'    => [ \&table_info,    { table_id => 1, tour_id => 0 } ],
        'table_opts' => [
            \&table_opts,
            { %{ $self->table_option }, table_id => 1, tour_id => 0 }
        ],
        'table_chat' =>
          [ \&table_chat, { table_id => 1, message => 1 }, 2 ],
        'bet' => [ \&bet, { table_id => 1, chips => 1, tour_id => 0 }, 2 ],
        'check' => [ \&check, { table_id => 1, tour_id  => 0 }, 2 ],
        'fold'  => [ \&fold,  { table_id => 1, tour_id  => 0 }, 2 ],
        'draw'  => [ \&draw,  { table_id => 1, card_idx => 1, tour_id => 0 }, 2 ],
        'discard' =>
          [ \&discard, { table_id => 1, card_idx => 1, tour_id => 0 }, 2 ],
        
        # Requirements: 11.1, 11.2, 11.3 - Set auto-action preferences
        'set_auto_action' => [ \&set_auto_action, { table_id => 1, auto_action => 1, auto_call_limit => 0 }, 2 ],

      # tournaments
      #'create_tour' => [
      #  #\&create_tour, { %{ $self->game_option }, %{ $self->tour_option } }, 4
      #  \&create_tour, $self->tour_option, 4
      #],
      #  'watch_tour'   => [ \&watch_tour,   { tour_id => 1 } ],
      #  'unwatch_tour' => [ \&unwatch_tour, { tour_id => 1 } ],
      #  'open_tour'    => [ \&open_tour,    { tour_id => 1 } ],
      #  'start_tour'   => [ \&start_tour,   { tour_id => 1 } ],
      #  'reg_tour'     => [ \&reg_tour,     { tour_id => 1 } ],
      #  'unreg_tour'   => [ \&unreg_tour,   { tour_id => 1 } ],

        # dealers choice
        'pick_game' =>
          [ \&pick_game, { table_id => 1, tour_id => 0, game => 1 }, 2 ],

        # admin
    };
}

has 'poker_option' => (
    is      => 'rw',
    isa     => sub { die "Not a hash.\n" unless ref( $_[0] ) eq 'HASH' },
    builder => '_build_poker_option',
);

sub _build_poker_option {
    my $self    = shift;
    my $opt_reg = qr/^[\w_]{1,20}$/;

    my %option = (
        chair => qr/^\d{1,2}$/,
        game  => qr/^\d{1,2}$/,

        chips     => qr/^[-+]?[0-9]*\.?[0-9]+$/,
        fix_limit => qr/^\d{1,10}$/,

        limit => qr/^(NL|PL|FL)$/,

        chair_count => qr/^[\w_]{1,20}$/,
        small_blind => qr/^[\w_]{1,20}$/,
        big_blind   => qr/^[\w_]{1,20}$/,
        ante        => qr/^[\w_]{1,20}$/,
        turn_clock  => qr/^[\w_]{1,20}$/,
        time_bank   => qr/^[\w_]{1,20}$/,
        eval_high   => qr/^[\w_]{1,20}$/,
        eval_low    => qr/^[\w_]{1,20}$/,
        hi_mult     => qr/^[\w_]{1,20}$/,
        low_mult    => qr/^[\w_]{1,20}$/,
        class       => qr/^[\w_]{1,20}$/,

        card_idx => sub {
            my $aref = shift;
            return unless $aref && ref $aref eq 'ARRAY' && scalar @$aref <= 7;
            for (@$aref) {
                return unless /^\d{1,2}$/;
            }
            return 1;
        },
        
        # Requirements: 11.1, 11.2, 11.3 - Validate auto-action values
        auto_action => qr/^(fold|check_fold|call_\d+)$/,
        auto_call_limit => qr/^\d{1,10}$/,
    );

=pod
    # game options
    my $sth = $self->pdb->prepare('SELECT (name) FROM game_option');
    $sth->execute;
    while ( my $opt = $sth->fetchrow_array ) {
        $option{$opt} = $opt_reg;
    }
=cut

    return {%option};
}

has 'table_list' => (
    is      => 'rw',
    isa     => sub { die "Not a hash.\n" unless ref( $_[0] ) eq 'HASH' },
    builder => '_build_table_list',
);

sub _build_table_list {
    return {};
}

=pod
has 'tour_list' => (
  is      => 'rw',
  isa     => sub { die "Not a hash.\n" unless ref( $_[0] ) eq 'HASH' },
  builder => '_build_tour_list',
);

sub _build_tour_list {
  return {};
}

has 'tour_count' => (
  is      => 'rw',
  default => sub { return 0 },
);
=cut

sub _fetch_inplay {
    my ( $self, $login ) = @_;

    my $inplay = 0;

    for my $ring (
       map  { $self->table_list->{$_} }
       grep { exists $self->table_list->{$_} }
       keys %{ $login->user->ring_play }
    ) {
       for my $chair (
         grep { $_->has_player && $_->player->login->id eq $login->id} @{ $ring->chairs }
       ) {
         $inplay += $chair->chips;
       }
   }
   return $inplay;
}

sub fetch_cashier {
    my ( $self, $login ) = @_;

    my $inplay = $self->_fetch_inplay($login);

    my $chips = $self->db->fetch_chips( $login->user->id );

    $login->send(["fetch_cashier_res", {
       login_id => $login->id,
       user_id => $login->user->id,
       inplay => $inplay,
       inbank => $chips,
    }]);
}

sub reload {

    my ( $self, $login ) = @_;
    my $inplay = $self->_fetch_inplay($login);

    my $chips = $self->db->fetch_chips( $login->user->id );
    my $total = $inplay + $chips;

    if ( $total < 400 ) {
        $self->db->credit_chips( $login->user->id, 400 - $total );
        $self->db->credit_invested( $login->user->id, 400 - $total );
    }
    $self->login_info($login);
}

sub auto_match {
    my ( $self, $login ) = @_;

    # First try to find existing tables with available seats
    for my $table ( values %{ $self->table_list }) {
       my ($has_player, $has_seat);
       #for my $chair (@{ $table->chairs }) {
       for my $chair ( 0 .. $#{ $table->chairs } ) {

          if ($table->chairs->[$chair]->has_player) {
             $has_player = 1;
             if ( $has_seat ) {
                $login->send(["auto_match_res", {
                   success => 1,
                   table_id => $table->table_id,
                   chair_id => $chair,
                }]);
                return;
             }
          }
          else {
             $has_seat = 1;
             if ( $has_player ) {
                $login->send(["auto_match_res", {
                   success => 1,
                   table_id => $table->table_id,
                   chair_id => $chair,
                }]);
                return;
             }
          }
       }
    }

    # If no suitable tables found, create a new test table for single player
    if (scalar keys %{ $self->table_list } == 0) {
        # Create a basic Texas Hold'em table
        my $table_opts = {
            table_id => $self->table_count + 1,
            chair_count => 6,
            game_class => 'holdem',
            limit => 'NL',
            small_blind => 1,
            big_blind => 2,
            auto_start => 1,
            db => $self->db,
        };

        my $table = $self->table_maker->ring_table($table_opts);
        if ($table) {
            $self->table_list->{ $table->table_id } = $table;
            $self->table_count($self->table_count + 1);
            $self->_notify_lobby(
                [ 'notify_create_ring', $self->_fetch_table_opts($table) ]
            );

            # Find first available chair
            for my $chair (0 .. $#{ $table->chairs }) {
                if (!$table->chairs->[$chair]->has_player) {
                    $login->send(["auto_match_res", {
                       success => 1,
                       table_id => $table->table_id,
                       chair_id => $chair,
                    }]);
                    return;
                }
            }
        }
    }

    $login->send(["auto_match_res", { success => 0 }]);
}

sub _create_ring {
    my ( $self, $login, $opts ) = @_;
    $opts->{table_id} = $self->table_count( $self->table_count + 1 );
    $opts->{db} = $self->db;

    #$opts->{director_id} = $login->user_id;
    my $game = $self->table_maker->ring_table($opts);
    return { success => 0 } unless $game;

    # add to table list
    $self->table_list->{ $game->table_id } = $game;
    $self->_notify_lobby(
        [ 'notify_create_ring', $self->_fetch_table_opts($game) ] );
    return { success => 1, table_id => $game->table_id };
}

sub create_ring {
    my ( $self, $login, $opts ) = @_;
    my $response = ['create_ring_res'];
    $response->[1] = $self->_create_ring( $login, $opts );
    $login->send($response);
}

sub join_ring {
    my ( $self, $login, $opts ) = @_;
    my $response = [ 'join_ring_res', { success => 0 } ];
    
    unless ( $login->has_user ) {
        $response->[1] = { success => 0, message => 'Please register or login first.', %$opts };
        $login->send($response);
        return;
    }
    
    my $table = $self->table_list->{ $opts->{table_id} };

    unless ( defined $table ) {
        $response->[1] = { success => 0, message => 'No such table.', %$opts };
        $login->send($response);
        return;
    }

    $response->[1] = $table->join( $login, $opts );
    unless ( $response->[1]->{success} ) {
        $login->send($response);
        return;
    }
    $login->send($response);

    # auto start
    if (   $table->game_over
        && $table->auto_start
        && $table->auto_start_count >= $table->auto_start )
    {
        $table->lobby_data( $table->_build_lobby_data );
        $table->auto_start_game(1);
    }
}

sub unjoin_ring {
    my ( $self, $login, $opts ) = @_;
    my $response = ['unjoin_ring_res'];
    my $table    = $self->table_list->{ $opts->{table_id} };
    unless ( defined $table ) {
        $response->[1] = { success => 0, message => 'No such table.', %$opts };
        $login->send($response);
        return;
    }

    my @chairs =
      defined $opts->{chair} ? ( $opts->{chair} ) : map { $_->index }
      @{ $table->_find_chairs($login) };

    my @unseated;
    for my $chair (@chairs) {
        my $res = $table->unjoin( $login, $chair );
        if ( $res->{success} ) {
            push @unseated, $res->{chair};
        }
    }
    if ( scalar @unseated ) {
        $response->[1] = {
            success  => 1,
            table_id => $table->table_id,
            chairs   => [@unseated],
        };
    }
    else {
        $response->[1] = {
            success  => 0,
            table_id => $table->table_id,
        };
    }
    $login->send($response);
}

sub wait_ring {
    my ( $self, $login, $opts ) = @_;
    my $response = ['wait_ring_res'];
    my $table    = $self->table_list->{ $opts->{table_id} };
    unless ( defined $table ) {
        $response->[1] = { success => 0, message => 'No such table.', %$opts };
        $login->send($response);
        return;
    }
    $response->[1] = $table->wait($login);
    $login->send($response);
}

sub unwait_ring {
    my ( $self, $login, $opts ) = @_;
    my $response = ['unwait_ring_res'];
    my $table    = $self->table_list->{ $opts->{table_id} };
    unless ( defined $table ) {
        $response->[1] = { success => 0, message => 'No such table.', %$opts };
        $login->send($response);
        return;
    }
    $response->[1] = $table->unwait($login);
    $login->send($response);
}

#sub watch_ring {
sub watch_table {
    my ( $self, $login, $opts ) = @_;
    my $response = ['watch_table_res'];
    my $table    = $self->_fetch_table($opts);

    unless ($table) {
        $response->[1] = { success => 0, message => 'No such table.', %$opts };
        $login->send($response);
        return;
    }
    $response->[1] = $table->watch($login);
    $response->[1]->{auto_seat} = $opts->{auto_seat} if $opts->{auto_seat};
    $response->[1]->{chair_id} = $opts->{chair_id} if $opts->{chair_id};
    $login->send($response);
    if ( $response->[1]->{success} ) {

        # If already seated, assume reconnect
        for my $c ( @{ $table->_find_chairs($login) } ) {
            $c->clear_check_fold;
            $c->clear_stand_flag;
            $c->player->login($login);
        }

        $self->_send_table_summary( $login, $table );

        # refresh chat channel
        if ( $table->chat ) {
            $login->send( $table->chat->refresh );
        }
    }
}

sub table_info {
    my ( $self, $login, $opts ) = @_;
    my $response = ['table_info_res'];
    my $table    = $self->table_list->{ $opts->{table_id} };
    unless ($table) {
        $response->[1] = { success => 0, message => 'No such table.', %$opts };
        $login->send($response);
        return;
    }
    $self->_send_table_summary( $login, $table );
}

sub _send_table_summary {
    my ( $self, $login, $table ) = @_;

    $login->send( [ 'player_snap', $table->_players_detail($login), ] );
    $login->send( [ 'table_snap',  $table->_table_detail ] );
}

#sub unwatch_ring {
sub unwatch_table {
    my ( $self, $login, $opts ) = @_;

    my $response = ['unwatch_table_res'];
    my $table    = $self->_fetch_table($opts);

    unless ($table) {
        $response->[1] = { success => 0, message => 'No such table.', %$opts };
        $login->send($response);
        return;
    }
    $response->[1] = $table->unwatch($login);

    $login->send($response);
}

sub destroy_ring {
    my ( $self, $login, $opts ) = @_;
    my $response = ['destroy_ring_res'];
    my $table    = $self->table_list->{ $opts->{table_id} };
    unless ($table) {
        $response->[1] = { success => 0, message => 'No such table.', %$opts };
        $login->send($response);
        return;
    }
    $response->[1] = $table->destroy;
    if ( $response->[1]->{success} ) {
        delete $self->table_list->{ $opts->{table_id} };
        delete $self->channels->{ $opts->{table_id} };

        $self->_notify_lobby( [ 'notify_destroy_ring', $response->[1] ] );
    }
    $login->send($response);
}

sub _notify_lobby {
    my ( $self, $response ) = @_;
    for my $log ( values %{ $self->lobby_watch } ) {
        $log->send($response);
    }
}

sub table_chips {
    my ( $self, $login, $opts ) = @_;
    my $response = ['table_chips_res'];

    my $table = $self->_fetch_table($opts);

    unless ( defined $table ) {
        $response->[1] = { success => 0, message => 'No such table.', %$opts };
        $login->send($response);
        return;
    }

    my $chair;
    for my $c (@{ $table->chairs }) {
       $chair = $c if ($c->has_player && $c->player->login->id eq $login->id); 
    }

    #my $chair = $table->chairs->[ $opts->{chair} ];
    #unless ( $chair
    #    && $chair->has_player
    #    && !$chair->is_in_hand )

    unless ($chair && !$chair->is_in_hand)
    {
        $response->[1] = { success => 0, message => 'Hand not over.', %$opts };
        $login->send($response);
        return;
    }

    #my $player = $table->chairs->[ $chair->index ]->player;
    #unless ( $opts->{chips} > 0 ) {
    #    $response->[1]->{message} = 'Invalid amt';
    #    $login->send($response);
    #    return;
    #}

    if ( $opts->{deposit} ) {
       my $keep = ($table->table_min + $table->table_max) / 2;
       my $deposit = $chair->player->chips - $keep;
       unless ($deposit > 0) {
          $response->[1]->{message} = 'Invalid amt';
          $login->send($response);
          return;
       }
       $self->db->credit_chips( $login->user->id, $deposit );
       $chair->player->chips( $keep );
    }
    elsif ( $opts->{chips} && $opts->{chips} > $self->db->fetch_chips( $login->user->id ) ) {
        $response->[1]->{message} = 'Not enough chips.';
        $login->send($response);
        return;
    }
    else {
       $self->db->debit_chips( $login->user->id, $opts->{chips} );
       $chair->player->chips( $chair->player->chips + $opts->{chips} );
    }

    my $re = {
        table_id => $table->table_id,
        balance => $self->db->fetch_chips( $login->user->id ),
        chips   => $chair->player->chips,
        chair   => $chair->index,
    };

    $response->[1] = { success => 1, %$re };
    $login->send($response);
    $table->_notify_watch( [ 'player_update', $re ] );
}

# lobby

sub watch_lobby {
    my ( $self, $login ) = @_;
    my $response = [ 'watch_lobby_res', { success => 1 } ];
    $self->_watch_lobby($login);
    $login->send($response);
}

sub _watch_lobby {
    my ( $self, $login ) = @_;
    $self->lobby_watch->{ $login->id } = $login;
    $self->_ring_snap($login);

    #$self->_tour_snap($login);
}

sub unwatch_lobby {
    my ( $self, $login ) = @_;
    my $response = ['unwatch_lobby_res'];
    $response->[1] = $self->_unwatch_lobby($login);
    $login->send($response);
}

sub _unwatch_lobby {
    my ( $self, $login ) = @_;
    delete $self->lobby_watch->{ $login->id };
    return { success => 1 };
}

sub _fetch_table_opts {
    my ( $self, $table ) = @_;
    my $res = {
        table_id    => $table->table_id,
        chair_count => $table->chair_count,
        game_class  => $table->game_class,

        #director_id => $table->director_id,
        limit => $table->limit,
    };
    $res->{ante}        = $table->ante        if $table->ante;
    $res->{big_blind}   = $table->big_blind   if $table->big_blind;
    $res->{small_blind} = $table->small_blind if $table->small_blind;
    $res->{game_choice} = $table->game_choice if $table->game_choice;
    if ( $table->dealer_choices ) {
        $res->{dealer_choices} = [ keys %{ $table->dealer_choices } ];
    }
    return { ( %{ $table->_fetch_lobby_update }, %$res ) };
}

sub _ring_snap {
    my ( $self, $login, $opts ) = @_;
    $login->send(
        [
            'ring_snap',
            [
                map { $self->_fetch_table_opts($_) }
                  values %{ $self->table_list }
            ]
        ]
    );
}

=pod
sub _tour_snap {
  my ( $self, $login ) = @_;
  $login->send(
    [
      'tour_snap',
      [ map { $_->summary } values %{ $self->tour_list } ]
    ]
  );
}
=cut

sub _poker_cleanup {
    my ( $self, $login ) = @_;

    $self->_unwatch_lobby($login);

    # remove user from table list
    if ( $login->has_user ) {
        for my $ring (
            map  { $self->table_list->{$_} }
            grep { exists $self->table_list->{$_} }
            keys %{ $login->user->ring_play }
          )
        {
            $ring->_unwatch($login);
            $ring->_unjoin_all($login);
            $ring->_unwait($login);
        }
    }
}

sub _validate_action {
    my ( $self, $login, $opts ) = @_;
    my $rv = { success => 1 };

    $rv->{table} = $self->table_list->{ $opts->{table_id} };

    if ( !defined $rv->{table} ) {
        return { success => 0, message => 'No such table', %$opts };
    }
    elsif ( $rv->{table}->game_over ) {
        return { success => 0, message => 'Game not started', %$opts };
    }

    my $chair = $rv->{table}->chairs->[ $rv->{table}->action ]
      if defined $rv->{table}->action;
    if (   $chair
        && $chair->has_player
        && $chair->player->login->id eq $login->id )
    {
        $rv->{chair} = $chair->index;
    }
    else {
        return { success => 0, message => 'Not your turn', %$opts };
    }

    $rv->{table_id} = $rv->{table}->table_id;
    return $rv;
}

sub bet {
    my ( $self, $login, $opts ) = @_;
    my $response = ['bet_res'];
    $response->[1] = $self->_validate_action( $login, $opts );
    unless ( $response->[1]->{success} ) {
        $login->send($response);
        return;
    }

    my $table = delete $response->[1]->{table};
    my $chair = $table->chairs->[ $response->[1]->{chair} ];

    unless ( $table->valid_act->{bet} || $table->valid_act->{bring} ) {
        $response->[1]->{message} = 'Invalid action';
        $response->[1]->{success} = 0;
        $login->send($response);
        return;
    }
    my $bet = $table->bet( $opts->{chips} );
    unless ($bet) {
        $response->[1]->{success} = 0;
        $response->[1]->{message} = 'Invalid bet';
        $login->send($response);
        return;
    }

    $response->[1]->{chips}             = $bet;
    $response->[1]->{balance}           = $chair->chips;
    $response->[1]->{chair}             = $chair->index;
    $response->[1]->{table_id}          = $table->table_id;
    $response->[1]->{in_pot_this_round} = $chair->in_pot_this_round;

    $login->send($response);

    $table->action_done;
}

sub check {
    my ( $self, $login, $opts ) = @_;

    my $response = ['check_res'];
    $response->[1] = $self->_validate_action( $login, $opts );
    unless ( $response->[1]->{success} ) {
        $login->send($response);
        return;
    }

    my $table = delete $response->[1]->{table};

    unless ( $table->legal_action('check') ) {
        $response->[1]->{message} = 'Invalid action.';
        $response->[1]->{success} = 0;
        $login->send($response);
        return;
    }

    if ( $table->check ) {
        $login->send($response);
        $table->action_done;
    }
    else {
        $response->[1]->{success} = 0;
        $login->send($response);
    }
}

sub fold {
    my ( $self, $login, $opts ) = @_;
    my $response = ['fold_res'];
    $response->[1] = $self->_validate_action( $login, $opts );
    unless ( $response->[1]->{success} ) {
        $login->send($response);
        return;
    }

    my $table = delete $response->[1]->{table};

    unless ( $table->legal_action('fold') ) {
        $response->[1]->{success} = 0;
        $response->[1]->{message} = 'Invalid action';
        $login->send($response);
        return;
    }

    if ( $table->fold ) {
        $login->send($response);
        $table->action_done;
    }
    else {
        $login->send($response);
    }
}

sub discard {
    my ( $self, $login, $opts ) = @_;
    my $response = ['discard_res'];
    $response->[1] = $self->_validate_action( $login, $opts );
    unless ( $response->[1]->{success} ) {
        $login->send($response);
        return;
    }

    my $table = delete $response->[1]->{table};

    unless ( $table->legal_action('discard') ) {
        $response->[1]->{success} = 0;
        $response->[1]->{message} = 'Invalid action.';
        $login->send($response);
        return;
    }

    if ( scalar @{ $opts->{card_idx} } > $table->max_discards ) {
        $response->[1]->{success}      = 0;
        $response->[1]->{message}      = 'Too many discards';
        $response->[1]->{max_discards} = $table->max_discards;
        $login->send($response);
        return;
    }
    my $idx = $table->discard( $opts->{card_idx} );
    if ($idx) {

        $response->[1]->{card_idx} = $idx;

        $login->send($response);
        delete $response->[1]->{success};
        $table->_notify_watch(

            [ 'notify_discard', $response->[1] ]
        );
        $table->action_done;
    }
    else {
        $response->[1]->{success} = 0;
        $response->[1]->{message} = 'Invalid discard';
        $login->send($response);
    }
}

sub draw {
    my ( $self, $login, $opts ) = @_;
    my $response = ['draw_res'];
    $response->[1] = $self->_validate_action( $login, $opts );
    unless ( $response->[1]->{success} ) {
        $login->send($response);
        return;
    }

    my $table = delete $response->[1]->{table};

    unless ( $table->legal_action('draw') ) {
        $response->[1]->{success} = 0;
        $response->[1]->{message} = 'Invalid action';
        $login->send($response);
        return;
    }

    if ( scalar @{ $opts->{card_idx} } > $table->max_draws ) {
        $response->[1]->{success}   = 0;
        $response->[1]->{message}   = 'Too many draws';
        $response->[1]->{max_draws} = $table->max_draws;
        $login->send($response);
        return;
    }
    my $card_map = $table->draw( $opts->{card_idx} );
    if ($card_map) {
        $login->send($response);
        delete $response->[1]->{success};
        my $hide_map = { map { $_ => undef } ( keys %$card_map ) };
        for my $log ( values %{ $table->watch_list } ) {

            $response->[1]->{card_map} =
              $login->id eq $log->id ? $card_map : $hide_map;
            $log->send( [ 'notify_draw', $response->[1], ] );
        }
        $table->action_done;
    }
    else {
        $login->send($response);
    }
}

# Requirements: 11.1, 11.2, 11.3 - Set auto-action preferences
sub set_auto_action {
    my ( $self, $login, $opts ) = @_;
    my $response = ['set_auto_action_res'];
    
    # Validate that user is logged in
    unless ( $login->has_user ) {
        $response->[1] = { 
            success => 0, 
            message => 'Must be logged in to set auto-action preferences' 
        };
        $login->send($response);
        return;
    }
    
    # Get the table
    my $table = $self->table_list->{ $opts->{table_id} };
    unless ($table) {
        $response->[1] = { 
            success => 0, 
            message => 'Table not found',
            table_id => $opts->{table_id}
        };
        $login->send($response);
        return;
    }
    
    # Find the player's chair at this table
    my $chair;
    for my $c ( @{ $table->chairs } ) {
        if ( $c->has_player && 
             $c->player->has_login && 
             $c->player->login->id eq $login->id ) {
            $chair = $c;
            last;
        }
    }
    
    unless ($chair) {
        $response->[1] = { 
            success => 0, 
            message => 'You are not seated at this table',
            table_id => $opts->{table_id}
        };
        $login->send($response);
        return;
    }
    
    # Validate auto_action value (fold, check_fold, call_N)
    my $auto_action = $opts->{auto_action};
    unless ( $auto_action =~ /^(fold|check_fold|call_\d+)$/ ) {
        $response->[1] = { 
            success => 0, 
            message => 'Invalid auto_action value. Must be fold, check_fold, or call_N',
            auto_action => $auto_action
        };
        $login->send($response);
        return;
    }
    
    # Set the auto-action preference
    $chair->auto_action($auto_action);
    
    # If it's a call_N action, extract and set the limit
    if ( $auto_action =~ /^call_(\d+)$/ ) {
        $chair->auto_call_limit($1);
    } elsif ( exists $opts->{auto_call_limit} ) {
        $chair->auto_call_limit($opts->{auto_call_limit});
    }
    
    $response->[1] = {
        success => 1,
        table_id => $opts->{table_id},
        chair => $chair->index,
        auto_action => $chair->auto_action,
        auto_call_limit => $chair->auto_call_limit,
        message => 'Auto-action preference updated'
    };
    
    $login->send($response);
}

# tournaments

#sub _fetch_tour_opts {
#  my ( $self, $tour ) = @_;
#  my $opt = {
#    tour_id => $tour->tour_id,
#    tables => $tour->tables,
#    status => $tour->status,
#    registered =>
#      { map { $_->player_id => $_->login->id } values %{ $tour->registered } },
#  };
#  for my $key ( keys %{ $self->tour_option } ) {
#    $opt->{$key} = $tour->$key;
#  }
#for my $key ( keys %{ $self->game_option } ) {
#  $opt->{$key} = $tour->{game_args}->{$key}
#    if exists $tour->{game_args}->{$key};
#}
#  return $opt;
#}

=pod
sub open_tour {
  my ( $self, $login, $opts ) = @_;
  my $response = ['open_tour_res'];
  my $tour     = $self->tour_list->{ $opts->{tour_id} };
  if ( $tour && $tour->director_id == $login->user_id ) {
    $response->[1] = $tour->open_tour;
  }
  else {
    $response->[1] = { success => 0 };
  }
  $login->send($response);
}

sub start_tour {
  my ( $self, $login, $opts ) = @_;
  my $response = ['start_tour_res'];
  my $tour     = $self->tour_list->{ $opts->{tour_id} }
    if exists $self->tour_list->{ $opts->{tour_id} };
  if ( $tour && $tour->director_id == $login->user_id ) {
    $response->[1] = $tour->start_tour;
  }
  else {
    $response->[1] = { success => 0 };
  }
  $login->send($response);
}

has 'tour_classes' => (
  is      => 'rw',
  isa     => sub { die "Not an hash!" unless ref( $_[0] ) eq 'HASH' },
  builder => '_build_tour_classes',
);

sub _build_tour_classes {
  return {
    1 => 'Freezeout',
    2 => 'Shootout',
    3 => 'Fifty50',
    4 => 'Bounty',
  };
}

sub create_tour {
  my ( $self, $login, $opts ) = @_;
  $opts->{tour_class} = 
      $opts->{tour_class} && exists $self->tour_classes->{ $opts->{tour_class} }
    ? $opts->{tour_class} 
    : 1;
  $opts->{tour_id}     = $self->tour_count( $self->tour_count + 1 );
  #$opts->{director_id} = $login->user_id;
  $opts->{table_maker} = $self->table_maker;
  $opts->{lobby_watch} = $self->lobby_watch;
  my $response = [ 'create_tour_res', { success => 1 } ];
  my $class =  'FB::Poker::Tournament::' . $self->tour_classes->{ $opts->{tour_class} };
  my $tour = $class->new($opts);
  $response->[1]->{tour_id} = $tour->tour_id;
  $self->tour_list->{ $tour->tour_id } = $tour;
  $login->send($response);
  $self->_notify_lobby(
    [ 'notify_create_tour', $tour->summary ] );
}

#sub tour_info {
sub watch_tour {
  my ( $self, $login, $opts ) = @_;
  my $response = $self->_watch_tour( $login, $opts );
  $login->send($response);
}

sub _watch_tour {
  my ( $self, $login, $opts ) = @_;
  my $response = ['watch_tour_res'];
  my $tour     = $self->tour_list->{ $opts->{tour_id} };
  if ($tour) {
    $response->[1] = $tour->_watch($login);
  }
  else {
    $response->[1] = { %$opts, success => 0 };
  }
  return $response;
}

sub unwatch_tour {
  my ( $self, $login, $opts ) = @_;
  my $response = $self->_unwatch_tour( $login, $opts );
  $login->send($response);
}

sub _unwatch_tour {
  my ( $self, $login, $opts ) = @_;
  my $response = ['unwatch_tour_res'];
  my $tour     = $self->tour_list->{ $opts->{tour_id} };
  if ($tour) {
    $response->[1] = $tour->_unwatch($login);
  }
  else {
    $response->[1] = { %$opts, success => 0 };
  }
  return $response;
}

sub reg_tour {
  my ( $self, $login, $opts ) = @_;
  my $response = ['reg_tour_res'];
  my $tour     = $self->tour_list->{ $opts->{tour_id} };
  if ($tour) {
    $response->[1] = $tour->register($login);
  }
  else {
    $response->[1] = { success => 0 };
  }
  $login->send($response);
}

sub unreg_tour {
  my ( $self, $login, $opts ) = @_;
  my $response = ['unreg_tour_res'];
  my $tour     = $self->tour_list->{ $opts->{tour_id} };
  if ($tour) {
    $response->[1] = $tour->unregister($login);
  }
  else {
    $response->[1] = { success => 0 };
  }
  $login->send($response);
}
=cut

sub _fetch_table {
    my ( $self, $opts ) = @_;
    return $self->table_list->{ $opts->{table_id} };
}

sub table_chat {
    my ( $self, $login, $opts ) = @_;
    my $response = ['table_chat_res'];
    my $table    = $self->_fetch_table($opts);

    unless ( $table && $table->chat ) {
        $response->[1] = { success => 0, message => 'No such chat.' };
        $login->send($response);
        return;
    }
    $table->chat->write( $login->id, $opts );
    delete $opts->{message};
    $response->[1] = { success => 1, %$opts };
    $login->send($response);
}

# dealers choice
sub pick_game {
    my ( $self, $login, $opts ) = @_;
    my $response = ['pick_game_res'];
    $response->[1] = $self->_validate_action( $login, $opts );
    unless ( $response->[1]->{success} ) {
        $login->send($response);
        return;
    }

    my $table = delete $response->[1]->{table};
    my $chair = $table->chairs->[ $response->[1]->{chair} ];
    unless ( $table->legal_action('choice') ) {
        $response->[1]->{message} = 'Invalid action';
        $response->[1]->{success} = 0;
        $login->send($response);
        return;
    }

    unless ( exists $table->dealer_choices->{ $opts->{game} } ) {
        $response->[1]->{message} = 'Invalid game';
        $response->[1]->{success} = 0;
        $login->send($response);
        return;
    }

    my $o =
      { map { $_ => $table->$_ }
          qw(table_id action button turn_clock time_bank watch_list game_over dealer_choices lobby_data)
      };
    %$o = ( %$o, %{ $table->dealer_choices->{ $opts->{game} } } );

    $o->{small_blind} = $table->small_blind if $table->small_blind;
    $o->{big_blind}   = $table->big_blind   if $table->big_blind;

    $o->{wait_list} = $table->wait_list if $table->wait_list;
    $o->{db} = $self->db;

    #$o->{tournament} = $table->tournament if $table->can('tournament');

    my $new_table = $self->table_maker->ring_table($o);

=pod
  my $new_table =
      $table->type eq 'r' ? $self->table_maker->ring_table($o)
    : $table->type eq 't' ? $self->table_maker->tour_table($o)
    :                       undef;
=cut

    unless ($new_table) {
        $response->[1]->{message} = 'Invalid game';
        $response->[1]->{success} = 0;
        $login->send($response);
        return;
    }

    $table->auto_start_event(undef);
    $table->auto_play_event(undef);
    $table->turn_event(undef);

    $new_table->sb( $table->sb ) if $new_table->can('sb');
    $new_table->bb( $table->bb ) if $new_table->can('bb');
    $new_table->chairs( $table->chairs );
    $new_table->chat( $table->chat );
    $new_table->game_choice( $new_table->game_class );
    $new_table->game_class('dealers');
    $self->table_list->{ $new_table->table_id } = $new_table;
    undef($table);
    $response->[1] = {
        success     => 1,
        game_choice => $new_table->game_choice,
        table_id    => $new_table->table_id,
        limit       => $new_table->limit,
    };
    $login->send($response);
    $new_table->_notify_watch( [ 'notify_pick_game', $response->[1] ] );
    $new_table->chat->write(
        'd',
        {
                message => 'The game is '
              . $new_table->limit . ' '
              . $new_table->show_name
        }
    );
    $new_table->dealer->shuffle_deck;
    $new_table->next_round(1);
    $new_table->begin_new_round;
}

sub table_opts {
    my ( $self, $login, $opts ) = @_;
    my $response = $self->_table_opts( $login, $opts );
    $login->send($response);
}

sub _table_opts {
    my ( $self, $login, $opts ) = @_;
    my $response = ['table_opts_res'];
    my $table    = $self->_fetch_table($opts);

    unless ($table) {
        $response->[1] = { success => 0, message => 'No such table.' };
        return $response;
    }

    my %parm = map { $_ => $opts->{$_} } keys %{ $self->table_option };
    for my $chair ( @{ $table->_find_chairs($login) } ) {
        my $p = $chair->player;
        %$p = ( %$p, %parm );
    }
    $response->[1] = { success => 1, table_id => $table->table_id, %parm };
    return $response;
}

# Check if current player is a house player and trigger strategy
# Requirements: 4.1, 4.2 - House player actions integrate with game engine
sub check_house_player_action {
    my ($self, $table) = @_;
    
    return unless defined $table;
    return unless defined $table->action;
    return if $table->game_over;
    
    my $chair = $table->chairs->[$table->action];
    return unless $chair && $chair->has_player;
    
    my $player = $chair->player;
    return unless $player;
    
    # Check if this is a house player using table's detection method
    return unless $table->_is_house_player($table->action);
    
    # Get the login for this player
    my $login = $self->_find_login_for_player($player);
    return unless $login;
    
    # Use strategy manager to decide action
    my $decision = $self->strategy_manager->decide_action($table, $chair);
    
    # Execute the decided action through existing validation
    # Requirement 4.2: Actions go through existing validation logic
    $self->_execute_house_player_action($login, $table, $decision);
}

# Find login object for a player
sub _find_login_for_player {
    my ($self, $player) = @_;
    
    # Search through login_list for matching user
    for my $login_id (keys %{$self->login_list}) {
        my $login = $self->login_list->{$login_id};
        
        # Defensive checks: ensure all required objects are defined
        next unless $login->has_user;
        next unless $player->has_login;
        next unless $player->login->has_user;
        
        # Compare underlying user IDs
        if ($login->user->id == $player->login->user->id) {
            return $login;
        }
    }
    
    return;
}

# Execute house player action based on strategy decision
sub _execute_house_player_action {
    my ($self, $login, $table, $decision) = @_;
    
    my $action = $decision->{action};
    my $table_id = $table->table_id;
    
    # Build options for action
    my $opts = {
        table_id => $table_id,
    };
    
    # Execute action through existing command handlers
    # This ensures all validation and game logic is applied
    if ($action eq 'bet' || $action eq 'raise') {
        $opts->{chips} = $decision->{amount};
        $self->bet($login, $opts);
    }
    elsif ($action eq 'call') {
        $opts->{chips} = $decision->{amount};
        $self->bet($login, $opts);
    }
    elsif ($action eq 'check') {
        $self->check($login, $opts);
    }
    elsif ($action eq 'fold') {
        $self->fold($login, $opts);
    }
    elsif ($action eq 'draw' || $action eq 'discard') {
        $opts->{card_idx} = $decision->{cards} || [];
        if ($action eq 'draw') {
            $self->draw($login, $opts);
        } else {
            $self->discard($login, $opts);
        }
    }
    else {
        # Default to check if possible, otherwise fold
        if ($table->legal_action('check')) {
            $self->check($login, $opts);
        } else {
            $self->fold($login, $opts);
        }
    }
}

1;