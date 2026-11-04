# Copyright (C) 2026, California Vision
# Forecast page controller (Sessions 2-3). Serves the play-money forecast
# UI and the public resolution record page.
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

# Public resolution record page (Session 3). The record body loads over
# the app websocket (fc_record with resolution_id, falling back to
# question_id); the page only carries the id and the socket url.
sub record {
    my $self = shift;
    my $id = $self->param('id') // '';
    return $self->redirect_to('/forecast') unless $id =~ /^[\w-]+$/;

    my $url = $self->url_for('websocket')->to_abs;
    $url->scheme('wss') if $self->req->headers->header('X-Forwarded-For');

    $self->stash(ws_url => $url->to_abs, record_id => $id);
    $self->render(
        template => 'forecast_record',
        format   => 'html',
        handler  => 'ep',
    );
}

1;
