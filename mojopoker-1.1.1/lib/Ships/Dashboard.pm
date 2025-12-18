package Ships::Dashboard;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw(encode_json);

# Requirements: 4.1, 4.3 - Main dashboard view with gaming metrics
sub index {
    my $self = shift;
    
    # Placeholder: Render admin dashboard template
    # Will display system metrics, gaming metrics, table list
    $self->render(
        template => 'admin/dashboard',
        format   => 'html',
        handler  => 'ep',
    );
}

# Requirements: 4.1, 4.3, 4.6 - JSON metrics endpoint
sub metrics {
    my $self = shift;
    
    # Placeholder: Return JSON with system and gaming metrics
    my $metrics = {
        system => {
            uptime           => 0,
            uptime_formatted => '0d 0h 0m',
            memory_usage_mb  => 0,
            memory_percent   => 0,
            cpu_percent      => 0,
        },
        gaming => {
            active_users          => 0,
            active_tables         => 0,
            total_chips_in_play   => 0,
            websocket_connections => 0,
            games_in_progress     => 0,
        },
        tables    => [],
        timestamp => time,
    };
    
    $self->render(json => $metrics);
}

# Requirements: 8.1, 8.2, 8.3 - Error logs view
sub logs {
    my $self = shift;
    
    # Check if JSON format requested
    if ($self->accepts('json')) {
        return $self->logs_json;
    }
    
    # Placeholder: Render logs template
    $self->render(
        template => 'admin/logs',
        format   => 'html',
        handler  => 'ep',
    );
}

# Requirements: 8.1, 8.2, 8.3 - Logs as JSON endpoint
sub logs_json {
    my $self = shift;
    
    # Placeholder: Return recent error log entries
    my $logs = {
        entries => [],
        total   => 0,
    };
    
    $self->render(json => $logs);
}

# Requirements: 6.4 - Health check endpoint
sub health {
    my $self = shift;
    
    # Placeholder: Return health status
    my $status = {
        status    => 'ok',
        timestamp => time,
    };
    
    $self->render(json => $status);
}

# Requirements: 4.2 - Admin authentication middleware
sub require_admin {
    my $self = shift;
    
    # Placeholder: Check if user has admin privileges
    # Return 401 for unauthenticated requests
    # For now, return 1 to allow access (will be implemented later)
    return 1;
}

1;

__END__

=head1 NAME

Ships::Dashboard - Admin dashboard controller for MojoPoker

=head1 SYNOPSIS

    # In Ships.pm routes:
    $r->get('/admin/dashboard')->to(controller => 'dashboard', action => 'index');
    $r->get('/admin/metrics')->to(controller => 'dashboard', action => 'metrics');
    $r->get('/admin/logs')->to(controller => 'dashboard', action => 'logs');
    $r->get('/health')->to(controller => 'dashboard', action => 'health');

=head1 DESCRIPTION

Admin dashboard for viewing real-time gaming metrics, system health,
and error logs.

=head1 ROUTES

=over 4

=item GET /admin/dashboard

Main dashboard view with system and gaming metrics.

=item GET /admin/metrics

JSON endpoint returning current metrics.

=item GET /admin/logs

Error logs view with filtering support.

=item GET /health

Health check endpoint for monitoring.

=back

=cut
