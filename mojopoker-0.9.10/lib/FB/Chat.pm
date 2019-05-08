package FB::Chat;
use Moo;

has 'id' => (
  is      => 'rw',
);

has 'channel' => (
  is      => 'rw',
);

has 'table_id' => (
  is  => 'rw',
);

has 'tour_id' => (
  is  => 'rw',
);

has 'logins' => (
  is      => 'rw',
  isa     => sub { die "Not a hash!" unless ref( $_[0] ) eq 'HASH' },
  builder => '_build_logins',
);

sub _build_logins {
  return {};
}

has 'buffer_size' => (
  is  => 'rw',
  default => sub { return 5 }
);

has 'buffer' => (
  is  => 'rw',
  isa     => sub { die "Not an array!" unless ref( $_[0] ) eq 'ARRAY' },
  builder   => '_build_buffer',
);

sub _build_buffer {
  return [];
}

sub write {
  my ($self, $login_id, $opts) = @_;
  push(@{ $self->buffer }, { 
    login_id => $login_id, 
    message => $opts->{message},
  });
  shift(@{ $self->buffer }) if scalar @{ $self->buffer } > $self->buffer_size;
  for my $log (values %{ $self->logins }) {
    unless (exists $log->block->{$login_id}) {
      $log->send([ 'notify_message', { 
        channel  => $self->channel, 
        table_id => $self->table_id, 
        tour_id  => $self->tour_id, 
        message  => $opts->{message}, 
        from     => $login_id 
      } ]);
    }
  }
}

sub join {
  my ($self, $login) = @_;
  $self->logins->{$login->id} = $login;
}

sub unjoin {
  my ($self, $login) = @_;
  delete $self->logins->{$login->id};
}

sub refresh {
  my $self = shift;
  return [ 'message_snap', [ map { 
    {
      channel  => $self->channel, 
      table_id => $self->table_id,
      tour_id  => $self->tour_id,
      message  => $_->{message},
      from     => $_->{login_id},
    }
  } @{ $self->buffer } ] ]; 
}

1;

