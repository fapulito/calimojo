package Ships;
use Mojo::Base 'Mojolicious';
use lib 'perl5';
use FB;
use FB::Observability;
use FB::Security;

has 'address_block' => sub {
  return {};
};

has 'address_info' => sub {
  return {};
};

has facebook_app_id => sub {
   return $ENV{FACEBOOK_APP_ID} || 'development_app_id';
};

has facebook_secret => sub {
   return $ENV{FACEBOOK_APP_SECRET} || 'development_secret';
};

has fb => sub {
  my $self = shift;
  return FB->new(
    address_block => $self->app->address_block,
    facebook_secret => $self->facebook_secret,
  );
};

# Requirements: 1.2 - FB::Observability instance for error tracking
has observability => sub {
  return FB::Observability->new;
};

# Requirements: 5.1, 5.2 - FB::Security instance for server hardening
has security => sub {
  return FB::Security->new;
};

# This method will run once at server start
sub startup {
  my $self = shift;

  $ENV{LIBEV_FLAGS} = 4;

  # Requirements: 1.2 - Initialize Sentry on application start
  $self->observability->init;

  # cookie setup
  #$self->sessions->cookie_name('ships');
  #$self->sessions->default_expiration(315360000); #10 years
  #$self->sessions->secure(1);  # only send cookies over SSL
  #$self->secret('g)ue(ss# %m4e &i@f y25o*u c*69an');
  #$self->plugin('PODRenderer');

  # Requirements: 5.1, 5.2 - Add security middleware to apply headers and rate limiting
  $self->hook(before_dispatch => sub {
    my $c = shift;
    
    # Requirements: 5.2 - Rate limiting check
    my $ip = $c->tx->remote_address || '127.0.0.1';
    unless ($self->security->check_rate_limit($ip)) {
      $c->render(
        json => { error => 'rate_limit_exceeded', message => 'Too many requests' },
        status => 429,
      );
      return;
    }
    
    # Requirements: 5.1 - Apply security headers to all responses
    my $headers = $self->security->get_security_headers;
    for my $header (keys %$headers) {
      $c->res->headers->header($header => $headers->{$header});
    }
  });

  # Router
  my $r = $self->routes;
  # swap next line for the one after for custom DOS protection
  #my $b = $r->under('/')->to( controller => 'auth', action => 'block' );
  my $b = $r->under( sub { return 1 } ); # don't block anyone
  $b->websocket('/websocket')->to( controller => 'websocket', action => 'service' );
  $b->get('/')->to( controller => 'main', action => 'default' );
  #$r->route('/book/:bookmark')->to( controller => 'main', action => 'book' );
  $r->get('/privacy')->to( controller => 'main', action => 'privacy' );
  $r->get('/terms')->to( controller => 'main', action => 'terms' );
  $r->get('/leaderboard')->to( controller => 'main', action => 'leader' );
  $r->get('/deletion')->to( controller => 'main', action => 'deletion' );
  $r->post('/delete')->to(controller => 'main', action => 'delete');

  # Requirements: 4.1, 4.2, 6.4 - Dashboard routes
  # Health check endpoint (no auth required - used by load balancers)
  $r->get('/health')->to(controller => 'dashboard', action => 'health');
  
  # Admin dashboard routes (auth middleware applied in controller)
  $r->get('/admin/dashboard')->to(controller => 'dashboard', action => 'index');
  $r->get('/admin/metrics')->to(controller => 'dashboard', action => 'metrics');
  $r->get('/admin/logs')->to(controller => 'dashboard', action => 'logs');
  $r->get('/admin/logs.json')->to(controller => 'dashboard', action => 'logs_json');

  $r->any('*')->to(cb => sub { shift->redirect_to('/') });
}

1;