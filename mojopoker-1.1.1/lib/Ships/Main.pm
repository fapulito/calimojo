package Ships::Main;
use Mojo::Base 'Mojolicious::Controller';
use MIME::Base64;
use Mojo::JSON qw(j);
use Digest::SHA qw(hmac_sha256);


sub default {
    my $self = shift;

    # upgrade websocket scheme to wss
    my $url = $self->url_for('websocket')->to_abs;
    $url->scheme('wss') if $self->req->headers->header('X-Forwarded-For');
    my $opts = 'ws: "' . $url->to_abs . '"';

    $self->stash( 
       opts => $opts,
       facebook_app_id => $self->app->facebook_app_id, 
    );

    $self->render(
        template => 'main',
        format   => 'html',
        handler  => 'ep',
    );
}

sub terms {
    my $self = shift;
    $self->render(
        template => 'terms',
        format   => 'html',
        handler  => 'ep',
    );
}

sub privacy {
    my $self = shift;
    $self->render(
        template => 'privacy',
        format   => 'html',
        handler  => 'ep',
    );
}

sub leader {
    my $self = shift;
    $self->render(
        template => 'leader',
        format   => 'html',
        handler  => 'ep',
    );
}

sub delete {
    my $self = shift;
    my $signed_request = $self->param('signed_request');
    my $return = {url => undef, confirmation_code => undef};
    my $status_url = "https://mojopoker.xyz/deletion?id=";
    my $secret = $self->app->facebook_secret;
    my ($encoded_sig, $payload) = split(/\./, $signed_request, 2);
    unless ($encoded_sig && $payload) {
       $self->render(json => $return);
       return;
    }
    my $data = j(decode_base64($payload));
    my $expected_sig = encode_base64(hmac_sha256($payload, $secret), "");
    $expected_sig =~ tr/\/+/_-/;
    $expected_sig =~ s/=//;

    if ($encoded_sig eq $expected_sig && exists $data->{user_id}) {
      #verified; okay to do something with $data
       my $sth = $self->app->fb->db->dbh->prepare("SELECT id, bookmark FROM users WHERE facebook_id = ?");
       $sth->execute($data->{user_id});
       my ($id, $bookmark) = $sth->fetchrow_array;

       unless ($id && $bookmark) {
          $self->render(json => $return);
          return;
       }

       my $del_sth = $self->app->fb->db->dbh->prepare("UPDATE users SET facebook_id = NULL, facebook_deleted = CURRENT_TIMESTAMP WHERE id = ?");
       $del_sth->execute($id);
       $status_url .= $bookmark;
       $return->{url} = $status_url;
       $return->{confirmation_code} = $bookmark;

    }
    $self->render(json => $return);
}

sub deletion {
    my $self = shift;
    my $id = $self->param('id');
   
    return unless $id;

    my $sth = $self->app->fb->db->dbh->prepare("SELECT facebook_deleted FROM users WHERE bookmark = ?");
    $sth->execute($id);
    my $deleted = $sth->fetchrow_array;

    return unless $deleted;

    $self->stash(
       deleted => $deleted,
    );

    $self->render(
        template => 'deletion',
        format   => 'html',
        handler  => 'ep',
    );
}

sub book {
    my $self = shift;
    my $bookmark = param('bookmark');
    my $url = $self->url_for('websocket')->to_abs;
    $url->scheme('wss') if $self->req->headers->header('X-Forwarded-For');
    my $opts = 'ws: "' . $url->to_abs . '", bookmark: "' . $bookmark . '"';

    $self->stash(
       opts => $opts,
       facebook_app_id => $self->app->facebook_app_id,
    );

    $self->render(
        template => 'main',
        format   => 'html',
        handler  => 'ep',
    );
}

1;

