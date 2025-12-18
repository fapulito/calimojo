#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';

use_ok('FB::Observability');

# Test module instantiation
my $obs = FB::Observability->new;
ok($obs, 'FB::Observability instantiated');

# Test validate_config with no environment variables
{
    local $ENV{SENTRY_DSN} = undef;
    local $ENV{GA4_MEASUREMENT_ID} = undef;
    local $ENV{FB_PIXEL_ID} = undef;
    
    my $obs_empty = FB::Observability->new;
    my $validation = $obs_empty->validate_config;
    
    is(ref $validation, 'HASH', 'validate_config returns hash');
    is($validation->{sentry_dsn}, 1, 'Empty Sentry DSN is valid (disabled)');
    is($validation->{ga4_measurement_id}, 1, 'Empty GA4 ID is valid (disabled)');
    is($validation->{fb_pixel_id}, 1, 'Empty FB Pixel ID is valid (disabled)');
}

# Test validate_config with valid values
{
    local $ENV{SENTRY_DSN} = 'https://abc123@sentry.io/12345';
    local $ENV{GA4_MEASUREMENT_ID} = 'G-ABC123XYZ';
    local $ENV{FB_PIXEL_ID} = '1234567890';
    
    my $obs_valid = FB::Observability->new;
    my $validation = $obs_valid->validate_config;
    
    is($validation->{sentry_dsn}, 1, 'Valid Sentry DSN passes validation');
    is($validation->{ga4_measurement_id}, 1, 'Valid GA4 ID passes validation');
    is($validation->{fb_pixel_id}, 1, 'Valid FB Pixel ID passes validation');
}

# Test validate_config with invalid values
{
    local $ENV{SENTRY_DSN} = 'invalid-dsn';
    local $ENV{GA4_MEASUREMENT_ID} = 'invalid-ga4';
    local $ENV{FB_PIXEL_ID} = 'not-a-number';
    
    my $obs_invalid = FB::Observability->new;
    my $validation = $obs_invalid->validate_config;
    
    is($validation->{sentry_dsn}, 0, 'Invalid Sentry DSN fails validation');
    is($validation->{ga4_measurement_id}, 0, 'Invalid GA4 ID fails validation');
    is($validation->{fb_pixel_id}, 0, 'Invalid FB Pixel ID fails validation');
}

# Test mask_sensitive
{
    is($obs->mask_sensitive('test1234567890'), '**********7890', 'mask_sensitive shows last 4 chars');
    is($obs->mask_sensitive('1234'), '***4', 'mask_sensitive handles 4 char input');
    is($obs->mask_sensitive('abc'), '**c', 'mask_sensitive handles 3 char input');
    is($obs->mask_sensitive(''), '', 'mask_sensitive handles empty string');
    is($obs->mask_sensitive(undef), '', 'mask_sensitive handles undef');
}

# Test get_tracking_config with no values
{
    local $ENV{GA4_MEASUREMENT_ID} = undef;
    local $ENV{FB_PIXEL_ID} = undef;
    
    my $obs_empty = FB::Observability->new;
    my $config = $obs_empty->get_tracking_config;
    
    is(ref $config, 'HASH', 'get_tracking_config returns hash');
    is($config->{ga4_measurement_id}, undef, 'Empty GA4 returns undef');
    is($config->{fb_pixel_id}, undef, 'Empty FB Pixel returns undef');
}

# Test get_tracking_config with values
{
    local $ENV{GA4_MEASUREMENT_ID} = 'G-TEST123';
    local $ENV{FB_PIXEL_ID} = '9876543210';
    
    my $obs_with_values = FB::Observability->new;
    my $config = $obs_with_values->get_tracking_config;
    
    is($config->{ga4_measurement_id}, 'G-TEST123', 'GA4 ID preserved exactly');
    is($config->{fb_pixel_id}, '9876543210', 'FB Pixel ID preserved exactly');
}

# Test init without DSN
{
    local $ENV{SENTRY_DSN} = undef;
    
    my $obs_no_dsn = FB::Observability->new;
    my $result = $obs_no_dsn->init;
    
    is($result, 1, 'init returns 1 without DSN');
    is($obs_no_dsn->sentry_enabled, 0, 'Sentry disabled without DSN');
}

# Test init with valid DSN
{
    local $ENV{SENTRY_DSN} = 'https://abc123@sentry.io/12345';
    
    my $obs_with_dsn = FB::Observability->new;
    my $result = $obs_with_dsn->init;
    
    is($result, 1, 'init returns 1 with valid DSN');
    is($obs_with_dsn->sentry_enabled, 1, 'Sentry enabled with valid DSN');
}

# Test init with invalid DSN
{
    local $ENV{SENTRY_DSN} = 'invalid-dsn';
    
    my $obs_invalid_dsn = FB::Observability->new;
    my $result = $obs_invalid_dsn->init;
    
    is($result, 1, 'init returns 1 with invalid DSN');
    is($obs_invalid_dsn->sentry_enabled, 0, 'Sentry disabled with invalid DSN');
}

# Test capture_error
{
    local $ENV{SENTRY_DSN} = 'https://abc123@sentry.io/12345';
    
    my $obs_capture = FB::Observability->new;
    $obs_capture->init;
    
    my $event = $obs_capture->capture_error('Test error', {
        user_id  => 123,
        login_id => 'testuser',
        url      => '/test',
        method   => 'GET',
    });
    
    is(ref $event, 'HASH', 'capture_error returns hash');
    is($event->{exception}{value}, 'Test error', 'Error message captured');
    is($event->{user}{id}, 123, 'User ID captured');
    is($event->{user}{login_id}, 'testuser', 'Login ID captured');
    is($event->{request}{url}, '/test', 'Request URL captured');
    is($event->{request}{method}, 'GET', 'Request method captured');
    
    # Test round-trip
    my $json = $obs_capture->serialize_error($event);
    my $decoded = $obs_capture->deserialize_error($json);
    
    is_deeply($decoded->{exception}, $event->{exception}, 'Exception round-trips correctly');
    is_deeply($decoded->{user}, $event->{user}, 'User context round-trips correctly');
    is_deeply($decoded->{request}, $event->{request}, 'Request context round-trips correctly');
}

done_testing();
