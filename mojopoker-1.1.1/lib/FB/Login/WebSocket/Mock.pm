package FB::Login::WebSocket::Mock;
use strict;
use warnings;

# Mock WebSocket class for house players
# Provides the same interface as real WebSocket but doesn't actually send anything

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;

    # Set default values
    $self->{remote_address} = $args{remote_address} || '127.0.0.1';
    $self->{connection_id} = $args{connection_id} || 'mock-' . time;

    return $self;
}

sub remote_address {
    my ($self) = @_;
    return $self->{remote_address};
}

sub connection {
    my ($self) = @_;
    return $self->{connection_id};
}

sub send {
    my ($self, $message) = @_;
    # Mock send - just return silently for house players
    # In real usage, this would send WebSocket messages
    # For house players, we just ignore the messages
    return 1;
}

sub finish {
    my ($self) = @_;
    # Mock finish - just return silently for house players
    # In real usage, this would close the WebSocket connection
    # For house players, we just ignore this
    return 1;
}

sub is_websocket {
    my ($self) = @_;
    return 1; # Yes, this is a WebSocket (mock)
}

sub is_finished {
    my ($self) = @_;
    return 0; # Never finished for house players
}

1;