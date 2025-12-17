package FB;
use Moo;

with 'FB::Poker';

use feature qw(state);

#use DBI;
use FB::Compat::Timer;
use FB::Db;
use SQL::Abstract;
use Mojo::JSON qw(j);
use Digest::SHA qw(hmac_sha256);
use Crypt::Eksblowfish::Bcrypt qw(bcrypt en_base64);
use FB::Poker;
use FB::Chat;
use FB::Login;
use FB::Login::WebSocket;
use FB::Login::WebSocket::Mock;
use FB::User;
use FB::Poker::Strategy::Manager;
use FB::Poker::Strategy::Evaluator::Holdem;
use FB::Poker::Strategy::Evaluator::Omaha;
use FB::Poker::Strategy::Evaluator::Draw;
use FB::Session::Manager;
use Time::Piece;
use Time::Seconds;
use MIME::Base64;
use Data::Dumper;

has 'cycle_event' => ( is => 'rw', );

has 'prize_timer' => (
    is      => 'rw',
    builder => '_build_prize_timer',
);

has 'facebook_secret' => ( is => 'rw', );

# reset timer
sub _build_prize_timer {
    my $self     = shift;
    my $t        = localtime;

    $t -= $t->sec;
    $t -= $t->min * 60;
    $t -= $t->hour * 60 * 60;
    $t += 24 * 60 * 60;

    my $seconds = $t - localtime;
    return FB::Compat::Timer::timer($seconds, 0, sub {
        $self->prize_timer( $self->_build_prize_timer );
        $self->db->reset_leaders;
        $self->_update_all_logins;
        $self->_notify_leaders;
    });
}

has 'news' => (
    is      => 'rw',
    isa     => sub { die "Not an array.\n" unless ref( $_[0] ) eq 'ARRAY' },
    default => sub { return [] },
);

has 'address_block' => (
    is  => 'rw',
    isa => sub { die "Not a hash.\n" unless ref( $_[0] ) eq 'HASH' },
);

has 'max_idle' => (
    is      => 'rw',
    default => sub { return 600 },
);

has 'secret' => (
    is      => 'rw',
    default => sub { return 'g)ue(ss# %m4e &i@f y25o*u c*69an' },
);

has 'start_time' => (
    is      => 'rw',
    default => sub { return time },
);

#has 'sql' => (
#    is => 'rw',
#    isa =>
#      sub { die "Not a SQL::Abstract!" unless $_[0]->isa('SQL::Abstract') },
#    builder => '_build_sql',
#);

#sub _build_sql {
#    my $self = shift;
#    return SQL::Abstract->new;
#}

has 'db' => (
    is      => 'rw',
    isa     => sub { die "Not a FB::Db" unless $_[0]->isa('FB::Db') },
    builder => '_build_db',
);

sub _build_db {
    my $self = shift;
    return FB::Db->new;
}

has 'strategy_manager' => (
    is      => 'rw',
    isa     => sub { die "Not a FB::Poker::Strategy::Manager" unless $_[0]->isa('FB::Poker::Strategy::Manager') },
    builder => '_build_strategy_manager',
);

sub _build_strategy_manager {
    my $self = shift;
    my $manager = FB::Poker::Strategy::Manager->new;
    
    # Register evaluators for different game variants
    # Requirement 2.4: Load appropriate evaluation rules for each variant
    $manager->register_evaluator('holdem', FB::Poker::Strategy::Evaluator::Holdem->new);
    $manager->register_evaluator('omaha', FB::Poker::Strategy::Evaluator::Omaha->new);
    $manager->register_evaluator('omahahilo', FB::Poker::Strategy::Evaluator::Omaha->new);
    $manager->register_evaluator('draw', FB::Poker::Strategy::Evaluator::Draw->new);
    
    return $manager;
}

# Requirements: 10.1, 10.2
has 'session_manager' => (
    is      => 'rw',
    isa     => sub { die "Not a FB::Session::Manager" unless $_[0]->isa('FB::Session::Manager') },
    builder => '_build_session_manager',
);

sub _build_session_manager {
    my $self = shift;
    return FB::Session::Manager->new(fb => $self);
}

has 'login_list' => (
    is      => 'rw',
    isa     => sub { die "Not a hash.\n" unless ref( $_[0] ) eq 'HASH' },
    builder => '_build_login_list',
);

sub _build_login_list {
    return {};
}

has 'login_watch' => (
    is      => 'rw',
    isa     => sub { die "Not a hash.\n" unless ref( $_[0] ) eq 'HASH' },
    builder => '_build_login_watch',
);

sub _build_login_watch {
    return {};
}

has 'user_map' => (
    is      => 'rw',
    isa     => sub { die "Not a hash.\n" unless ref( $_[0] ) eq 'HASH' },
    builder => '_build_user_map',
);

sub _build_user_map {
    return {};
}

has 'channels' => (
    is      => 'rw',
    isa     => sub { die "Not a hash.\n" unless ref( $_[0] ) eq 'HASH' },
    builder => '_build_channels',
);

sub _build_channels {
    return {};
}

has 'command' => (
    is      => 'rw',
    isa     => sub { die "Not a hash.\n" unless ref( $_[0] ) eq 'HASH' },
    builder => '_build_command',
);

sub _build_command {
    return {
        sys_info => [ \&sys_info, {} ],
        register => [
            \&register,
            {
                username => 0,
                password => 0,
                email    => 0,
                birthday => 0,
                handle   => 0
            }
        ],
        login_book => [ \&login_book, { bookmark => 1 } ],
        login      => [ \&login,      { username => 1, password => 1 } ],
        authorize  => [ \&authorize,  { status   => 1, authResponse => 1 } ],
        guest_login    => [ \&guest_login, {} ],
        watch_logins   => [ \&watch_logins ],
        unwatch_logins => [ \&unwatch_logins ],
        login_info     => [ \&login_info ],
        #fetch_cashier  => [ \&fetch_cashier ],
        update_profile => [
            \&update_profile,
            {
                first_name => 0,
                last_name  => 0,
                picture    => 0,
                id    => 0,
            },
            2
        ],
        logout         => [ \&logout,         {} ],
        block          => [ \&block,          { login_id => 1 }, 2 ],
        unblock        => [ \&unblock,        { login_id => 1 }, 2 ],
        join_channel   => [ \&join_channel,   { channel => 1 }, 2 ],
        unjoin_channel => [ \&unjoin_channel, { channel => 1 }, 2 ],
        write_channel => [ \&write_channel, { channel => 1, message => 1 }, 2 ],
        ping          => [ \&ping,          {} ],

        # ADMIN
        credit_chips => [ \&credit_chips, { user_id => 1, chips => 1 }, 4 ],
        logout_all => [ \&logout_all, {}, 4 ],
        logout_login    => [ \&logout_login,    { login_id => 1 }, 4 ],
        logout_user     => [ \&logout_user,     { user_id  => 1 }, 4 ],
        create_channel  => [ \&create_channel,  { channel  => 1 }, 4 ],
        destroy_channel => [ \&destroy_channel, { channel  => 1 }, 4 ],
        update_news     => [ \&update_news,     { news     => 1 }, 4 ],
    };
}

has 'option' => (
    is      => 'rw',
    isa     => sub { die "Not a hash.\n" unless ref( $_[0] ) eq 'HASH' },
    builder => '_build_option',
);

sub _build_option {
    return {
        username => qr/^[a-zA-Z0-9\s!@#\$%^&\*\(\)_]{2,20}$/,
        password => qr/^[a-zA-Z0-9\s!@#\$%^&\*\(\)_]{2,20}$/,
        handle   => qr/^[a-zA-Z0-9\s!@#\$%^&\*\(\)_]{2,20}$/,
        channel  => qr/^[\w\s_]{1,20}$/,
        message  => qr/^[\w\s\.\,\?!@#\$%^&\*\(\)_]{1,255}$/,
        email    => qr/^\w{2,20}@\w{2,20}\.\w{3,8}/,
        birthday => qr/^[\w\s_\.\\\-]{40}$/,
        bookmark => qr/^\w{40}$/,
        bitcoin  => qr/^\w{52}$/,

        #login_id => qr/^\d{1,12}$/,
        user_id  => qr/^\d{1,12}$/,
        table_id => qr/^\d{1,12}$/,
    };
}

sub validate {

    my ( $self, $cmd, $opts ) = @_;

    # missing required param
    my $valid = $self->command->{$cmd}->[1];
    for ( keys %$valid ) {
        if ( $valid->{$_} && !defined $opts->{$_} ) {
            return { error => 'missing_option', command => $cmd, option => $_ };
        }
    }

    # invalid key or value
    while ( my ( $key, $value ) = each %$opts ) {
        if ( exists $valid->{$key} && defined $value ) {
            if ( ref $self->option->{$key} eq 'Regexp'
                && $value !~ $self->option->{$key} )
            {
                return {
                    error   => 'invalid_value',
                    command => $cmd,
                    option  => $key
                };
            }
            elsif ( ref $self->option->{$key} eq 'CODE'
                && !$self->option->{$key}($value) )
            {
                return {
                    error   => 'invalid_value',
                    command => $cmd,
                    option  => $key
                };
            }
        }
        else {
            return {
                error   => 'invalid_option',
                command => $cmd,
                option  => $key
            };
        }
    }

    # Note: Password hashing is done in register(), not here
    # validate() only performs format checks, not transformations
    return $opts;
}

sub request {
    my ( $self, $login, $aref ) = @_;

    #my ( $self, $login, $json ) = @_;

    #my $aref = eval { decode_json ref $json ? $$json : $json };
    #if ($@) {
    #  $login->req_error;
    #  $login->send( [ 'malformed_json', { message => $@ } ] );
    #  return;
    #}

    if ( ref $aref ne 'ARRAY' ) {
        $login->req_error;
        $login->send( ['invalid_command_format'] );
        return;
    }

    my ( $cmd, $opts ) = @$aref;

    if ( ref $cmd || !exists $self->command->{$cmd} ) {
        $login->req_error;
        $login->send( ['invalid_command'] );
        return;
    }

    my $level = $self->command->{$cmd}->[2];
    my $login_level = $login->has_user ? $login->user->level : 0;
    if ( $level && $login_level < $level ) {
        $login->req_error;
        $login->send(
            [ 'permission_denied', { success => 0, command => $cmd } ] );
        return;
    }

    if ( $opts && ref $opts ne 'HASH' ) {
        $login->req_error;
        $login->send( [ 'invalid_option_format', { command => $cmd } ] );
        return;
    }

    $opts = $self->validate( $cmd, $opts );
    if ( $opts->{error} ) {
        $login->req_error;
        $login->send( [ 'invalid_option', $opts ] );
        return;
    }

    $login->last_req_time(time);

    $self->command->{$cmd}->[0]( $self, $login, $opts );
}

#sub _notify_login_watch {
#    my ( $self, $msg ) = @_;
#    for my $log ( values %{ $self->login_watch } ) {
#        $log->send($msg);
#    }
#}

sub _notify_logins {
    my $self        = shift;
    my $login_count = keys %{ $self->login_list };
    for my $log ( values %{ $self->login_list } ) {
        $log->send( [ 'notify_logins', { login_count => $login_count } ] );
    }
}

sub _fetch_login_opts {
    my ( $self, $login ) = @_;
    return {
        login_id       => $login->id,
        remote_address => $login->remote_address,
    };
}

sub watch_logins {
    my ( $self, $login ) = @_;
    $login->send( [ 'watch_logins_res', { success => 1 } ] );
    $self->_watch_logins($login);
}

sub _watch_logins {
    my ( $self, $login ) = @_;
    $self->login_watch->{ $login->id } = $login;
    $self->_login_snap($login);
}

sub unwatch_logins {
    my ( $self, $login ) = @_;
    $self->_unwatch_logins($login);
    $login->send( [ 'unwatch_logins_res', { success => 1 } ] );
}

sub _unwatch_logins {
    my ( $self, $login ) = @_;
    delete $self->login_watch->{ $login->id };
}

sub _login_snap {
    my ( $self, $login ) = @_;
    $login->send(
        [
            'login_snap',
            [
                map { $self->_fetch_login_opts($_) }
                  values %{ $self->login_list }
            ]
        ]
    );
}

sub sys_info {
    my ( $self, $login ) = @_;
    my $now = time;
    $login->send(
        [
            'sys_info_res',
            {
                epoch      => $now,
                uptime     => ( $now - $self->start_time )->pretty,
                login_list => scalar keys %{ $self->login_list },
            }
        ]
    );
}

sub _new_login {
    my ( $self, $opts ) = @_;
    my $connection_id = $opts->{websocket}->connection;
    return unless $connection_id;
    $opts->{id}         = $connection_id;
    $opts->{last_visit} = time;

    #$opts->{db}         = $self->db;
    return FB::Login::WebSocket->new($opts);
}

sub _guest_login {
    my ( $self, $opts ) = @_;
    my $login = $self->_new_login($opts);
    return unless $login;
    
    # Create a guest user with starting chips immediately on connect
    my $guest_opts = { chips => 400, invested => 400 };
    my $user = $self->db->new_user($guest_opts);
    
    # Error handling - return undef if user creation failed
    unless ($user) {
        warn "Failed to create guest user: database error";
        return;
    }
    
    $login->user($user);
    $self->user_map->{ $login->user->id } = $login->id;
    
    $self->join_channel( $login, { channel => 'main' } );

    #$self->login_list->{ $login->id } = $login;
    return $login;
}

sub guest_login {
    my ( $self, $login ) = @_;

    # Create a guest user with starting chips if not already logged in
    unless ( $login->has_user ) {
        my $guest_opts = { chips => 400, invested => 400 };
        my $user = $self->db->new_user($guest_opts);
        
        # Error handling - send error response if user creation failed
        unless ($user) {
            warn "Failed to create guest user: database error";
            $login->send(['guest_login', {
                success => 0,
                error => 'user_creation_failed',
                message => 'Unable to create guest account. Please try again.'
            }]);
            return;
        }
        
        $login->user($user);
        $self->user_map->{ $login->user->id } = $login->id;
    }

    $self->login_list->{ $login->id } = $login;
    $login->send(
        [
            'guest_login',
            {
                success  => 1,
                login_id => $login->id,
                user_id  => $login->user->id,
                chips    => $self->db->fetch_chips( $login->user->id ),
                timer    => int( $self->prize_timer->remaining ),
            }
        ]
    );

    $self->_watch_lobby($login);
    #$self->_login_snap($login);
    $self->_notify_logins();
    $login->send(
        [ 'notify_leaders', { leaders => $self->db->fetch_leaders } ] );
}

sub _bcrypt_hash {
    my ($self, $plaintext) = @_;
    # Generate bcrypt hash with cost factor 12
    # Salt format: $2a$12$<22 base64 chars>
    my $cost = 12;
    my $salt_bytes = '';
    for (1..16) {
        $salt_bytes .= chr(int(rand(256)));
    }
    my $salt = sprintf('$2a$%02d$%s', $cost, en_base64($salt_bytes));
    return bcrypt($plaintext, $salt);
}

sub _bcrypt_verify {
    my ($self, $plaintext, $stored_hash) = @_;
    return unless $stored_hash && $plaintext;
    # bcrypt() with the stored hash as salt will produce the same hash if password matches
    my $check_hash = bcrypt($plaintext, $stored_hash);
    return $check_hash eq $stored_hash;
}

sub register {
    my ( $self, $login, $opts ) = @_;

    my $response = ['register_res'];

    if ( $login->has_user ) {
        $response->[1] = {
            success => 0,
            message => 'Already registered.',
            user_id => $login->user->id
        };
        $login->send($response);
        return;
    }

    # Hash password with bcrypt before storing (cost 12)
    if ($opts->{password}) {
        $opts->{password} = $self->_bcrypt_hash($opts->{password});
    }

    # add user
    my $user = $self->db->new_user($opts);
    
    # Error handling - send error response if user creation failed
    unless ($user) {
        warn "Failed to create registered user: database error";
        $response->[1] = {
            success => 0,
            message => 'Registration failed. Please try again.'
        };
        $login->send($response);
        return;
    }
    
    $login->user($user);
    $self->user_map->{ $login->user->id } = $login->id;

    #$login->user->db( $self->db );

    # update user
    #$self->_update_user( $login, $opts );
    $self->db->credit_chips( $login->user->id, 400 );
    $self->db->credit_invested( $login->user->id, 400 );

    # update user database
    my $ui = $self->_fetch_user_info($login);
    $self->db->update_user( $ui, $login->user->id );

    $response->[1] = { success => 1, %{ $ui } };
    $login->send($response);
}

#sub _update_user {

#    my ( $self, $login, $opts ) = @_;
#    $opts->{last_visit} = time;

#$opts->{remote_address} = $login->websocket->remote_address
#  if $login->websocket->is_websocket;

#    my ( $stmt, @bind ) =
#      $self->sql->update( 'user', $opts, { id => $opts->{id} } );
#    my $sth = $self->db->prepare($stmt);
#    $sth->execute(@bind);
#}

sub update_profile {
    my ( $self, $login, $opts ) = @_;
    my $response = ['update_profile_res'];
    $response->[1] = $self->_update_profile( $login, $opts );
    $login->send($response);
}

sub _update_profile {
    my ( $self, $login, $opts ) = @_;
    return { success => 0 } unless $login->has_user;
    $login->user->first_name($opts->{first_name});
    $login->user->last_name($opts->{last_name});
    $login->user->username($opts->{first_name});
    $login->user->handle($opts->{first_name});
    $login->user->profile_pic($opts->{picture}->{data}->{url});

    # update user database
    my $ui = $self->_fetch_user_info($login);
    $self->db->update_user( $ui, $login->user->id );

    return { success => 1, %{ $self->_fetch_user_info($login) } };
}

sub login_info {
    my ( $self, $login ) = @_;
    my $response = ['login_info_res'];
    $response->[1] = $self->_fetch_login_info($login);
    $login->send($response);
}

sub _update_all_logins {
    my $self = shift;
    for my $log ( values %{ $self->login_list } ) {
        my $log_info = $self->_fetch_login_info($log); 

        $log->send(["login_update", { %{ $log_info } } ]); 
    }
}

sub _fetch_login_info {
    my ( $self, $login ) = @_;
    my $info = $self->_fetch_user_info($login);
    return {
        %{ $info },
        login_id => $login->id,
        success  => 1,
    };
}

sub _fetch_user_info {
    my ( $self, $login ) = @_;
    return { } unless $login->has_user;
    my $chips = $self->db->fetch_chips( $login->user->id );

    return {
        id => $login->user->id,
        facebook_id => $login->user->facebook_id,
        username => $login->user->username,
        bookmark => $login->user->bookmark,
        level    => $login->user->level,
        email    => $login->user->email,
        birthday => $login->user->birthday,
        handle   => $login->user->handle,
        chips    => $chips,
        last_visit => $login->user->last_visit,
    };
}

sub authorize {
    my ( $self, $login, $opts ) = @_;

    my $response     = [ 'authorize_res', { success => 0 } ];
    my $secret = $self->facebook_secret;
    my $signed = $opts->{authResponse}->{signedRequest};
    my ( $encoded_sig, $payload ) = split( /\./, $signed, 2 );
    unless ($encoded_sig && $payload) {
       $login->send($response);
       return;
    }
    my $data         = j( decode_base64($payload) );
    my $expected_sig = encode_base64( hmac_sha256( $payload, $secret ), "" );
    $expected_sig =~ tr/\/+/_-/;
    $expected_sig =~ s/=//;

    if ( $encoded_sig eq $expected_sig ) {

        # signature verified
        $response->[1] = { success => 1 };

        $opts->{facebook_id} = $data->{user_id};
        $opts->{username}    = $data->{user_id};
    }

    $login->send($response);

    # return unless authorized
    return unless $response->[1]->{success};

    my $user = $self->db->fetch_user( { facebook_id => $opts->{facebook_id} } );

    #print Dumper($user->username);
    # already registered, so login
    if ( $user && ref $user eq 'FB::User' && $user->id ) {
        $login->send( [ "authorize_res", { msg => 'already registerd' } ] );
        $login->user($user);
        $self->_login($login);
    }

    # register new user
    else {
        $login->send( [ "authorize_res", { msg => 'register' } ] );
        my $un = $opts->{facebook_id};
        $self->register( $login,
            { facebook_id => $opts->{facebook_id}, username => $un } );
    }
}

sub _login {
    my ( $self, $login ) = @_;

    #my ( $self, $login, $opts ) = @_;

    my $response = [ 'login_res', { login_id => $login->id } ];

    #my $user_opts = $self->fetch_user_opts($opts);

    unless ( $login->has_user ) {
        $response->[1]->{success} = 0;
        $response->[1]->{message} = 'Login failed.';
        $login->send($response);
        return;
    }

    if ( $login->user && $login->user->id == 1 ) {
        unless ( $login->remote_address eq '127.0.0.1' ) {
            $response->[1]->{success} = 0;
            $response->[1]->{message} = 'No remote admin access.';
            $login->send($response);
            return;
        }
    }

    #if ( $login->has_user ) {
    #    $response->[1]->{success} = 0;
    #    $response->[1]->{message} = 'You are already logged in.';
    #    $login->send($response);
    #    return;
    #}

    #$login->user(FB::User->new(%$user_opts));
    #$self->user_map->{ $login->user->id } = $login->id;

    # Requirements: 10.1, 10.2 - Check for reconnection within grace period
    if ($self->session_manager->is_disconnected($login->id)) {
        $self->session_manager->on_reconnect($login);
    }

    # logout any old connections
    my $old_login_id = $self->user_map->{ $login->user->id };
    my $old_login = $self->login_list->{$old_login_id} if $old_login_id;

    if ( $old_login && ref($old_login) ) {
        $old_login->send(
            [
                'forced_logout',
                { message => 'Another login has been detected.' }
            ]
        );

        #$self->_cleanup($old_login);
        $old_login->logout;
    }

    # %$login = ( %$login, %$user_opts );
    # $login->user( FB::User->new(%$user_opts) );
    $self->user_map->{ $login->user->id } = $login->id;

    #$login->user->db( $self->db );

    $response->[1] = {
        %{ $response->[1] },
        success => 1,
        %{ $self->_fetch_login_info($login) }
    };

    $login->send($response);

    #$self->_notify_logins();
    #$login->send(['notify_leaders', { leaders => $self->_fetch_leaders }]);

}

#sub _force_logout {
#  my ( $self, $login, $opts ) = @_;
#  $login->send( [ 'forced_logout', $opts ] );
#  $login->logout;
#}

sub login {
    my ( $self, $login, $opts ) = @_;
    
    # Extract plaintext password before fetching user
    my $plaintext_password = $opts->{password};
    
    # Fetch user by username only (not password - we verify separately)
    my $user = $self->db->fetch_user({ username => $opts->{username} });

    unless (ref $user eq 'FB::User') {
       $login->send(["login_res", { success => 0, reason => "No such user" }]);
       $self->logout($login);
       return;
    }

    # Verify password using bcrypt comparison
    unless ($self->_bcrypt_verify($plaintext_password, $user->password)) {
       $login->send(["login_res", { success => 0, reason => "Invalid password" }]);
       $self->logout($login);
       return;
    }

    $login->user($user);
    $self->_login($login);
}

sub login_book {
    my ( $self, $login, $opts ) = @_;
    my $user = $self->db->fetch_user($opts);

    unless (ref $user eq 'FB::User') {
       $login->send(["login_book_res", { success => 0, reason => "No such user" }]);
       $self->logout($login);
       return;
    }
    $login->user($user);
    $self->_login($login);

    #    $self->_login( $login, $opts, { bookmark => 1 } );
}

=pod
sub fetch_user_opts {
    my ( $self, $opts ) = @_;
    my ( $stmt, @bind ) = $self->sql->select( 'user', '*', $opts );
    my $sth = $self->db->prepare($stmt);
    $sth->execute(@bind);
    my $href = $sth->fetchrow_hashref;
    $href->{user_id} = $href->{id};
    return $href;
}
=cut

sub _notify_leaders {
    my $self    = shift;
    my $leaders = $self->db->fetch_leaders;

    my $login_count = keys %{ $self->login_list };

    my $response = [
        'notify_leaders',
        {
            logins  => $login_count,
            leaders => $leaders,
            success => 1,
        }
    ];

    for my $log ( values %{ $self->login_list } ) {
        $log->send($response);
    }
}

sub logout {
    my ( $self, $login ) = @_;
    my $response = [ 'logout_res', { success => 1 } ];
    $login->send($response);
    $self->_logout($login);

    #  $self->_cleanup($login) if $login->has_user_id;
    #  $login->logout unless $login->websocket->is_finished;
}

sub _logout {
    my ( $self, $login ) = @_;

    #$self->_cleanup($login);
    $login->logout unless $login->websocket->is_finished;
}

sub logout_all {
    my ( $self, $login ) = @_;
    my $response = ['logout_all_res'];
    for my $log ( values %{ $self->login_list } ) {
        $self->_logout($log);
    }
}

sub logout_user {
    my ( $self, $login, $opts ) = @_;
    my $response = [ 'logout_user_res', { success => 1 } ];
    my $log = $self->login_list->{ $opts->{login_id} };
    $self->_logout($log);
    $login->send($response);
}

sub _cleanup {
    my ( $self, $login ) = @_;

    # Requirements: 10.1, 10.2 - Handle disconnection with grace period
    # Try to save session for reconnection
    my $session_saved = $self->session_manager->on_disconnect($login);
    
    # If session was saved, don't do full cleanup yet
    if ($session_saved) {
        # Only remove from login_list, keep everything else for reconnection
        delete $self->login_list->{ $login->id };
        return;
    }

    # poker cleanup
    $self->_poker_cleanup($login);

    # remove from login_list
    delete $self->login_list->{ $login->id };

    # remove from login_watch
    delete $self->login_watch->{ $login->id };

    # remove from chat channels
    for my $channel ( values %{ $self->channels } ) {
        $channel->unjoin($login);
    }

    if ( $login->has_user ) {

        # remove from user_map
        if ( $self->user_map->{ $login->user->id } eq $login->id ) {
            delete $self->user_map->{ $login->user->id };
        }

        # update user database
        $self->db->update_user( $self->_fetch_user_info($login),
            $login->user->id );

        # cashout: update user_chips
    }

    $self->_notify_logins();

}

sub block {
    my ( $self, $login, $opts ) = @_;
    my $response    = ['block_res'];
    my $block_login = $self->login_list->{ $opts->{login_id} };
    unless ($block_login) {
        $response->[1]->{success} = 0;
        $login->send($response);
    }
    $self->login->block->{ $opts->{login_id} } = 1;
    $response->[1] = $self->_fetch_login_opts($block_login);
    $response->[1]->{success} = 1;
    $login->send($response);
}

sub unblock {
    my ( $self, $login, $opts ) = @_;
    my $response    = ['unblock_res'];
    my $block_login = $self->login_list->{ $opts->{login_id} };
    unless ($block_login) {
        $response->{success} = 0;
        $login->send($response);
    }
    delete $self->login->block->{ $opts->{login_id} };
    $response->[1] = $self->_fetch_login_opts($block_login);
    $response->[1]->{success} = 1;
    $login->send($response);
}

sub destroy_channel {
    my ( $self, $login, $opts ) = @_;
    delete $self->channels->{ $opts->{channel} };
    $login->send(
        [
            'destroy_channel_res', { success => 1, channel => $opts->{channel} }
        ]
    );
}

sub create_channel {
    my ( $self, $login, $opts ) = @_;
    $self->_create_channel($opts);
    $login->send(
        [ 'create_channel_res', { success => 1, channel => $opts->{channel} } ]
    );
}

sub _create_channel {
    my ( $self, $opts ) = @_;
    $self->channels->{ $opts->{channel} } = FB::Chat->new($opts);
}

sub join_channel {
    my ( $self, $login, $opts ) = @_;
    if ( !exists $self->channels->{ $opts->{channel} } ) {
        $login->send(
            [
                'join_channel_res',
                { success => 0, message => 'No such channel.' }
            ]
        );
        return;
    }
    $self->channels->{ $opts->{channel} }->join($login);
    $login->send(
        [ 'join_channel_res', { success => 1, channel => $opts->{channel} } ] );
    $login->send( $self->channels->{ $opts->{channel} }->refresh );
}

sub unjoin_channel {
    my ( $self, $login, $opts ) = @_;
    if ( !exists $self->channels->{ $opts->{channel} } ) {
        $login->send(
            [
                'unjoin_channel_res',
                { success => 0, message => 'No such channel.' }
            ]
        );
        return;
    }
    $self->channels->{ $opts->{channel} }->unjoin($login);
    $login->send(
        [ 'unjoin_channel_res', { success => 1, channel => $opts->{channel} } ]
    );
}

sub write_channel {
    my ( $self, $login, $opts ) = @_;

    if ( !exists $self->channels->{ $opts->{channel} } ) {
        $login->send(
            [
                'write_channel_res',
                { success => 0, message => 'No such channel.' }
            ]
        );
        return;
    }

    $self->channels->{ $opts->{channel} }->write( $login->id, $opts );
    $login->send(
        [ 'write_channel_res', { success => 1, channel => $opts->{channel} } ]
    );
}

sub ping {
    my ( $self, $login ) = @_;
    $login->send( [ 'ping_res', { epoch => time } ] );
}

sub credit_chips {
    my ( $self, $login, $opts ) = @_;
    my $response = [ 'credit_chips_res', { success => 0 } ];

    $login->send($response);
}

sub cycle300 {
    my $self = shift;
    $self->_notify_leaders();
}

sub BUILD {
    my $self = shift;

    #$self->db( $self->_build_db );
    $self->option( { %{ $self->option }, %{ $self->poker_option } } );
    $self->command( { %{ $self->command }, %{ $self->poker_command } } );
    $self->_create_channel( { channel => 'main' } );
    $self->cycle_event(
        FB::Compat::Timer::timer(300, 300, sub {
            $self->cycle300;
        })
    );

    # Create test tables with house players on startup
    $self->_create_test_tables();
}

sub _create_test_tables {
    my $self = shift;

    # Create a Texas Hold'em table
    my $table_opts = {
        table_id => $self->table_count + 1,
        chair_count => 6,
        game_class => 'holdem',
        limit => 'NL',
        small_blind => 1,
        big_blind => 2,
        auto_start => 1,
        db => $self->db,
        fb => $self,
    };

    my $table = $self->table_maker->ring_table($table_opts);
    if ($table) {
        $self->table_list->{ $table->table_id } = $table;
        $self->table_count($self->table_count + 1);

        # Add house players to the table
        $self->_add_house_players($table);

        $self->_notify_lobby(
            [ 'notify_create_ring', $self->_fetch_table_opts($table) ]
        );
    }

    # Create an Omaha table
    $table_opts = {
        table_id => $self->table_count + 1,
        chair_count => 6,
        game_class => 'omaha',
        limit => 'PL',
        small_blind => 1,
        big_blind => 2,
        auto_start => 1,
        db => $self->db,
        fb => $self,
    };

    $table = $self->table_maker->ring_table($table_opts);
    if ($table) {
        $self->table_list->{ $table->table_id } = $table;
        $self->table_count($self->table_count + 1);

        # Add house players to the table
        $self->_add_house_players($table);

        $self->_notify_lobby(
            [ 'notify_create_ring', $self->_fetch_table_opts($table) ]
        );
    }
}

sub _add_house_players {
    my ($self, $table) = @_;

    # Get house players from database
    my $house_player1 = $self->db->fetch_user({username => 'HousePlayer1'});
    my $house_player2 = $self->db->fetch_user({username => 'HousePlayer2'});

    if ($house_player1) {
        # Create proper mock WebSocket object for house player
        my $mock_ws = FB::Login::WebSocket::Mock->new(
            remote_address => '127.0.0.1'
        );

        # Create house login with mock WebSocket
        my $house_login1 = FB::Login::WebSocket->new({
            id => 'house1_' . $table->table_id,
            websocket => $mock_ws,
            db => $self->db,
        });
        $house_login1->user($house_player1);
        $self->login_list->{$house_login1->id} = $house_login1;

        # Join the table with chips
        $table->join($house_login1, {
            chair => 0,
            chips => 200,
        });
    }

    if ($house_player2) {
        # Create proper mock WebSocket object for house player
        my $mock_ws = FB::Login::WebSocket::Mock->new(
            remote_address => '127.0.0.1'
        );

        # Create house login with mock WebSocket
        my $house_login2 = FB::Login::WebSocket->new({
            id => 'house2_' . $table->table_id,
            websocket => $mock_ws,
            db => $self->db,
        });
        $house_login2->user($house_player2);
        $self->login_list->{$house_login2->id} = $house_login2;

        # Join the table with chips
        $table->join($house_login2, {
            chair => 1,
            chips => 200,
        });
    }
}

1;