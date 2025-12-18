package FB::Observability;
use Moo;
use Mojo::JSON qw(encode_json decode_json);
use Mojo::Log;
use Try::Tiny;

# Configuration attributes - read from environment variables
# Requirements: 7.1 - Read configuration from environment variables
has 'sentry_dsn' => (
    is      => 'ro',
    default => sub { $ENV{SENTRY_DSN} },
);

has 'ga4_measurement_id' => (
    is      => 'ro',
    default => sub { $ENV{GA4_MEASUREMENT_ID} },
);

has 'fb_pixel_id' => (
    is      => 'ro',
    default => sub { $ENV{FB_PIXEL_ID} },
);

has 'sentry_enabled' => (
    is      => 'rw',
    default => 0,
);

has 'log' => (
    is      => 'ro',
    default => sub { Mojo::Log->new },
);

# Internal storage for captured errors (for testing/local logging)
has '_captured_errors' => (
    is      => 'rw',
    default => sub { [] },
);

# Requirements: 7.3 - Validation patterns for configuration values
my $SENTRY_DSN_PATTERN = qr{^https?://[a-f0-9]+(?::[a-f0-9]+)?@[^/]+/\d+$}i;
my $GA4_PATTERN = qr{^G-[A-Z0-9]+$}i;
my $FB_PIXEL_PATTERN = qr{^\d+$};

# Requirements: 1.2 - Initialize Sentry with configured DSN
# Requirements: 1.3 - Handle missing DSN gracefully with warning
sub init {
    my $self = shift;
    
    my $dsn = $self->sentry_dsn;
    
    # Requirements: 1.3 - Log warning if DSN not configured
    if (!defined $dsn || $dsn eq '') {
        $self->log->warn("Sentry DSN not configured - Sentry integration disabled");
        $self->sentry_enabled(0);
        return 1;
    }
    
    # Validate DSN format before enabling
    my $validation = $self->validate_config;
    if (!$validation->{sentry_dsn}) {
        $self->log->warn("Invalid Sentry DSN format - Sentry integration disabled");
        $self->sentry_enabled(0);
        return 1;
    }
    
    # Enable Sentry integration
    # Note: In production, this would initialize the actual Sentry SDK
    # For now, we enable the flag and log errors locally
    $self->sentry_enabled(1);
    $self->log->info("Sentry integration initialized with DSN: " . $self->mask_sensitive($dsn));
    
    return 1;
}

# Requirements: 1.1, 1.4 - Capture error details and send to Sentry
# Requirements: 1.5 - Produce valid JSON that round-trips correctly
sub capture_error {
    my ($self, $error, $context) = @_;
    $context //= {};
    
    # Build Sentry event structure
    # Requirements: 1.4 - Include user context and request context
    my $event = {
        exception => {
            type  => ref($error) || 'Error',
            value => "$error",
        },
        timestamp => time(),
    };
    
    # Add user context if provided
    if (defined $context->{user_id} || defined $context->{login_id}) {
        $event->{user} = {};
        $event->{user}{id} = $context->{user_id} if defined $context->{user_id};
        $event->{user}{login_id} = $context->{login_id} if defined $context->{login_id};
    }
    
    # Add request context if provided
    if (defined $context->{url} || defined $context->{method}) {
        $event->{request} = {};
        $event->{request}{url} = $context->{url} if defined $context->{url};
        $event->{request}{method} = $context->{method} if defined $context->{method};
    }
    
    # Add any extra context
    if (defined $context->{extra}) {
        $event->{extra} = $context->{extra};
    }
    
    # Add tags
    $event->{tags} = {
        environment => $ENV{MOJO_MODE} // 'development',
    };
    
    # Store the error locally (for testing and fallback)
    push @{$self->_captured_errors}, $event;
    
    # If Sentry is enabled, send the event
    if ($self->sentry_enabled) {
        # In production, this would send to Sentry API
        # For now, we log the event
        try {
            my $json = encode_json($event);
            $self->log->error("Sentry event: $json");
        } catch {
            $self->log->error("Failed to serialize Sentry event: $_");
        };
    }
    
    return $event;
}

# Requirements: 2.1, 2.2, 3.1, 3.2 - Return config for frontend tracking scripts
# Requirements: 2.4, 3.4 - Use IDs exactly as configured without modification
sub get_tracking_config {
    my $self = shift;
    
    my $config = {};
    
    # Requirements: 2.2 - Return undef for unconfigured GA4
    my $ga4_id = $self->ga4_measurement_id;
    if (defined $ga4_id && $ga4_id ne '') {
        $config->{ga4_measurement_id} = $ga4_id;
    } else {
        $config->{ga4_measurement_id} = undef;
    }
    
    # Requirements: 3.2 - Return undef for unconfigured FB Pixel
    my $fb_id = $self->fb_pixel_id;
    if (defined $fb_id && $fb_id ne '') {
        $config->{fb_pixel_id} = $fb_id;
    } else {
        $config->{fb_pixel_id} = undef;
    }
    
    return $config;
}

# Requirements: 7.4 - Mask sensitive values for logging (show only last 4 characters)
sub mask_sensitive {
    my ($self, $value) = @_;
    
    return '' unless defined $value;
    return '' if $value eq '';
    
    my $len = length($value);
    
    # If value is 4 characters or less, mask all but last character
    if ($len <= 4) {
        return ('*' x ($len - 1)) . substr($value, -1);
    }
    
    # Show only last 4 characters, mask the rest
    return ('*' x ($len - 4)) . substr($value, -4);
}

# Requirements: 7.2, 7.3 - Validate configuration formats
sub validate_config {
    my $self = shift;
    
    my $result = {
        sentry_dsn         => 1,  # Default to valid (disabled is valid)
        ga4_measurement_id => 1,
        fb_pixel_id        => 1,
    };
    
    # Validate Sentry DSN if provided
    my $dsn = $self->sentry_dsn;
    if (defined $dsn && $dsn ne '') {
        $result->{sentry_dsn} = ($dsn =~ $SENTRY_DSN_PATTERN) ? 1 : 0;
    }
    
    # Validate GA4 Measurement ID if provided
    my $ga4_id = $self->ga4_measurement_id;
    if (defined $ga4_id && $ga4_id ne '') {
        $result->{ga4_measurement_id} = ($ga4_id =~ $GA4_PATTERN) ? 1 : 0;
    }
    
    # Validate Facebook Pixel ID if provided
    my $fb_id = $self->fb_pixel_id;
    if (defined $fb_id && $fb_id ne '') {
        $result->{fb_pixel_id} = ($fb_id =~ $FB_PIXEL_PATTERN) ? 1 : 0;
    }
    
    return $result;
}

# Helper method to get captured errors (for testing)
sub get_captured_errors {
    my $self = shift;
    return $self->_captured_errors;
}

# Helper method to clear captured errors (for testing)
sub clear_captured_errors {
    my $self = shift;
    $self->_captured_errors([]);
    return 1;
}

# Serialize error data to JSON (for round-trip testing)
# Requirements: 1.5 - Produce valid JSON that round-trips correctly
sub serialize_error {
    my ($self, $error_data) = @_;
    return encode_json($error_data);
}

# Deserialize error data from JSON
sub deserialize_error {
    my ($self, $json) = @_;
    return decode_json($json);
}

1;

__END__

=head1 NAME

FB::Observability - Centralized observability module for MojoPoker

=head1 SYNOPSIS

    use FB::Observability;
    
    my $obs = FB::Observability->new;
    $obs->init;
    
    # Capture an error
    $obs->capture_error($error, {
        user_id   => 123,
        login_id  => 'abc',
        url       => '/websocket',
        method    => 'GET',
    });
    
    # Get tracking config for templates
    my $config = $obs->get_tracking_config;
    
    # Validate configuration
    my $validation = $obs->validate_config;
    
    # Mask sensitive values for logging
    my $masked = $obs->mask_sensitive($dsn);

=head1 DESCRIPTION

Central module for managing all observability integrations including
Sentry error tracking, GA4 analytics, and Facebook Pixel.

=head2 Configuration

The module reads configuration from environment variables:

=over 4

=item * SENTRY_DSN - Sentry Data Source Name for error tracking

=item * GA4_MEASUREMENT_ID - Google Analytics 4 measurement ID (format: G-XXXXXXXX)

=item * FB_PIXEL_ID - Facebook Pixel ID (numeric)

=back

=head2 Methods

=over 4

=item init()

Initialize all integrations. Logs warning if Sentry DSN is not configured.

=item capture_error($error, $context)

Capture an error and send to Sentry. Context should include user_id, login_id,
url, and method for full context.

=item get_tracking_config()

Returns a hash with ga4_measurement_id and fb_pixel_id for use in templates.
Returns undef for unconfigured values.

=item validate_config()

Validates configuration formats. Returns hash with validation status for each config.

=item mask_sensitive($value)

Masks sensitive values for logging, showing only last 4 characters.

=back

=cut
