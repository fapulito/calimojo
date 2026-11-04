# Copyright (C) 2026, California Vision
# Forecast page controller (Session 2). Serves the play-money forecast UI.
package Ships::Forecast;
use Mojo::Base 'Mojolicious::Controller';

sub show {
    my $self = shift;

    # upgrade websocket scheme to wss
    my $url = $self->url_for('websocket')->to_abs;
    $url->scheme('wss') if $self->req->headers->header('X-Forwarded-For');

    $self->stash(ws_url => $url->to_abs);
    $self->render(
        template => 'forecast',
        format   => 'html',
        handler  => 'ep',
    );
}

1;
