package Ships;
use Mojo::Base 'Mojolicious';
use lib 'perl5';
use FB;

has 'address_block' => sub {
  return {};
};

has 'address_info' => sub {
  return {};
};

has facebook_app_id => sub {
   return $ENV{FACEBOOK_APP_ID} or die "FACEBOOK_APP_ID environment variable is required";
};

has facebook_secret => sub {
   return $ENV{FACEBOOK_APP_SECRET} or die "FACEBOOK_APP_SECRET environment variable is required";
};

has fb => sub {
  my $self = shift;
  return FB->new(
    address_block => $self->app->address_block,
    facebook_secret => $self->facebook_secret,
  );
};

# This method will run once at server start
sub startup {
  my $self = shift;

  $ENV{LIBEV_FLAGS} = 4;

  # cookie setup
  #$self->sessions->cookie_name('ships');
  #$self->sessions->default_expiration(315360000); #10 years
  #$self->sessions->secure(1);  # only send cookies over SSL
  #$self->secret('g)ue(ss# %m4e &i@f y25o*u c*69an');
  #$self->plugin('PODRenderer');

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
  $r->any('*')->to(cb => sub { shift->redirect_to('/') });
}

1;