package Ships::Dashboard;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw(encode_json decode_json);

# Requirements: 4.2 - Admin authentication middleware
# Returns 1 if user has admin privileges, 0 otherwise
# Admin level is 4 or higher (based on FB.pm command structure)
sub require_admin {
    my $self = shift;
    
    # Get the FB instance from the app
    my $fb = $self->app->fb;
    
    # Check if we have a session with user info
    my $user_id = $self->session('user_id');
    my $login_id = $self->session('login_id');
    
    # If no session, check for API key authentication (for programmatic access)
    my $api_key = $self->req->headers->header('X-Admin-API-Key');
    if ($api_key && $api_key eq ($ENV{ADMIN_API_KEY} || '')) {
        return 1 if $ENV{ADMIN_API_KEY};  # Only allow if key is configured
    }
    
    # Check if user is logged in via WebSocket session
    if ($login_id && exists $fb->login_list->{$login_id}) {
        my $login = $fb->login_list->{$login_id};
        if ($login && $login->has_user) {
            my $user_level = $login->user->level || 0;
            # Admin level is 4 or higher (based on FB.pm command structure)
            return 1 if $user_level >= 4;
        }
    }
    
    # Check if user_id is in user_map and has admin level
    if ($user_id && exists $fb->user_map->{$user_id}) {
        my $login_id_from_map = $fb->user_map->{$user_id};
        if ($login_id_from_map && exists $fb->login_list->{$login_id_from_map}) {
            my $login = $fb->login_list->{$login_id_from_map};
            if ($login && $login->has_user) {
                my $user_level = $login->user->level || 0;
                return 1 if $user_level >= 4;
            }
        }
    }
    
    # For development/testing: allow localhost access if ADMIN_LOCALHOST is set
    if ($ENV{ADMIN_LOCALHOST} && $self->tx->remote_address eq '127.0.0.1') {
        return 1;
    }
    
    # Not authenticated - return 401
    $self->res->code(401);
    $self->render(
        json => {
            error => 'unauthorized',
            message => 'Admin authentication required',
        },
        status => 401,
    );
    
    return 0;
}

# Requirements: 4.1, 4.3 - Main dashboard view with gaming metrics
sub index {
    my $self = shift;
    
    # Check admin authentication
    return unless $self->require_admin;
    
    # Render admin dashboard template
    $self->render(
        template => 'admin/dashboard',
        format   => 'html',
        handler  => 'ep',
    );
}

# Requirements: 4.1, 4.3, 4.6 - JSON metrics endpoint
sub metrics {
    my $self = shift;
    
    # Check admin authentication
    return unless $self->require_admin;
    
    # Get the FB instance from the app
    my $fb = $self->app->fb;
    
    # Collect system metrics
    my $system_metrics = $self->_collect_system_metrics($fb);
    
    # Collect gaming metrics
    my $gaming_metrics = $self->_collect_gaming_metrics($fb);
    
    # Collect per-table information
    my $tables = $self->_collect_table_info($fb);
    
    my $metrics = {
        system    => $system_metrics,
        gaming    => $gaming_metrics,
        tables    => $tables,
        timestamp => time,
    };
    
    $self->render(json => $metrics);
}

# Helper: Collect system metrics (uptime, memory, CPU)
sub _collect_system_metrics {
    my ($self, $fb) = @_;
    
    # Calculate uptime
    my $start_time = $fb->start_time || time;
    my $uptime_seconds = time - $start_time;
    
    # Format uptime as human-readable string
    my $days = int($uptime_seconds / 86400);
    my $hours = int(($uptime_seconds % 86400) / 3600);
    my $minutes = int(($uptime_seconds % 3600) / 60);
    my $uptime_formatted = "${days}d ${hours}h ${minutes}m";
    
    # Get memory usage (platform-specific)
    my ($memory_usage_mb, $memory_percent) = $self->_get_memory_usage();
    
    # Get CPU usage (simplified - actual CPU monitoring would need more sophisticated approach)
    my $cpu_percent = $self->_get_cpu_usage();
    
    return {
        uptime           => $uptime_seconds,
        uptime_formatted => $uptime_formatted,
        memory_usage_mb  => $memory_usage_mb,
        memory_percent   => $memory_percent,
        cpu_percent      => $cpu_percent,
        perl_version     => $],
        mojo_version     => $Mojolicious::VERSION || 'unknown',
    };
}

# Helper: Get memory usage
sub _get_memory_usage {
    my $self = shift;
    
    my $memory_mb = 0;
    my $memory_percent = 0;
    
    # Try to get memory info from /proc on Linux
    if (-f '/proc/self/status') {
        if (open my $fh, '<', '/proc/self/status') {
            while (<$fh>) {
                if (/^VmRSS:\s+(\d+)\s+kB/) {
                    $memory_mb = int($1 / 1024);
                    last;
                }
            }
            close $fh;
        }
        
        # Get total memory for percentage calculation
        if (open my $fh, '<', '/proc/meminfo') {
            my $total_kb = 0;
            while (<$fh>) {
                if (/^MemTotal:\s+(\d+)\s+kB/) {
                    $total_kb = $1;
                    last;
                }
            }
            close $fh;
            $memory_percent = $total_kb > 0 ? sprintf("%.1f", ($memory_mb * 1024 / $total_kb) * 100) : 0;
        }
    }
    # Windows fallback - use rough estimate
    elsif ($^O eq 'MSWin32') {
        # On Windows, we can't easily get memory without external modules
        # Return 0 as placeholder
        $memory_mb = 0;
        $memory_percent = 0;
    }
    
    return ($memory_mb, $memory_percent);
}

# Helper: Get CPU usage (simplified)
sub _get_cpu_usage {
    my $self = shift;
    
    # CPU usage monitoring requires sampling over time
    # For now, return 0 as a placeholder
    # A proper implementation would track CPU time between calls
    return 0;
}

# Helper: Collect gaming metrics (users, tables, chips, connections)
sub _collect_gaming_metrics {
    my ($self, $fb) = @_;
    
    # Count active users (logged in users with user objects)
    my $active_users = 0;
    my $websocket_connections = scalar keys %{$fb->login_list || {}};
    
    for my $login (values %{$fb->login_list || {}}) {
        $active_users++ if $login && $login->has_user;
    }
    
    # Count active tables and games in progress
    my $active_tables = scalar keys %{$fb->table_list || {}};
    my $games_in_progress = 0;
    my $total_chips_in_play = 0;
    
    for my $table (values %{$fb->table_list || {}}) {
        next unless $table;
        
        # Count games in progress (tables with active betting)
        if ($table->can('game') && $table->game) {
            $games_in_progress++;
        }
        
        # Sum chips in play across all tables
        if ($table->can('pot')) {
            $total_chips_in_play += $table->pot || 0;
        }
        
        # Also count chips at chairs
        if ($table->can('chairs')) {
            for my $chair (@{$table->chairs || []}) {
                next unless $chair && $chair->can('chips');
                $total_chips_in_play += $chair->chips || 0;
            }
        }
    }
    
    return {
        active_users          => $active_users,
        active_tables         => $active_tables,
        total_chips_in_play   => $total_chips_in_play,
        websocket_connections => $websocket_connections,
        games_in_progress     => $games_in_progress,
    };
}

# Helper: Collect per-table information
sub _collect_table_info {
    my ($self, $fb) = @_;
    
    my @tables;
    
    for my $table (values %{$fb->table_list || {}}) {
        next unless $table;
        
        # Get table ID
        my $table_id = $table->can('table_id') ? $table->table_id : 0;
        
        # Get game type
        my $game_type = $table->can('game_class') ? $table->game_class : 'unknown';
        
        # Count players at table
        my $player_count = 0;
        if ($table->can('chairs')) {
            for my $chair (@{$table->chairs || []}) {
                $player_count++ if $chair && $chair->can('has_user') && $chair->has_user;
            }
        }
        
        # Get pot size
        my $pot_size = $table->can('pot') ? ($table->pot || 0) : 0;
        
        # Determine status
        my $status = 'waiting';
        if ($table->can('game') && $table->game) {
            $status = 'active';
        }
        
        push @tables, {
            table_id     => $table_id,
            game_type    => $game_type,
            player_count => $player_count,
            pot_size     => $pot_size,
            status       => $status,
        };
    }
    
    return \@tables;
}

# Requirements: 8.1, 8.2, 8.3 - Error logs view
sub logs {
    my $self = shift;
    
    # Check admin authentication
    return unless $self->require_admin;
    
    # Check if JSON format requested
    if ($self->accepts('json')) {
        return $self->logs_json;
    }
    
    # Get severity filter from query params
    my $severity = $self->param('severity');
    
    # Get log entries
    my $log_data = $self->_get_log_entries($severity);
    
    # Render logs template
    $self->render(
        template => 'admin/logs',
        format   => 'html',
        handler  => 'ep',
        entries  => $log_data->{entries},
        total    => $log_data->{total},
        severity_filter => $severity,
    );
}

# Requirements: 8.1, 8.2, 8.3 - Logs as JSON endpoint
sub logs_json {
    my $self = shift;
    
    # Check admin authentication
    return unless $self->require_admin;
    
    # Get severity filter from query params
    my $severity = $self->param('severity');
    
    # Get log entries
    my $log_data = $self->_get_log_entries($severity);
    
    $self->render(json => $log_data);
}

# Helper: Get log entries from storage
# Requirements: 8.1 - Display most recent 100 error log entries
# Requirements: 8.2 - Show timestamp, severity, message, source
# Requirements: 8.3 - Support severity filtering
sub _get_log_entries {
    my ($self, $severity_filter) = @_;
    
    my @entries;
    my $limit = 100;  # Requirements: 8.1 - most recent 100 entries
    
    # Try to read from log file if it exists
    my $log_file = $ENV{ERROR_LOG_FILE} || './logs/error.log';
    
    if (-f $log_file && open my $fh, '<', $log_file) {
        my @lines;
        while (<$fh>) {
            push @lines, $_;
        }
        close $fh;
        
        # Parse log lines (most recent first)
        my $id = 0;
        for my $line (reverse @lines) {
            last if @entries >= $limit;
            
            # Parse log line format: [TIMESTAMP] [SEVERITY] MESSAGE (SOURCE)
            # Example: [2025-12-17T10:30:00Z] [error] Database connection failed (FB::Db::connect line 45)
            if ($line =~ /^\[([^\]]+)\]\s*\[(\w+)\]\s*(.+?)(?:\s*\(([^)]+)\))?$/) {
                my ($timestamp, $severity, $message, $source) = ($1, $2, $3, $4 || 'unknown');
                
                # Apply severity filter if specified
                if ($severity_filter) {
                    next unless lc($severity) eq lc($severity_filter);
                }
                
                $id++;
                push @entries, {
                    id        => $id,
                    timestamp => $timestamp,
                    severity  => lc($severity),
                    message   => $message,
                    source    => $source,
                };
            }
        }
    }
    else {
        # No log file - try to get from in-memory log storage
        # This is a fallback for when file-based logging isn't configured
        @entries = $self->_get_memory_log_entries($severity_filter, $limit);
    }
    
    return {
        entries => \@entries,
        total   => scalar @entries,
    };
}

# Helper: Get log entries from in-memory storage (fallback)
sub _get_memory_log_entries {
    my ($self, $severity_filter, $limit) = @_;
    
    # Check if FB::Observability has captured any errors
    my @entries;
    
    # Try to get from observability module if available
    eval {
        require FB::Observability;
        my $obs = FB::Observability->instance;
        if ($obs && $obs->can('get_recent_errors')) {
            my $errors = $obs->get_recent_errors($limit);
            for my $error (@{$errors || []}) {
                # Apply severity filter
                if ($severity_filter) {
                    next unless lc($error->{severity} || 'error') eq lc($severity_filter);
                }
                
                push @entries, {
                    id        => $error->{id} || 0,
                    timestamp => $error->{timestamp} || '',
                    severity  => $error->{severity} || 'error',
                    message   => $error->{message} || '',
                    source    => $error->{source} || 'unknown',
                    user_id   => $error->{user_id},
                    login_id  => $error->{login_id},
                    request_url => $error->{request_url},
                    request_method => $error->{request_method},
                };
            }
        }
    };
    
    # If no entries found, return empty array with sample structure
    if (!@entries) {
        # Return empty but valid structure
        return ();
    }
    
    return @entries;
}

# Requirements: 6.4 - Health check endpoint
# Note: Health check does NOT require admin authentication
# It's used by load balancers and monitoring systems
sub health {
    my $self = shift;
    
    my $status = 'ok';
    my $db_status = 'ok';
    my $db_message = '';
    
    # Check database connectivity
    eval {
        my $fb = $self->app->fb;
        if ($fb && $fb->db && $fb->db->dbh) {
            # Try a simple query to verify connection
            my $result = $fb->db->dbh->ping;
            unless ($result) {
                $db_status = 'error';
                $db_message = 'Database ping failed';
                $status = 'degraded';
            }
        }
        else {
            $db_status = 'error';
            $db_message = 'Database not initialized';
            $status = 'degraded';
        }
    };
    
    if ($@) {
        $db_status = 'error';
        $db_message = "Database check failed: $@";
        $status = 'degraded';
    }
    
    my $response = {
        status    => $status,
        timestamp => time,
        checks    => {
            database => {
                status  => $db_status,
                message => $db_message,
            },
        },
    };
    
    # Return 200 for ok/degraded, 503 for critical failures
    my $http_status = ($status eq 'ok' || $status eq 'degraded') ? 200 : 503;
    
    $self->render(
        json   => $response,
        status => $http_status,
    );
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
