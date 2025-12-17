# Implementation Plan

- [x] 1. Add database type detection and configuration




  - Add `db_type` attribute to FB::Db with default from DATABASE_TYPE env var
  - Implement fallback to 'sqlite' when DATABASE_TYPE is not set
  - Add validation for supported database types (sqlite, postgres, postgresql)
  - _Requirements: 1.1, 1.2, 2.1_


- [x] 2. Implement SQLite connection builder




  - [x] 2.1 Create _build_sqlite_dbh method


    - Build DSN from SQLITE_PATH environment variable
    - Default to './db/fb.db' if SQLITE_PATH not set
    - Set RaiseError => 1, AutoCommit => 1
    - Enable foreign keys: PRAGMA foreign_keys = ON
    - Enable WAL mode: PRAGMA journal_mode = WAL
    - _Requirements: 1.3, 1.4, 6.2, 6.4_

  - [ ]* 2.2 Write property test for SQLite connection
    - **Property 1: Database Type Detection Consistency**
    - **Validates: Requirements 1.1, 1.2**

  - [x] 2.3 Add SQLite-specific error handling

    - Catch file not found errors
    - Catch permission denied errors
    - Log descriptive error messages with file path
    - _Requirements: 1.5, 4.3_

  - [ ]* 2.4 Write unit tests for SQLite connection errors
    - Test connection with invalid path
    - Test connection with missing directory
    - Test error message format
    - _Requirements: 1.5, 4.3_


- [x] 3. Refactor PostgreSQL connection builder




  - [x] 3.1 Rename _build_dbh to _build_postgres_dbh


    - Keep existing PostgreSQL connection logic
    - Add support for DATABASE_URL parsing
    - Maintain backward compatibility with DB_* env vars
    - _Requirements: 2.3_

  - [x] 3.2 Improve PostgreSQL error handling

    - Check for missing required environment variables
    - List all missing variables in error message
    - Log connection details (host, port, database) on failure
    - _Requirements: 2.2, 2.4, 4.2_

  - [ ]* 3.3 Write unit tests for PostgreSQL connection errors
    - Test connection with missing env vars
    - Test connection with invalid credentials
    - Test error message includes missing variable list
    - _Requirements: 2.2, 4.2_



- [x] 4. Implement database connection dispatcher





  - [x] 4.1 Create new _build_dbh method as dispatcher

    - Check db_type attribute
    - Route to _build_sqlite_dbh for 'sqlite'
    - Route to _build_postgres_dbh for 'postgres' or 'postgresql'
    - Die with clear error for unsupported types
    - Store selected database type for later use
    - _Requirements: 1.1, 1.2, 2.1_

  - [ ]* 4.2 Write property test for database type routing
    - **Property 1: Database Type Detection Consistency**
    - **Validates: Requirements 1.1, 1.2, 2.1**

  - [x] 4.3 Add connection validation on startup

    - Test database ping after connection
    - Verify required tables exist
    - Log database type and connection status
    - _Requirements: 5.1, 5.2, 5.4_

  - [ ]* 4.4 Write unit tests for connection validation
    - Test validation with valid database
    - Test validation with missing schema
    - Test validation logs correct information
    - _Requirements: 5.1, 5.2, 5.4_


- [x] 5. Abstract last insert ID handling



  - [x] 5.1 Create _get_last_insert_id helper method


    - For SQLite: use $dbh->last_insert_id(undef, undef, undef, undef)
    - For PostgreSQL: use $dbh->last_insert_id(undef, undef, $table, $column)
    - Accept table and column parameters
    - Return positive integer ID
    - _Requirements: 3.2, 6.5_

  - [ ]* 5.2 Write property test for last insert ID
    - **Property 3: Last Insert ID Consistency**
    - **Validates: Requirements 3.2, 6.5**

  - [x] 5.3 Update new_user to use _get_last_insert_id


    - Replace hardcoded last_insert_id call
    - Pass 'users' table and 'id' column
    - Handle both SQLite ('user' table) and PostgreSQL ('users' table)
    - _Requirements: 3.2_

  - [ ]* 5.4 Write unit tests for new_user with both databases
    - Test user creation returns valid ID for SQLite
    - Test user creation returns valid ID for PostgreSQL
    - Test IDs are positive integers
    - _Requirements: 3.2, 7.2_


- [x] 6. Checkpoint - Ensure all tests pass




  - Ensure all tests pass, ask the user if questions arise.


- [x] 7. Add comprehensive error logging




  - [x] 7.1 Create _log_error helper method


    - Accept error message and context hash
    - Log database type
    - Log SQL statement if available
    - Log bind parameters if available
    - Format output for readability
    - _Requirements: 4.1, 4.5_

  - [x] 7.2 Update all database methods to use _log_error


    - Update new_user error handling
    - Update fetch_user error handling
    - Update update_user error handling
    - Update chip operation error handling
    - _Requirements: 4.1, 4.5_

  - [ ]* 7.3 Write unit tests for error logging
    - Test error log includes database type
    - Test error log includes SQL statement
    - Test error log includes bind parameters
    - _Requirements: 4.1, 4.5_

- [x] 8. Handle database-specific SQL differences





  - [x] 8.1 Update table name references


    - Use 'user' for SQLite (legacy compatibility)
    - Use 'users' for PostgreSQL (modern convention)
    - Create helper method _get_table_name('users')
    - _Requirements: 3.1_



  - [x] 8.2 Update timestamp handling



    - SQLite: use Unix timestamps (integer)
    - PostgreSQL: use TIMESTAMP type
    - Ensure compatibility in queries
    - _Requirements: 3.4_

  - [ ]* 8.3 Write property test for timestamp compatibility
    - **Property 7: Timestamp Compatibility**
    - **Validates: Requirements 3.4**

  - [ ]* 8.4 Write unit tests for SQL compatibility
    - Test queries work with both databases
    - Test timestamp storage and retrieval
    - Test table name resolution
    - _Requirements: 3.1, 3.4, 7.3_


- [x] 9. Add transaction support






  - [x] 9.1 Create transaction helper methods

    - Create begin_transaction method
    - Create commit_transaction method
    - Create rollback_transaction method
    - Ensure compatibility with both databases
    - _Requirements: 3.5_

  - [ ]* 9.2 Write property test for transaction rollback
    - **Property 8: Transaction Rollback Consistency**
    - **Validates: Requirements 3.5, 7.5**

  - [ ]* 9.3 Write unit tests for transactions
    - Test successful transaction commit
    - Test failed transaction rollback
    - Test database state after rollback
    - _Requirements: 3.5, 7.5_




- [x] 10. Update documentation and configuration





  - [x] 10.1 Update .env.example with database configuration

    - Add DATABASE_TYPE examples
    - Add SQLite configuration section
    - Add PostgreSQL configuration section
    - Add comments explaining each option
    - _Requirements: 1.4, 2.3_

  - [x] 10.2 Update README.md with database setup instructions


    - Add SQLite setup instructions
    - Add PostgreSQL setup instructions
    - Add troubleshooting section
    - Add migration instructions
    - _Requirements: 4.4_

  - [x] 10.3 Create database migration guide


    - Document SQLite to PostgreSQL migration
    - Document PostgreSQL to SQLite migration
    - Include example commands
    - _Requirements: 4.4_

- [x] 11. Final Checkpoint - Ensure all tests pass





  - Ensure all tests pass, ask the user if questions arise.
