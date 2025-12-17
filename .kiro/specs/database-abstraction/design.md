# Design Document: Database Abstraction Layer

## Overview

This design implements a flexible database abstraction layer for the Mojo Poker application that supports both SQLite (for local development) and PostgreSQL (for production deployment). The design maintains backward compatibility with existing code while adding the ability to switch between database backends via environment configuration.

The current implementation hardcodes PostgreSQL connectivity, causing application startup failures when PostgreSQL environment variables are not configured. This design solves that problem by:

1. Detecting the desired database type from environment variables
2. Building appropriate database connections based on configuration
3. Abstracting database-specific operations (last insert ID, timestamp handling)
4. Providing clear error messages for configuration issues
5. Maintaining a single, unified API for all database operations

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Application Layer                       │
│                  (FB.pm, FB::Poker, etc.)                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Unified API
                         │
┌────────────────────────▼────────────────────────────────────┐
│                       FB::Db                                 │
│              (Database Abstraction Layer)                    │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Configuration Detection                       │  │
│  │  (DATABASE_TYPE, env vars, fallback logic)           │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────┐         ┌──────────────────┐         │
│  │  SQLite Driver   │         │ PostgreSQL Driver│         │
│  │  (_build_sqlite) │         │  (_build_postgres)│        │
│  └──────────────────┘         └──────────────────┘         │
└────────────────────────────────────────────────────────────┘
                         │
         ┌───────────────┴───────────────┐
         │                               │
┌────────▼────────┐            ┌────────▼────────┐
│     SQLite      │            │   PostgreSQL    │
│   (fb.db file)  │            │  (NeonDB/Cloud) │
└─────────────────┘            └─────────────────┘
```

### Component Interaction Flow

```
1. Application starts
2. FB::Db->new() called
3. _build_dbh() triggered
   ├─> Check DATABASE_TYPE env var
   ├─> If "sqlite" or unset → _build_sqlite_dbh()
   ├─> If "postgres" → _build_postgres_dbh()
   └─> Store database type for later use
4. Database connection established
5. Application code calls database methods
6. FB::Db routes to appropriate implementation
7. Results returned to application
```

## Components and Interfaces

### 1. FB::Db Module (Enhanced)

**Attributes:**

```perl
has 'secret' => (
    is => 'rw',
    default => sub { return 'g)ue(ss# %m4e &i@f y25o*u c*69an' }
);

has 'db_type' => (
    is => 'rw',
    default => sub { return $ENV{DATABASE_TYPE} || 'sqlite' }
);

has 'dbh' => (
    is => 'rw',
    builder => '_build_dbh'
);

has 'sql' => (
    is => 'rw',
    isa => sub { die "Not a SQL::Abstract!" unless $_[0]->isa('SQL::Abstract') },
    builder => '_build_sql'
);
```

**Methods:**

```perl
# Connection builders
sub _build_dbh { }           # Dispatcher based on db_type
sub _build_sqlite_dbh { }    # SQLite-specific connection
sub _build_postgres_dbh { }  # PostgreSQL-specific connection

# Database-agnostic operations
sub new_user { }
sub fetch_user { }
sub update_user { }
sub fetch_leaders { }
sub reset_leaders { }
sub debit_chips { }
sub credit_chips { }
sub fetch_chips { }
sub credit_invested { }

# Helper methods
sub _get_last_insert_id { }  # Abstraction for auto-increment IDs
sub _log_error { }           # Consistent error logging
sub _validate_connection { } # Startup validation
```

### 2. Database Connection Strategy

**SQLite Connection:**
- Uses `dbi:SQLite:dbname=path/to/file`
- Enables foreign keys: `PRAGMA foreign_keys = ON`
- Enables WAL mode: `PRAGMA journal_mode = WAL`
- Uses `last_insert_rowid()` for auto-increment IDs
- Defaults to `./db/fb.db` if SQLITE_PATH not set

**PostgreSQL Connection:**
- Uses `dbi:Pg:dbname=...;host=...;port=...;sslmode=...`
- Supports DATABASE_URL parsing or individual env vars
- Uses `last_insert_id(undef, undef, 'table', 'column')` for IDs
- Enables UTF-8: `pg_enable_utf8 => 1`
- Requires SSL by default: `sslmode=require`

### 3. Configuration Detection Logic

```perl
sub _build_dbh {
    my $self = shift;
    my $db_type = $self->db_type;
    
    if ($db_type eq 'sqlite') {
        return $self->_build_sqlite_dbh();
    }
    elsif ($db_type eq 'postgres' || $db_type eq 'postgresql') {
        return $self->_build_postgres_dbh();
    }
    else {
        die "Unsupported DATABASE_TYPE: $db_type. Use 'sqlite' or 'postgres'";
    }
}
```

## Data Models

### Environment Variables

**SQLite Configuration:**
```bash
DATABASE_TYPE=sqlite          # or unset (defaults to sqlite)
SQLITE_PATH=./db              # Path to database files
```

**PostgreSQL Configuration (Option 1 - DATABASE_URL):**
```bash
DATABASE_TYPE=postgres
DATABASE_URL=postgresql://user:pass@host:port/dbname?sslmode=require
```

**PostgreSQL Configuration (Option 2 - Individual vars):**
```bash
DATABASE_TYPE=postgres
DB_HOST=ep-example-123.us-east-2.aws.neon.tech
DB_USER=username
DB_PASSWORD=password
DB_PORT=5432
DB_NAME=neondb
DB_SSLMODE=require
```

### Database Schema Compatibility

Both databases use the same schema structure with minor differences:

**Common Tables:**
- `users` - User accounts and chips
- `logins` - Active login sessions
- `leaderboard` - Player rankings
- `tables_ring` - Ring game tables
- `tables_tour` - Tournament tables
- `chat_messages` - Chat history
- `user_stats` - Player statistics

**SQLite-specific:**
- Uses `INTEGER PRIMARY KEY` for auto-increment
- Uses `datetime` as text (Unix timestamps)
- Table name: `user` (legacy compatibility)

**PostgreSQL-specific:**
- Uses `SERIAL PRIMARY KEY` for auto-increment
- Uses `TIMESTAMP` for datetime
- Table name: `users` (plural, modern convention)
- Supports stored procedures and triggers

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Database Type Detection Consistency
*For any* environment configuration, if DATABASE_TYPE is set to "sqlite" or is unset, then the system should connect to SQLite; if set to "postgres", then the system should connect to PostgreSQL.
**Validates: Requirements 1.1, 1.2, 2.1**

### Property 2: Connection Failure Graceful Termination
*For any* database connection attempt that fails, the system should log a descriptive error message and terminate without starting the application server.
**Validates: Requirements 1.5, 2.4, 5.3**

### Property 3: Last Insert ID Consistency
*For any* new record insertion, the returned auto-generated ID should be a positive integer regardless of database type.
**Validates: Requirements 3.2, 6.5**

### Property 4: Query API Uniformity
*For any* database operation (insert, select, update, delete), the method signature and return value format should be identical regardless of database type.
**Validates: Requirements 3.1, 8.3**

### Property 5: Environment Variable Validation
*For any* PostgreSQL configuration, if required environment variables (DB_HOST, DB_USER, DB_PASSWORD) are missing, the system should list all missing variables in the error message before terminating.
**Validates: Requirements 2.2, 4.2**

### Property 6: SQLite File Creation
*For any* SQLite configuration where the database file does not exist, the system should create the file at the specified path if the directory exists and is writable.
**Validates: Requirements 1.3**

### Property 7: Timestamp Compatibility
*For any* timestamp operation (insert, update, query), the timestamp should be stored and retrieved correctly in both SQLite (Unix timestamp) and PostgreSQL (TIMESTAMP type).
**Validates: Requirements 3.4**

### Property 8: Transaction Rollback Consistency
*For any* failed transaction, both SQLite and PostgreSQL should rollback all changes and leave the database in its pre-transaction state.
**Validates: Requirements 3.5, 7.5**

## Error Handling

### Connection Errors

**SQLite Errors:**
```perl
# File not found / permission denied
die "SQLite database file not accessible: $db_path\n" .
    "Error: $DBI::errstr\n" .
    "Check SQLITE_PATH environment variable and file permissions.";

# Schema missing
die "SQLite database exists but schema is missing.\n" .
    "Run: sqlite3 $db_path < db/fb.schema";
```

**PostgreSQL Errors:**
```perl
# Missing environment variables
die "PostgreSQL configuration incomplete. Missing variables:\n" .
    join("\n", @missing_vars) . "\n" .
    "Set DATABASE_URL or individual DB_* variables.";

# Connection refused
die "PostgreSQL connection failed: $DBI::errstr\n" .
    "Host: $db_host, Port: $db_port, Database: $db_name\n" .
    "Check network connectivity and credentials.";
```

### Runtime Errors

**Query Execution Errors:**
```perl
sub _execute_with_error_handling {
    my ($self, $sth, @bind) = @_;
    
    eval {
        $sth->execute(@bind);
    };
    
    if ($@) {
        $self->_log_error(
            "Query execution failed",
            {
                error => $@,
                sql => $sth->{Statement},
                params => \@bind,
                db_type => $self->db_type
            }
        );
        return;
    }
    
    return 1;
}
```

**User Creation Errors:**
```perl
sub new_user {
    my ($self, $opts) = @_;
    
    eval {
        # ... insertion logic ...
    };
    
    if ($@) {
        warn "Failed to create user: $@\n";
        warn "Database type: " . $self->db_type . "\n";
        warn "Options: " . Dumper($opts);
        return;  # Return undef to signal failure
    }
    
    return $user;
}
```

### Validation Errors

**Startup Validation:**
```perl
sub _validate_connection {
    my $self = shift;
    
    # Test connection
    eval {
        my $result = $self->dbh->ping;
        die "Database ping failed" unless $result;
    };
    
    if ($@) {
        die "Database validation failed: $@\n" .
            "Database type: " . $self->db_type . "\n" .
            "Cannot start application without valid database connection.";
    }
    
    # Test schema
    eval {
        my $table_name = $self->db_type eq 'sqlite' ? 'user' : 'users';
        $self->dbh->do("SELECT 1 FROM $table_name LIMIT 1");
    };
    
    if ($@) {
        die "Database schema validation failed: $@\n" .
            "Run database migrations before starting application.";
    }
    
    return 1;
}
```

## Testing Strategy

### Unit Tests

Unit tests verify specific database operations work correctly:

1. **Connection Tests**
   - Test SQLite connection with valid path
   - Test SQLite connection with invalid path
   - Test PostgreSQL connection with valid credentials
   - Test PostgreSQL connection with missing credentials
   - Test DATABASE_TYPE detection logic

2. **CRUD Operation Tests**
   - Test user creation returns valid ID
   - Test user fetch returns correct data
   - Test user update modifies records
   - Test chip debit/credit operations
   - Test leaderboard queries

3. **Error Handling Tests**
   - Test graceful failure on connection errors
   - Test error messages include required details
   - Test invalid SQL generates appropriate errors

### Property-Based Tests

Property-based tests verify universal correctness properties across many inputs:

1. **Property Test: Database Type Detection**
   - Generate random environment configurations
   - Verify correct database type is selected
   - **Feature: database-abstraction, Property 1: Database Type Detection Consistency**
   - **Validates: Requirements 1.1, 1.2, 2.1**

2. **Property Test: Last Insert ID Consistency**
   - Generate random user data
   - Insert into both SQLite and PostgreSQL
   - Verify both return positive integer IDs
   - **Feature: database-abstraction, Property 3: Last Insert ID Consistency**
   - **Validates: Requirements 3.2, 6.5**

3. **Property Test: Query API Uniformity**
   - Generate random database operations
   - Execute against both databases
   - Verify identical method signatures and return formats
   - **Feature: database-abstraction, Property 4: Query API Uniformity**
   - **Validates: Requirements 3.1, 8.3**

4. **Property Test: Timestamp Compatibility**
   - Generate random timestamps
   - Store and retrieve from both databases
   - Verify values are preserved correctly
   - **Feature: database-abstraction, Property 7: Timestamp Compatibility**
   - **Validates: Requirements 3.4**

5. **Property Test: Transaction Rollback**
   - Generate random transaction sequences
   - Force failures at random points
   - Verify database state is unchanged after rollback
   - **Feature: database-abstraction, Property 8: Transaction Rollback Consistency**
   - **Validates: Requirements 3.5, 7.5**

### Integration Tests

Integration tests verify the database layer works with the full application:

1. **Guest User Creation Flow**
   - Start application with SQLite
   - Connect via WebSocket
   - Verify guest user is created
   - Verify user can join tables

2. **Database Migration Test**
   - Create SQLite database with test data
   - Run migration to PostgreSQL
   - Verify all data transferred correctly
   - Verify application works with PostgreSQL

3. **Fallback Behavior Test**
   - Start application without DATABASE_TYPE set
   - Verify SQLite is used by default
   - Verify application functions normally

### Test Configuration

**Property-based test configuration:**
- Minimum 100 iterations per property test
- Use Test::More for Perl unit tests
- Use Test::PostgreSQL for PostgreSQL test instances
- Use temporary SQLite files for test isolation

**Test database setup:**
```perl
# SQLite test database
my $test_db = File::Temp->new(SUFFIX => '.db');
$ENV{DATABASE_TYPE} = 'sqlite';
$ENV{SQLITE_PATH} = $test_db->filename;

# PostgreSQL test database
use Test::PostgreSQL;
my $pgsql = Test::PostgreSQL->new()
    or plan skip_all => $Test::PostgreSQL::errstr;
$ENV{DATABASE_TYPE} = 'postgres';
$ENV{DATABASE_URL} = $pgsql->dsn;
```

## Implementation Notes

### Backward Compatibility

The design maintains backward compatibility by:

1. **Default to SQLite**: If DATABASE_TYPE is not set, use SQLite
2. **Preserve existing API**: All existing method signatures remain unchanged
3. **Support both table names**: Handle both `user` (SQLite legacy) and `users` (PostgreSQL)
4. **Graceful degradation**: If PostgreSQL fails, provide clear migration path

### Performance Considerations

**SQLite Optimizations:**
- Enable WAL mode for better concurrency
- Use prepared statements for repeated queries
- Keep database file on fast storage (SSD)

**PostgreSQL Optimizations:**
- Use connection pooling (PgBouncer) for production
- Enable prepared statements
- Use indexes on frequently queried columns

### Security Considerations

1. **Credential Management**
   - Never log database passwords
   - Use environment variables for all credentials
   - Support .env files for local development

2. **SQL Injection Prevention**
   - Use SQL::Abstract for query building
   - Use parameterized queries for all user input
   - Validate input before database operations

3. **File Permissions (SQLite)**
   - Set restrictive permissions on database files (0600)
   - Validate directory permissions before creating files
   - Warn if database file is world-readable

## Migration Path

### From Current (PostgreSQL-only) to New (Multi-database)

1. **Update FB::Db module** with new connection logic
2. **Add database type detection** in _build_dbh
3. **Implement SQLite connection builder**
4. **Abstract last_insert_id calls**
5. **Add error handling and logging**
6. **Update tests** to cover both databases
7. **Update documentation** with configuration examples

### For Existing Deployments

**PostgreSQL users (no changes needed):**
```bash
# Add this to .env
DATABASE_TYPE=postgres
# Keep existing DB_* variables
```

**SQLite users (new capability):**
```bash
# Add this to .env
DATABASE_TYPE=sqlite
SQLITE_PATH=./db
# Remove DB_* variables
```

## Future Enhancements

1. **Additional Database Support**
   - MySQL/MariaDB driver
   - MongoDB adapter for NoSQL option

2. **Connection Pooling**
   - Implement connection pool for PostgreSQL
   - Add connection health checks

3. **Query Caching**
   - Cache frequently-used queries
   - Implement query result caching layer

4. **Database Monitoring**
   - Add query performance logging
   - Track slow queries
   - Monitor connection pool usage

5. **Schema Versioning**
   - Implement database migration system
   - Track schema version in database
   - Auto-run migrations on startup
