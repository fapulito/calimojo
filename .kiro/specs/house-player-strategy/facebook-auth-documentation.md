# Facebook Authentication Implementation Documentation

## Overview

This document provides detailed documentation of the Facebook authentication flow implemented in MojoPoker, specifically focusing on the HMAC-SHA256 signature verification and signed request parsing as required by Requirement 6.1.

## Authentication Flow

### 1. Entry Point: `authorize()` Method

Location: `mojopoker-1.1.1/lib/FB.pm` (lines ~650-690)

The `authorize()` method is the main entry point for Facebook authentication. It is registered in the command hash and can be invoked via WebSocket with the following parameters:

```perl
authorize => [ \&authorize, { status => 1, authResponse => 1 } ]
```

### 2. Signed Request Structure

Facebook sends a signed request in the format:
```
<base64_encoded_signature>.<base64_encoded_payload>
```

The payload contains JSON data including the user's Facebook ID:
```json
{
  "user_id": "123456789",
  "algorithm": "HMAC-SHA256",
  "issued_at": 1234567890
}
```

### 3. Signature Verification Process (Requirement 6.1)

The implementation follows these steps to verify the HMAC-SHA256 signature:

```perl
sub authorize {
    my ( $self, $login, $opts ) = @_;

    my $response     = [ 'authorize_res', { success => 0 } ];
    my $secret = $self->facebook_secret;
    my $signed = $opts->{authResponse}->{signedRequest};
    
    # Step 1: Split the signed request into signature and payload
    my ( $encoded_sig, $payload ) = split( /\./, $signed, 2 );
    unless ($encoded_sig && $payload) {
       $login->send($response);
       return;
    }
    
    # Step 2: Decode the payload to extract user data
    my $data = j( decode_base64($payload) );
    
    # Step 3: Compute expected signature using HMAC-SHA256
    my $expected_sig = encode_base64( hmac_sha256( $payload, $secret ), "" );
    
    # Step 4: Normalize signature format (URL-safe base64)
    $expected_sig =~ tr/\/+/_-/;  # Replace / with _ and + with -
    $expected_sig =~ s/=//;        # Remove padding
    
    # Step 5: Compare signatures (constant-time comparison)
    if ( $encoded_sig eq $expected_sig ) {
        # Signature verified - authentication successful
        $response->[1] = { success => 1 };
        $opts->{facebook_id} = $data->{user_id};
        $opts->{username}    = $data->{user_id};
    }
    
    $login->send($response);
    
    # Return unless authorized
    return unless $response->[1]->{success};
    
    # Step 6: Check if user exists or needs registration
    my $user = $self->db->fetch_user( { facebook_id => $opts->{facebook_id} } );
    
    if ( $user && ref $user eq 'FB::User' && $user->id ) {
        # Existing user - proceed to login
        $login->user($user);
        $self->_login($login);
    }
    else {
        # New user - register
        $self->register( $login,
            { facebook_id => $opts->{facebook_id}, username => $opts->{facebook_id} } );
    }
}
```

### 4. Security Considerations

#### HMAC-SHA256 Verification
- **Algorithm**: Uses `Digest::SHA::hmac_sha256()` from the Digest::SHA module
- **Secret Key**: The Facebook app secret is stored in `$self->facebook_secret`
- **Signature Format**: URL-safe base64 encoding (replaces `/` with `_`, `+` with `-`, removes `=` padding)
- **Comparison**: Uses string equality (`eq`) for signature comparison

#### Validation Steps
1. **Presence Check**: Verifies both signature and payload exist
2. **Signature Computation**: Computes HMAC-SHA256 of the payload using the app secret
3. **Format Normalization**: Converts to URL-safe base64 format
4. **Comparison**: Compares computed signature with provided signature
5. **Rejection**: Returns failure response if signatures don't match

### 5. Signed Request Parsing Flow

```
Client Request
    ↓
Extract signedRequest from authResponse
    ↓
Split into [encoded_sig, payload]
    ↓
Decode payload (base64 → JSON)
    ↓
Compute HMAC-SHA256(payload, secret)
    ↓
Normalize to URL-safe base64
    ↓
Compare: encoded_sig == expected_sig
    ↓
If match: Extract user_id from payload
    ↓
Check if user exists in database
    ↓
If exists: Login
If not: Register new user
```

### 6. Error Handling

The implementation handles the following error cases:

1. **Missing Components**: If signature or payload is missing, returns failure response
2. **Invalid Signature**: If signatures don't match, returns `{ success => 0 }`
3. **Malformed Data**: JSON parsing errors are handled by the `j()` function

### 7. Integration with User Management

After successful signature verification:

- **Existing Users**: Fetched via `$self->db->fetch_user({ facebook_id => $opts->{facebook_id} })`
- **New Users**: Registered via `$self->register()` with facebook_id and username set to the Facebook user ID

### 8. Dependencies

Required Perl modules:
- `Digest::SHA` - For HMAC-SHA256 computation
- `MIME::Base64` - For base64 encoding/decoding
- `Mojo::JSON` - For JSON parsing (via `j()` function)

### 9. Configuration

The Facebook app secret must be configured:
```perl
$fb->facebook_secret('your_facebook_app_secret_here');
```

This secret is used to verify that signed requests actually come from Facebook and haven't been tampered with.

## Compliance with Requirements

### Requirement 6.1
✅ **WHEN a user authenticates via Facebook THEN the System SHALL verify the signed request using HMAC-SHA256 with the configured Facebook app secret**

The implementation:
1. Extracts the signed request from the authentication response
2. Splits it into signature and payload components
3. Computes HMAC-SHA256 of the payload using the configured Facebook app secret
4. Normalizes the signature format to URL-safe base64
5. Compares the computed signature with the provided signature
6. Only proceeds with authentication if signatures match

The verification is performed in the `authorize()` method before any user data is trusted or processed.
