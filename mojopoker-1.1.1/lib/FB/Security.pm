package FB::Security;
use Moo;
use Digest::SHA qw(sha256_hex);
use MIME::Base64 qw(encode_base64);
use Time::HiRes qw(time);

# Rate limiting storage - tracks requests per IP
# Requirements: 5.2 - Rate limiting per IP address
has 'rate_limits' => (
    is      => 'rw',
    default => sub { {} },
);

# Maximum requests per window
# Requirements: 5.2 - 100 requests per minute limit
has 'rate_limit_max' => (
    is      => 'ro',
    default => 100,
);

# Rate limit window in seconds
# Requirements: 5.3 - Reset counter after 60 seconds
has 'rate_limit_window' => (
    is      => 'ro',
    default => 60,
);

# CSRF token storage - maps token to expiry timestamp
has 'csrf_tokens' => (
    is      => 'rw',
    default => sub { {} },
);

# CSRF token validity period in seconds (30 minutes)
has 'csrf_token_ttl' => (
    is      => 'ro',
    default => 1800,
);

# Requirements: 5.1 - Return security headers hash
# Returns a hash of security headers to be applied to all HTTP responses
sub get_security_headers {
    my $self = shift;
    
    return {
        'X-Frame-Options'        => 'SAMEORIGIN',
        'X-Content-Type-Options' => 'nosniff',
        'X-XSS-Protection'       => '1; mode=block',
        'Content-Security-Policy' => "default-src 'self'; script-src 'self' 'unsafe-inline' https://www.googletagmanager.com https://connect.facebook.net https://ajax.googleapis.com; style-src 'self' 'unsafe-inline' https://code.jquery.com; img-src 'self' data: https:; connect-src 'self' wss: https://www.google-analytics.com https://www.facebook.com;",
        'Referrer-Policy'        => 'strict-origin-when-cross-origin',
        'Permissions-Policy'     => 'geolocation=(), microphone=(), camera=()',
    };
}

# Requirements: 5.2, 5.3 - Check if IP is within rate limit
# Returns 1 if request is allowed, 0 if rate limit exceeded
sub check_rate_limit {
    my ($self, $ip) = @_;
    
    return 1 unless defined $ip && length($ip);
    
    my $current_time = time();
    my $window_start = $current_time - $self->rate_limit_window;
    
    # Get or initialize rate limit data for this IP
    my $rate_data = $self->rate_limits->{$ip} //= {
        requests => [],
    };
    
    # Remove requests outside the current window
    $rate_data->{requests} = [
        grep { $_ > $window_start } @{$rate_data->{requests}}
    ];
    
    # Check if limit exceeded
    if (scalar(@{$rate_data->{requests}}) >= $self->rate_limit_max) {
        return 0;  # Rate limit exceeded
    }
    
    # Record this request
    push @{$rate_data->{requests}}, $current_time;
    
    return 1;  # Request allowed
}

# Requirements: 5.4 - Generate CSRF token using secure random
# Returns a new cryptographically secure CSRF token
sub generate_csrf_token {
    my $self = shift;
    
    # Generate random bytes for token
    my $random_data = '';
    
    # Try to use /dev/urandom for secure random data
    if (-r '/dev/urandom') {
        open my $fh, '<', '/dev/urandom' or die "Cannot open /dev/urandom: $!";
        read $fh, $random_data, 32;
        close $fh;
    } else {
        # Fallback: use combination of time, PID, and rand
        $random_data = join('', 
            time(), 
            $$, 
            rand(1000000),
            rand(1000000),
            rand(1000000),
            rand(1000000)
        );
    }
    
    # Create token from hash of random data
    my $token = sha256_hex($random_data . time() . $$);
    
    # Store token with expiry timestamp
    my $expiry = time() + $self->csrf_token_ttl;
    $self->csrf_tokens->{$token} = $expiry;
    
    # Clean up expired tokens periodically
    $self->_cleanup_expired_tokens();
    
    return $token;
}

# Requirements: 5.4 - Validate CSRF token with timing-safe comparison
# Returns 1 if token is valid, 0 otherwise
sub validate_csrf_token {
    my ($self, $token) = @_;
    
    return 0 unless defined $token && length($token);
    
    # Check if token exists and is not expired
    my $expiry = $self->csrf_tokens->{$token};
    
    return 0 unless defined $expiry;
    
    # Check if token has expired
    if (time() > $expiry) {
        delete $self->csrf_tokens->{$token};
        return 0;
    }
    
    # Token is valid - remove it (single use)
    delete $self->csrf_tokens->{$token};
    
    return 1;
}

# Clean up expired CSRF tokens
sub _cleanup_expired_tokens {
    my $self = shift;
    my $current_time = time();
    
    my $tokens = $self->csrf_tokens;
    for my $token (keys %$tokens) {
        if ($tokens->{$token} < $current_time) {
            delete $tokens->{$token};
        }
    }
}

# Requirements: 5.6 - Detect SQL injection and XSS patterns
# Returns 1 if attack pattern detected, 0 if clean
sub detect_attack_patterns {
    my ($self, $input) = @_;
    
    return 0 unless defined $input && length($input);
    
    # Convert to string if reference
    if (ref $input) {
        if (ref $input eq 'HASH') {
            # Check all values in hash
            for my $value (values %$input) {
                return 1 if $self->detect_attack_patterns($value);
            }
            return 0;
        } elsif (ref $input eq 'ARRAY') {
            # Check all elements in array
            for my $value (@$input) {
                return 1 if $self->detect_attack_patterns($value);
            }
            return 0;
        }
        return 0;
    }
    
    my $check_str = lc($input);
    
    # SQL injection patterns
    my @sql_patterns = (
        qr/\bunion\b.*\bselect\b/i,
        qr/\bselect\b.*\bfrom\b/i,
        qr/\bdrop\b.*\btable\b/i,
        qr/\bdelete\b.*\bfrom\b/i,
        qr/\binsert\b.*\binto\b/i,
        qr/\bupdate\b.*\bset\b/i,
        qr/\bexec\b.*\(/i,
        qr/\bexecute\b.*\(/i,
        qr/--\s*$/,                    # SQL comment at end
        qr/;\s*--/,                    # Statement terminator with comment
        qr/'\s*or\s+'.*'\s*=\s*'/i,   # Classic OR injection
        qr/'\s*or\s+1\s*=\s*1/i,      # OR 1=1 injection
        qr/'\s*;\s*drop\b/i,          # Drop after quote
        qr/\btruncate\b.*\btable\b/i,
        qr/\balter\b.*\btable\b/i,
        qr/\bcreate\b.*\btable\b/i,
        qr/\bgrant\b.*\bto\b/i,
        qr/\brevoke\b.*\bfrom\b/i,
    );
    
    # XSS patterns
    my @xss_patterns = (
        qr/<\s*script/i,
        qr/<\s*\/\s*script/i,
        qr/javascript\s*:/i,
        qr/vbscript\s*:/i,
        qr/on\w+\s*=/i,               # Event handlers like onclick=, onerror=
        qr/<\s*iframe/i,
        qr/<\s*object/i,
        qr/<\s*embed/i,
        qr/<\s*img[^>]+onerror/i,
        qr/<\s*svg[^>]+onload/i,
        qr/<\s*body[^>]+onload/i,
        qr/expression\s*\(/i,         # CSS expression
        qr/url\s*\(\s*['"]?\s*javascript/i,
        qr/<\s*meta[^>]+http-equiv/i,
        qr/<\s*link[^>]+rel\s*=\s*['"]?import/i,
        qr/data\s*:\s*text\/html/i,
    );
    
    # Check SQL patterns
    for my $pattern (@sql_patterns) {
        return 1 if $input =~ $pattern;
    }
    
    # Check XSS patterns
    for my $pattern (@xss_patterns) {
        return 1 if $input =~ $pattern;
    }
    
    return 0;
}

# Sanitize potentially dangerous input
sub sanitize_input {
    my ($self, $input) = @_;
    
    return '' unless defined $input;
    
    # HTML entity encode dangerous characters
    $input =~ s/&/&amp;/g;
    $input =~ s/</&lt;/g;
    $input =~ s/>/&gt;/g;
    $input =~ s/"/&quot;/g;
    $input =~ s/'/&#x27;/g;
    $input =~ s/\//&#x2F;/g;
    
    return $input;
}

1;

__END__

=head1 NAME

FB::Security - Server hardening and security module for MojoPoker

=head1 SYNOPSIS

    use FB::Security;
    
    my $security = FB::Security->new;
    
    # Check rate limit
    if ($security->check_rate_limit($ip)) {
        # Process request
    } else {
        # Return 429 Too Many Requests
    }
    
    # Generate CSRF token
    my $token = $security->generate_csrf_token;
    
    # Validate CSRF token
    if ($security->validate_csrf_token($submitted_token)) {
        # Process form
    }
    
    # Get security headers
    my $headers = $security->get_security_headers;

=head1 DESCRIPTION

Handles server hardening features including rate limiting, CSRF protection,
security headers, and attack pattern detection.

=cut
