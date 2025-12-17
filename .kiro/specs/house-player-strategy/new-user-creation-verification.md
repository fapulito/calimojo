# New User Creation Flow Verification

## Overview

This document verifies that the new user creation flow correctly implements Requirements 6.2, 6.3, and 6.4, ensuring that:
1. New users get their facebook_id stored (Requirement 6.2)
2. New users receive 400 starting chips and 400 invested (Requirement 6.3)
3. A bookmark is generated using HMAC-SHA1 (Requirement 6.4)

## User Creation Entry Points

There are two main paths for creating new users:

### 1. Facebook Authentication (via `authorize()`)
Location: `mojopoker-1.1.1/lib/FB.pm` (lines ~650-690)

### 2. Direct Registration (via `register()`)
Location: `mojopoker-1.1.1/lib/FB.pm` (lines ~530-580)

## Detailed Flow Analysis

### Step 1: Facebook Authentication Triggers Registration

When a user authenticates via Facebook and doesn't exist in the database:

```perl
sub authorize {
    # ... signature verification code ...
    
    # After successful signature verification
    my $user = $self->db->fetch_user( { facebook_id => $opts->{facebook_id} } );
    
    if ( $user && ref $user eq 'FB::User' && $user->id ) {
        # Existing user - login
        $login->user($user);
        $self->_login($login);
    }
    else {
        # New user - register with facebook_id
        $self->register( $login,
            { facebook_id => $opts->{facebook_id}, username => $opts->{facebook_id} } );
    }
}
```

**Verification Point 1**: ✅ The `facebook_id` is passed to `register()` and will be stored in the database.

### Step 2: Register Method Creates User

```perl
sub register {
    my ( $self, $login, $opts ) = @_;

    my $response = ['register_res'];

    # Check if already registered
    if ( $login->has_user ) {
        $response->[1] = {
            success => 0,
            message => 'Already registered.',
            user_id => $login->user->id
        };
        $login->send($response);
        return;
    }

    # Hash password with bcrypt (if provided)
    if ($opts->{password}) {
        $opts->{password} = $self->_bcrypt_hash($opts->{password});
    }

    # Create user in database
    my $user = $self->db->new_user($opts);
    
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
    $self->user_map->{ $login->user->id } = $login->id;

    # Credit initial chips: 400 chips and 400 invested
    $self->db->credit_chips( $login->user->id, 400 );
    $self->db->credit_invested( $login->user->id, 400 );

    # Update user database with final state
    my $ui = $self->_fetch_user_info($login);
    $self->db->update_user( $ui, $login->user->id );

    $response->[1] = { success => 1, %{ $ui } };
    $login->send($response);
}
```

**Verification Point 2**: ✅ After user creation, exactly 400 chips are credited via `credit_chips()`
**Verification Point 3**: ✅ After user creation, exactly 400 invested is credited via `credit_invested()`

### Step 3: Database User Creation (new_user)

Location: `mojopoker-1.1.1/lib/FB/Db.pm` (lines 50-67)

```perl
sub new_user {
   my ($self, $opts) = @_;
   
   # Insert user record with provided options (including facebook_id if present)
   my ( $stmt, @bind ) = $self->sql->insert( 'users', $opts );
   my $sth = $self->dbh->prepare($stmt);
   $sth->execute(@bind);

   # Get the auto-generated user ID
   $opts->{id} = $self->dbh->last_insert_id(undef, undef, 'users', 'id');
   
   # Set default values
   $opts->{reg_date} = time;
   $opts->{level}    = 2;
   $opts->{handle}   = $opts->{username} if $opts->{username};
   
   # Generate bookmark using HMAC-SHA1
   $opts->{bookmark} = hmac_sha1_hex( $opts->{id}, $self->secret );
   
   # Check for database errors
   return if $self->dbh->err;  
   
   # Create and return FB::User object
   my $user = FB::User->new(%$opts);
   return $user;
}
```

**Verification Point 4**: ✅ The `facebook_id` from `$opts` is inserted into the database via SQL::Abstract's insert
**Verification Point 5**: ✅ The bookmark is generated using `hmac_sha1_hex($opts->{id}, $self->secret)`

### Step 4: Bookmark Generation Details

The bookmark generation uses:
- **Algorithm**: HMAC-SHA1 (via `Digest::SHA::hmac_sha1_hex`)
- **Input**: User ID (numeric)
- **Secret Key**: `$self->secret` (default: `'g)ue(ss# %m4e &i@f y25o*u c*69an'`)
- **Output Format**: Hexadecimal string (40 characters)

Import statement in FB::Db.pm:
```perl
use Digest::SHA qw(hmac_sha1_hex);
```

Secret configuration in FB::Db.pm:
```perl
has 'secret' => ( 
   is => 'rw', 
   default => sub { return 'g)ue(ss# %m4e &i@f y25o*u c*69an' }, 
);
```

## Complete Data Flow

```
Facebook Auth Request
    ↓
authorize() verifies signature
    ↓
Check if user exists by facebook_id
    ↓
User NOT found → Call register()
    ↓
register() calls db->new_user({ facebook_id => ..., username => ... })
    ↓
new_user() performs:
  1. INSERT INTO users (facebook_id, username, ...)
  2. Get auto-generated user_id
  3. Generate bookmark = hmac_sha1_hex(user_id, secret)
  4. Return FB::User object with all fields
    ↓
register() calls:
  1. db->credit_chips(user_id, 400)
  2. db->credit_invested(user_id, 400)
  3. db->update_user() to persist final state
    ↓
User created with:
  - facebook_id: stored ✅
  - chips: 400 ✅
  - invested: 400 ✅
  - bookmark: HMAC-SHA1(user_id, secret) ✅
```

## Database Schema Verification

The users table includes the following relevant fields:

```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    facebook_id BIGINT UNIQUE,
    username VARCHAR(255),
    chips INTEGER DEFAULT 0,
    invested INTEGER DEFAULT 0,
    bookmark VARCHAR(40),
    reg_date TIMESTAMP,
    level SMALLINT DEFAULT 1,
    -- ... other fields
);
```

## Chip Management Methods

### credit_chips()
Location: `mojopoker-1.1.1/lib/FB/Db.pm` (line ~123)

Adds chips to a user's balance:
```perl
sub credit_chips {
    my ( $self, $user_id, $chips ) = @_;
    my $sql = <<SQL;
UPDATE users 
SET chips = chips + ? 
WHERE id = ?
SQL
    my $sth = $self->dbh->prepare($sql);
    $sth->execute($chips, $user_id);
}
```

### credit_invested()
Location: `mojopoker-1.1.1/lib/FB/Db.pm` (line ~147)

Adds to a user's invested amount:
```perl
sub credit_invested {
    my ( $self, $user_id, $chips ) = @_;
    my $sql = <<SQL;
UPDATE users 
SET invested = invested + ? 
WHERE id = ?
SQL
    my $sth = $self->dbh->prepare($sql);
    $sth->execute($chips, $user_id);
}
```

## Requirements Compliance

### Requirement 6.2
✅ **WHEN Facebook authentication succeeds for a new user THEN the System SHALL create a new user record with the Facebook ID as the unique identifier**

**Evidence**:
1. The `authorize()` method extracts `facebook_id` from the verified Facebook payload
2. This `facebook_id` is passed to `register()` in the options hash
3. `register()` passes it to `db->new_user($opts)`
4. `new_user()` inserts all fields from `$opts` into the database, including `facebook_id`
5. The database schema has `facebook_id BIGINT UNIQUE` ensuring uniqueness

### Requirement 6.3
✅ **WHEN a new user account is created via Facebook THEN the System SHALL credit the account with 400 starting chips and set invested to 400**

**Evidence**:
1. After `new_user()` returns, `register()` calls:
   - `$self->db->credit_chips( $login->user->id, 400 )`
   - `$self->db->credit_invested( $login->user->id, 400 )`
2. These methods execute SQL UPDATE statements that add exactly 400 to each field
3. The final state is persisted via `update_user()`

### Requirement 6.4
✅ **WHEN a new user account is created THEN the System SHALL generate a unique bookmark hash using HMAC-SHA1 of the user ID for session persistence**

**Evidence**:
1. In `new_user()`, after getting the auto-generated user ID:
   ```perl
   $opts->{bookmark} = hmac_sha1_hex( $opts->{id}, $self->secret );
   ```
2. Uses `Digest::SHA::hmac_sha1_hex()` which implements HMAC-SHA1
3. Input is the user ID (unique per user)
4. Secret key is configured in `$self->secret`
5. Output is a 40-character hexadecimal string
6. This bookmark is included in the FB::User object and stored in the database

## Testing Recommendations

To verify this implementation, property-based tests should:

1. **Test facebook_id storage**: Generate random facebook_ids, create users, verify they're stored and retrievable
2. **Test initial chip amounts**: Create users and verify chips = 400 and invested = 400
3. **Test bookmark generation**: Verify bookmark is 40 hex characters and matches HMAC-SHA1(user_id, secret)
4. **Test bookmark uniqueness**: Create multiple users and verify all bookmarks are unique
5. **Test idempotence**: Verify attempting to create duplicate facebook_id fails appropriately

## Conclusion

The implementation correctly satisfies all three requirements:
- ✅ Facebook ID is stored as the unique identifier (Requirement 6.2)
- ✅ New users receive exactly 400 chips and 400 invested (Requirement 6.3)
- ✅ Bookmark is generated using HMAC-SHA1 of user ID (Requirement 6.4)

The flow is well-structured with proper error handling and follows a clear sequence from authentication through user creation to chip allocation.
