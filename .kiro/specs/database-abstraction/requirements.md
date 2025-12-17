# Requirements Document

## Introduction

The database layer currently only supports PostgreSQL, causing the application to fail when PostgreSQL environment variables are not configured. This prevents local development with SQLite and breaks the advertised "backward compatible" feature. This specification addresses the need for a flexible database abstraction layer that supports both SQLite (for local development) and PostgreSQL (for production) based on environment configuration.

## Glossary

- **Database Abstraction Layer**: A software layer that provides a unified interface for database operations regardless of the underlying database system
- **FB::Db**: The Perl module responsible for all database operations in the Mojo Poker application
- **SQLite**: A lightweight, file-based relational database suitable for local development
- **PostgreSQL**: A production-grade relational database system used for cloud deployments
- **DATABASE_TYPE**: Environment variable that specifies which database system to use
- **Fallback Behavior**: The system's ability to automatically use SQLite when PostgreSQL is not configured
- **DBI**: Database Independent interface for Perl, providing a standard API for database access
- **DBD**: Database Driver, the specific implementation for each database system (DBD::SQLite, DBD::Pg)

## Requirements

### Requirement 1

**User Story:** As a developer, I want to run the poker application locally without configuring PostgreSQL, so that I can quickly start development and testing.

#### Acceptance Criteria

1. WHEN the DATABASE_TYPE environment variable is set to "sqlite" THEN the System SHALL connect to a SQLite database
2. WHEN the DATABASE_TYPE environment variable is not set THEN the System SHALL default to SQLite
3. WHEN SQLite is selected and the database file does not exist THEN the System SHALL create the database file at the configured path
4. WHEN SQLite is selected THEN the System SHALL use the SQLITE_PATH environment variable to locate the database files
5. WHEN SQLite connection fails THEN the System SHALL log a descriptive error message and terminate gracefully

### Requirement 2

**User Story:** As a system administrator, I want to deploy the poker application with PostgreSQL in production, so that I can handle concurrent users and scale the application.

#### Acceptance Criteria

1. WHEN the DATABASE_TYPE environment variable is set to "postgres" THEN the System SHALL connect to a PostgreSQL database
2. WHEN PostgreSQL is selected and required environment variables are missing THEN the System SHALL log which variables are missing and terminate gracefully
3. WHEN PostgreSQL is selected THEN the System SHALL use DATABASE_URL or individual DB_* environment variables for connection
4. WHEN PostgreSQL connection fails THEN the System SHALL log the connection error with details and terminate gracefully
5. WHEN PostgreSQL is selected THEN the System SHALL enable SSL mode based on DB_SSLMODE environment variable

### Requirement 3

**User Story:** As a developer, I want database operations to work identically regardless of whether I'm using SQLite or PostgreSQL, so that I can develop locally and deploy to production without code changes.

#### Acceptance Criteria

1. WHEN executing a database query THEN the System SHALL use the same method signature regardless of database type
2. WHEN inserting a new record THEN the System SHALL return the auto-generated ID using the appropriate method for each database
3. WHEN using SQL::Abstract for query building THEN the System SHALL generate compatible SQL for the selected database
4. WHEN handling timestamps THEN the System SHALL use compatible timestamp formats for both databases
5. WHEN executing transactions THEN the System SHALL use compatible transaction syntax for both databases

### Requirement 4

**User Story:** As a developer, I want clear error messages when database configuration is incorrect, so that I can quickly identify and fix configuration issues.

#### Acceptance Criteria

1. WHEN database connection fails THEN the System SHALL log the database type being attempted
2. WHEN required environment variables are missing THEN the System SHALL list all missing variables in the error message
3. WHEN database file path is invalid for SQLite THEN the System SHALL log the attempted path and permission issues
4. WHEN database schema is missing or outdated THEN the System SHALL provide instructions for running migrations
5. WHEN database operations fail THEN the System SHALL log the SQL statement and error details

### Requirement 5

**User Story:** As a system operator, I want the application to validate database connectivity on startup, so that I can detect configuration issues before users attempt to connect.

#### Acceptance Criteria

1. WHEN the application starts THEN the System SHALL attempt to connect to the configured database
2. WHEN database connection succeeds THEN the System SHALL log the database type and connection details
3. WHEN database connection fails THEN the System SHALL prevent the application from starting
4. WHEN database schema validation is enabled THEN the System SHALL verify required tables exist
5. WHEN running in development mode THEN the System SHALL log detailed database connection information

### Requirement 6

**User Story:** As a developer, I want database-specific optimizations to be applied automatically, so that I get the best performance from each database system.

#### Acceptance Criteria

1. WHEN using PostgreSQL THEN the System SHALL use parameterized queries with placeholders
2. WHEN using SQLite THEN the System SHALL enable foreign key constraints
3. WHEN using PostgreSQL THEN the System SHALL use connection pooling if available
4. WHEN using SQLite THEN the System SHALL use WAL mode for better concurrency
5. WHEN fetching last insert ID THEN the System SHALL use the database-specific method (last_insert_id for PostgreSQL, last_insert_rowid for SQLite)

### Requirement 7

**User Story:** As a developer, I want comprehensive tests for both database backends, so that I can be confident that database operations work correctly in all environments.

#### Acceptance Criteria

1. WHEN running tests THEN the System SHALL test database operations against both SQLite and PostgreSQL
2. WHEN testing user creation THEN the System SHALL verify auto-increment IDs work correctly for both databases
3. WHEN testing queries THEN the System SHALL verify SQL::Abstract generates compatible SQL for both databases
4. WHEN testing timestamps THEN the System SHALL verify timestamp handling works correctly for both databases
5. WHEN testing transactions THEN the System SHALL verify rollback and commit work correctly for both databases

### Requirement 8

**User Story:** As a developer, I want the database abstraction to support future database systems, so that the application can be extended without major refactoring.

#### Acceptance Criteria

1. WHEN adding a new database driver THEN the System SHALL require only implementing a database-specific connection method
2. WHEN database-specific SQL is needed THEN the System SHALL use a strategy pattern to select the appropriate SQL generator
3. WHEN new database operations are added THEN the System SHALL work with all supported database types
4. WHEN database configuration changes THEN the System SHALL not require changes to business logic code
5. WHEN extending database functionality THEN the System SHALL maintain backward compatibility with existing code
