package Ships::Websocket;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON 'j';

sub service {
  my $self = shift;

  #$self->inactivity_timeout(0);
  #$self->tx->with_compression;

  my $login;
  eval {
    $login = $self->app->fb->_guest_login( { websocket => $self->tx } );
  };
  
  if ($@) {
    # Log the detail server-side; the unauthenticated client only gets
    # a fixed message (never the raw exception).
    $self->app->log->error("WebSocket error during guest login: $@");
    $self->send({json => {error => 'login_failed', message => 'Unable to create login'}});
    $self->finish;
    return;
  }
  
  unless ($login) {
    $self->app->log->error("WebSocket: Failed to create guest login");
    $self->send({json => {error => 'login_failed', message => 'Unable to create login'}});
    $self->finish;
    return;
  }
  
  $self->on(
    message => sub {
      my ( $self, $msg ) = @_;
      my $aref = eval { j($msg) }; 
      if ($@) {
        $login->req_error;
        $login->send( [ 'malformed_json', { message => $@ } ] );
      }
      else {
        $self->app->fb->request( $login, $aref );
      }
    }
  );

  # Disconnected
  $self->on(
    finish => sub {
      my $self = shift;
      #cleanup now
      $self->app->fb->_cleanup($login);
      $self->app->log->debug("Logout " . $login->id);
    }
  );
}

1;
