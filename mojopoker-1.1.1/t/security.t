#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';

use_ok('FB::Security');

# Create security instance
my $security = FB::Security->new;
isa_ok($security, 'FB::Security');

# Test 4.1: Security Headers
subtest 'Security Headers' => sub {
    my $headers = $security->get_security_headers;
    
    ok(defined $headers, 'get_security_headers returns defined value');
    is(ref $headers, 'HASH', 'get_security_headers returns hash');
    
    # Check required headers per Requirements 5.1
    ok(exists $headers->{'X-Frame-Options'}, 'X-Frame-Options header present');
    ok(exists $headers->{'X-Content-Type-Options'}, 'X-Content-Type-Options header present');
    ok(exists $headers->{'X-XSS-Protection'}, 'X-XSS-Protection header present');
    ok(exists $headers->{'Content-Security-Policy'}, 'Content-Security-Policy header present');
    
    # Check header values
    is($headers->{'X-Frame-Options'}, 'SAMEORIGIN', 'X-Frame-Options is SAMEORIGIN');
    is($headers->{'X-Content-Type-Options'}, 'nosniff', 'X-Content-Type-Options is nosniff');
    like($headers->{'X-XSS-Protection'}, qr/1/, 'X-XSS-Protection is enabled');
    like($headers->{'Content-Security-Policy'}, qr/default-src/, 'CSP has default-src');
};

# Test 4.3: Rate Limiting
subtest 'Rate Limiting' => sub {
    my $rate_security = FB::Security->new(
        rate_limit_max => 5,
        rate_limit_window => 60,
    );
    
    my $test_ip = '192.168.1.100';
    
    # First 5 requests should be allowed
    for my $i (1..5) {
        is($rate_security->check_rate_limit($test_ip), 1, "Request $i allowed");
    }
    
    # 6th request should be blocked
    is($rate_security->check_rate_limit($test_ip), 0, 'Request 6 blocked (rate limit exceeded)');
    
    # Different IP should still be allowed
    is($rate_security->check_rate_limit('192.168.1.101'), 1, 'Different IP allowed');
    
    # Empty/undefined IP should be allowed (fail open)
    is($rate_security->check_rate_limit(''), 1, 'Empty IP allowed');
    is($rate_security->check_rate_limit(undef), 1, 'Undefined IP allowed');
};

# Test 4.4: CSRF Token Generation and Validation
subtest 'CSRF Token Generation and Validation' => sub {
    # Generate token
    my $token = $security->generate_csrf_token;
    ok(defined $token, 'generate_csrf_token returns defined value');
    ok(length($token) > 0, 'Token has length');
    is(length($token), 64, 'Token is 64 characters (SHA256 hex)');
    
    # Token should be valid
    is($security->validate_csrf_token($token), 1, 'Valid token validates');
    
    # Token should be single-use (invalid after first validation)
    is($security->validate_csrf_token($token), 0, 'Token invalid after use');
    
    # Invalid tokens should fail
    is($security->validate_csrf_token('invalid_token'), 0, 'Invalid token fails');
    is($security->validate_csrf_token(''), 0, 'Empty token fails');
    is($security->validate_csrf_token(undef), 0, 'Undefined token fails');
    
    # Multiple tokens should be independent
    my $token1 = $security->generate_csrf_token;
    my $token2 = $security->generate_csrf_token;
    isnt($token1, $token2, 'Different tokens generated');
    is($security->validate_csrf_token($token1), 1, 'First token valid');
    is($security->validate_csrf_token($token2), 1, 'Second token valid');
};

# Test 4.6: Attack Pattern Detection
subtest 'Attack Pattern Detection - SQL Injection' => sub {
    # SQL injection patterns should be detected
    is($security->detect_attack_patterns("SELECT * FROM users"), 1, 'SELECT FROM detected');
    is($security->detect_attack_patterns("1' OR '1'='1"), 1, 'OR injection detected');
    is($security->detect_attack_patterns("'; DROP TABLE users--"), 1, 'DROP TABLE detected');
    is($security->detect_attack_patterns("UNION SELECT password FROM users"), 1, 'UNION SELECT detected');
    is($security->detect_attack_patterns("DELETE FROM users WHERE 1=1"), 1, 'DELETE FROM detected');
    is($security->detect_attack_patterns("INSERT INTO users VALUES('hack')"), 1, 'INSERT INTO detected');
    is($security->detect_attack_patterns("UPDATE users SET admin=1"), 1, 'UPDATE SET detected');
    
    # Clean inputs should pass
    is($security->detect_attack_patterns("Hello World"), 0, 'Normal text passes');
    is($security->detect_attack_patterns('user@example.com'), 0, 'Email passes');
    is($security->detect_attack_patterns("John's Poker Room"), 0, 'Apostrophe in name passes');
};

subtest 'Attack Pattern Detection - XSS' => sub {
    # XSS patterns should be detected
    is($security->detect_attack_patterns("<script>alert('xss')</script>"), 1, 'Script tag detected');
    is($security->detect_attack_patterns("javascript:alert(1)"), 1, 'javascript: protocol detected');
    is($security->detect_attack_patterns('<img src="x" onerror="alert(1)">'), 1, 'onerror handler detected');
    is($security->detect_attack_patterns('<body onload="alert(1)">'), 1, 'onload handler detected');
    is($security->detect_attack_patterns('<iframe src="evil.com">'), 1, 'iframe detected');
    is($security->detect_attack_patterns('<svg onload="alert(1)">'), 1, 'svg onload detected');
    
    # Clean HTML-like content should pass
    is($security->detect_attack_patterns("I love <3 poker"), 0, 'Heart emoticon passes');
    is($security->detect_attack_patterns("5 > 3 and 2 < 4"), 0, 'Math comparison passes');
};

subtest 'Attack Pattern Detection - Hash/Array Input' => sub {
    # Hash with attack pattern
    is($security->detect_attack_patterns({
        name => 'John',
        query => "SELECT * FROM users"
    }), 1, 'Hash with SQL injection detected');
    
    # Array with attack pattern
    is($security->detect_attack_patterns([
        'normal',
        '<script>alert(1)</script>'
    ]), 1, 'Array with XSS detected');
    
    # Clean hash
    is($security->detect_attack_patterns({
        name => 'John',
        email => 'john@test.com'
    }), 0, 'Clean hash passes');
    
    # Empty/undefined
    is($security->detect_attack_patterns(''), 0, 'Empty string passes');
    is($security->detect_attack_patterns(undef), 0, 'Undefined passes');
};

# Test sanitize_input
subtest 'Input Sanitization' => sub {
    is($security->sanitize_input('<script>'), '&lt;script&gt;', 'Script tags escaped');
    is($security->sanitize_input('"test"'), '&quot;test&quot;', 'Quotes escaped');
    is($security->sanitize_input("'test'"), '&#x27;test&#x27;', 'Single quotes escaped');
    is($security->sanitize_input('a & b'), 'a &amp; b', 'Ampersand escaped');
    is($security->sanitize_input(undef), '', 'Undefined returns empty string');
};

done_testing();
