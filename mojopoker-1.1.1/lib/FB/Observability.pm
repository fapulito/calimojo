package FB::Observability;
use Moo;
use Mojo::JSON qw(encode_json decode_json);

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

# Requirements: 1.2 - Initialize Sentry with configured DSN
sub init {
    my $self = shift;
    # Placeholder: Initialize all integrations
    # Will initialize Sentry SDK when implemented
    return 1;
}

# Requirements: 1.1, 1.4 - Capture error details and send to Sentry
sub capture_error {
    my ($self, $error, $context) = @_;
    # Placeholder: Send error to Sentry with user/request context
    # $context should include user_id, login_id, request URL, method
    return 1;
}

# Requirements: 2.1, 3.1 - Return config for frontend tracking scripts
sub get_tracking_config {
    my $self = shift;
    # Placeholder: Return hash with ga4_measurement_id and fb_pixel_id
    return {
        ga4_measurement_id => $self->ga4_measurement_id,
        fb_pixel_id        => $self->fb_pixel_id,
    };
}

# Requirements: 7.4 - Mask sensitive values for logging
sub mask_sensitive {
    my ($self, $value) = @_;
    # Placeholder: Show only last 4 characters of sensitive values
    return $value;
}

# Requirements: 7.3 - Validate configuration formats
sub validate_config {
    my $self = shift;
    # Placeholder: Validate that configured values match expected formats
    return 1;
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

=head1 DESCRIPTION

Central module for managing all observability integrations including
Sentry error tracking, GA4 analytics, and Facebook Pixel.

=cut
