# Design Document: Guest User Error Handling

## Overview

The critical issue: `new_user` can return `undef` on database errors, but the code immediately calls `$login->user->id` without checking, causing crashes that prevent gameplay.

This design adds the minimal error handling needed to prevent crashes and let users play.

## Architecture

Simple fix in FB.pm - add null checks after `new_user` calls:

```
FB.pm
├── _guest_login()  → add error check after new_user
├── guest_login()   → add error check after new_user  
└── register()      → add error check after new_user
```

## Components and Interfaces

### Modified: _guest_login (lines 413-425)

```perl
sub _guest_login {
    my ($self, $opts) = @_;
    my $login = $self->_new_login($opts);
    return unless $login;
    
    my $guest_opts = { chips => 400, invested => 400 };
    my $user = $self->db->new_user($guest_opts);
    
    # Error handling - return undef if user creation failed
    unless ($user) {
        warn "Failed to create guest user: database error";
        return;
    }
    
    $login->user($user);
    $self->user_map->{$login->user->id} = $login->id;
    
    $self->join_channel($login, { channel => 'main' });
    return $login;
}
```

### Modified: guest_login (lines 427-450)

```perl
sub guest_login {
    my ($self, $login) = @_;

    unless ($login->has_user) {
        my $guest_opts = { chips => 400, invested => 400 };
        my $user = $self->db->new_user($guest_opts);
        
        # Error handling - send error response if user creation failed
        unless ($user) {
            warn "Failed to create guest user: database error";
            $login->send(['guest_login', {
                success => 0,
                error => 'user_creation_failed',
                message => 'Unable to create guest account. Please try again.'
            }]);
            return;
        }
        
        $login->user($user);
        $self->user_map->{$login->user->id} = $login->id;
    }

    # Rest of function unchanged...
    $self->login_list->{$login->id} = $login;
    $login->send([
        'guest_login',
        {
            success => 1,
            login_id => $login->id,
            user_id => $login->user->id,
            chips => $self->db->fetch_chips($login->user->id),
            timer => int($self->prize_timer->remaining),
        }
    ]);

    $self->_watch_lobby($login);
    $self->_notify_logins();
    $login->send(['notify_leaders', { leaders => $self->db->fetch_leaders }]);
}
```

### Modified: register (lines 489-520)

```perl
sub register {
    my ($self, $login, $opts) = @_;

    my $response = ['register_res'];

    if ($login->has_user) {
        $response->[1] = {
            success => 0,
            message => 'Already registered.',
            user_id => $login->user->id
        };
        $login->send($response);
        return;
    }

    if ($opts->{password}) {
        $opts->{password} = $self->_bcrypt_hash($opts->{password});
    }

    my $user = $self->db->new_user($opts);
    
    # Error handling - send error response if user creation failed
    unless ($user) {
        warn "Failed to create registered user: database error";
        $response->[1] = {
            success => 0,
            message => 'Registration failed. Please try again.'
        };
        $login->send($response);
        return;
    }
    
    $login->user($user);
    $self->user_map->{$login->user->id} = $login->id;

    $self->db->credit_chips($login->user->id, 400);
    $self->db->credit_invested($login->user->id, 400);

    my $ui = $self->_fetch_user_info($login);
    $self->db->update_user($ui, $login->user->id);

    $response->[1] = { success => 1, %{$ui} };
    $login->send($response);
}
```

## Data Models

No schema changes required. The existing users table works as-is.

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Guest login handles database failures gracefully

*For any* guest login attempt where `new_user` returns `undef`, the system should not crash and should either return `undef` (for `_guest_login`) or send an error response (for `guest_login`).

**Validates: Requirements 1.1**

### Property 2: Registration handles database failures gracefully

*For any* registration attempt where `new_user` returns `undef`, the system should not crash and should send an error response to the client.

**Validates: Requirements 1.2**

## Error Handling

| Scenario | Response |
|----------|----------|
| `new_user` fails in `_guest_login` | Log warning, return `undef` |
| `new_user` fails in `guest_login` | Log warning, send error response with `success => 0` |
| `new_user` fails in `register` | Log warning, send error response with `success => 0` |

## Testing Strategy

### Property-Based Testing Framework

**Framework**: Test2::Suite with Test2::Tools::Basic for Perl testing.

### Property-Based Tests

1. **Property 1 Test**: Mock `new_user` to return `undef`, call guest_login, verify no crash and error response sent
2. **Property 2 Test**: Mock `new_user` to return `undef`, call register, verify no crash and error response sent

### Unit Tests

1. **Guest login success**: Verify normal flow works when `new_user` succeeds
2. **Registration success**: Verify normal flow works when `new_user` succeeds
3. **Error response format**: Verify error responses have correct structure
