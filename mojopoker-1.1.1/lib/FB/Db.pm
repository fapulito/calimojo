package FB::Db;

use Moo;
use FB::User;

use DBI;
use SQL::Abstract;
use Digest::SHA qw(hmac_sha1_hex);

#use Data::Dumper;

has 'secret' => ( 
   is => 'rw', 
   default => sub { return 'g)ue(ss# %m4e &i@f y25o*u c*69an' }, 
);

has 'db_type' => (
   is => 'rw',
   default => sub { 
      my $type = $ENV{DATABASE_TYPE} || 'sqlite';
      # Normalize postgresql to postgres
      $type = 'postgres' if $type eq 'postgresql';
      # Validate supported types
      die "Unsupported DATABASE_TYPE: $type. Use 'sqlite', 'postgres', or 'postgresql'"
         unless $type eq 'sqlite' || $type eq 'postgres';
      return $type;
   },
);

has 'dbh' => ( 
   is => 'rw', 
   builder => '_build_dbh',
);

sub _build_dbh {
    my $self = shift;
    my $db_type = $self->db_type;
    
    my $dbh;
    if ($db_type eq 'sqlite') {
        $dbh = $self->_build_sqlite_dbh();
    }
    elsif ($db_type eq 'postgres') {
        $dbh = $self->_build_postgres_dbh();
    }
    else {
        die "Unsupported DATABASE_TYPE: $db_type. Use 'sqlite' or 'postgres'";
    }
    
    # Validate connection before returning
    $self->_validate_connection($dbh);
    
    return $dbh;
}

sub _build_sqlite_dbh {
    my $self = shift;
    
    # Get database path from environment or use default
    my $db_path = $ENV{SQLITE_PATH} || './db';
    my $db_file = "$db_path/fb.db";
    
    # Check if directory exists
    if (!-d $db_path) {
        die "SQLite database directory does not exist: $db_path\n" .
            "Create the directory or set SQLITE_PATH to a valid directory.";
    }
    
    # Check if directory is writable
    if (!-w $db_path) {
        die "SQLite database directory is not writable: $db_path\n" .
            "Check directory permissions.";
    }
    
    # Build DSN
    my $dsn = "dbi:SQLite:dbname=$db_file";
    
    # Connect to database
    my $dbh = eval {
        DBI->connect(
            $dsn,
            '',  # SQLite doesn't use username
            '',  # SQLite doesn't use password
            { 
                RaiseError => 1, 
                AutoCommit => 1,
                sqlite_unicode => 1,
            }
        );
    };
    
    if ($@) {
        die "SQLite database connection failed: $@\n" .
            "Database file: $db_file\n" .
            "Check SQLITE_PATH environment variable and file permissions.";
    }
    
    if (!$dbh) {
        die "SQLite database connection failed: $DBI::errstr\n" .
            "Database file: $db_file\n" .
            "Check SQLITE_PATH environment variable and file permissions.";
    }
    
    # Enable foreign keys
    eval {
        $dbh->do('PRAGMA foreign_keys = ON');
    };
    if ($@) {
        warn "Failed to enable foreign keys: $@\n";
    }
    
    # Enable WAL mode for better concurrency
    eval {
        $dbh->do('PRAGMA journal_mode = WAL');
    };
    if ($@) {
        warn "Failed to enable WAL mode: $@\n";
    }
    
    return $dbh;
}

sub _build_postgres_dbh {
    my $self = shift;
    
    my ($db_host, $db_user, $db_pass, $db_port, $db_name, $sslmode);
    
    # Try DATABASE_URL first (standard for cloud deployments)
    if ($ENV{DATABASE_URL}) {
        # Parse DATABASE_URL: postgresql://user:pass@host:port/dbname?sslmode=require
        my $url = $ENV{DATABASE_URL};
        
        if ($url =~ m{^postgres(?:ql)?://([^:]+):([^@]+)@([^:/]+)(?::(\d+))?/([^?]+)(?:\?(.*))?$}) {
            $db_user = $1;
            $db_pass = $2;
            $db_host = $3;
            $db_port = $4 || 5432;
            $db_name = $5;
            
            # Parse query parameters for sslmode
            if ($6) {
                my @params = split /&/, $6;
                foreach my $param (@params) {
                    if ($param =~ /^sslmode=(.+)$/) {
                        $sslmode = $1;
                    }
                }
            }
            $sslmode ||= 'require';
        } else {
            die "DATABASE_URL format invalid. Expected: postgresql://user:pass\@host:port/dbname?sslmode=require\n" .
                "Got: $url";
        }
    }
    # Fall back to individual DB_* environment variables
    else {
        # Check for required variables and collect missing ones
        my @missing_vars;
        push @missing_vars, 'DB_HOST' unless $ENV{DB_HOST};
        push @missing_vars, 'DB_USER' unless $ENV{DB_USER};
        push @missing_vars, 'DB_PASSWORD' unless $ENV{DB_PASSWORD};
        
        if (@missing_vars) {
            die "PostgreSQL configuration incomplete. Missing required environment variables:\n" .
                "  " . join("\n  ", @missing_vars) . "\n" .
                "Either set DATABASE_URL or all of: DB_HOST, DB_USER, DB_PASSWORD\n" .
                "Optional variables: DB_PORT (default: 5432), DB_NAME (default: neondb), DB_SSLMODE (default: require)";
        }
        
        $db_host = $ENV{DB_HOST};
        $db_user = $ENV{DB_USER};
        $db_pass = $ENV{DB_PASSWORD};
        $db_port = $ENV{DB_PORT} || 5432;
        $db_name = $ENV{DB_NAME} || 'neondb';
        $sslmode = $ENV{DB_SSLMODE} || 'require';
    }
    
    # Build DSN
    my $dsn = "dbi:Pg:dbname=$db_name;host=$db_host;port=$db_port;sslmode=$sslmode";
    
    # Attempt connection
    my $dbh = eval {
        DBI->connect(
            $dsn,
            $db_user,
            $db_pass,
            { RaiseError => 1, AutoCommit => 1, pg_enable_utf8 => 1 }
        );
    };
    
    if ($@) {
        die "PostgreSQL connection failed: $@\n" .
            "Connection details:\n" .
            "  Host: $db_host\n" .
            "  Port: $db_port\n" .
            "  Database: $db_name\n" .
            "  SSL Mode: $sslmode\n" .
            "Check network connectivity, credentials, and firewall settings.";
    }
    
    if (!$dbh) {
        die "PostgreSQL connection failed: $DBI::errstr\n" .
            "Connection details:\n" .
            "  Host: $db_host\n" .
            "  Port: $db_port\n" .
            "  Database: $db_name\n" .
            "  SSL Mode: $sslmode\n" .
            "Check network connectivity, credentials, and firewall settings.";
    }
    
    return $dbh;
}

sub _validate_connection {
    my ($self, $dbh) = @_;
    
    # Test database ping
    eval {
        my $result = $dbh->ping;
        die "Database ping failed" unless $result;
    };
    
    if ($@) {
        die "Database validation failed: $@\n" .
            "Database type: " . $self->db_type . "\n" .
            "Cannot start application without valid database connection.";
    }
    
    # Test schema - verify required tables exist (only if VALIDATE_SCHEMA is set)
    if ($ENV{VALIDATE_SCHEMA}) {
        eval {
            my $table_name = $self->_get_table_name('users');
            $dbh->do("SELECT 1 FROM $table_name LIMIT 1");
        };
        
        if ($@) {
            die "Database schema validation failed: $@\n" .
                "Database type: " . $self->db_type . "\n" .
                "Required table '" . $self->_get_table_name('users') . "' not found.\n" .
                "Run database migrations before starting application.";
        }
    }
    
    # Log successful connection
    warn "Database connection validated successfully\n" .
         "  Type: " . $self->db_type . "\n" .
         "  Status: Connected\n";
    
    return 1;
}

has 'sql' => (
    is => 'rw',
    isa =>
      sub { die "Not a SQL::Abstract!" unless $_[0]->isa('SQL::Abstract') },
    builder => '_build_sql',
);

sub _build_sql {
    return SQL::Abstract->new;
}

sub _get_last_insert_id {
    my ($self, $table, $column) = @_;
    
    # Default column to 'id' if not specified
    $column ||= 'id';
    
    my $id;
    if ($self->db_type eq 'sqlite') {
        # SQLite: use last_insert_id with all undef parameters
        $id = $self->dbh->last_insert_id(undef, undef, undef, undef);
    }
    elsif ($self->db_type eq 'postgres') {
        # PostgreSQL: requires table and column parameters
        $id = $self->dbh->last_insert_id(undef, undef, $table, $column);
    }
    else {
        die "Unsupported database type for last_insert_id: " . $self->db_type;
    }
    
    # Ensure we return a positive integer
    return $id && $id > 0 ? $id : undef;
}

sub _get_table_name {
    my ($self, $table) = @_;
    
    # Handle the users/user table name difference
    # SQLite uses 'user' for legacy compatibility
    # PostgreSQL uses 'users' for modern convention
    if ($table eq 'users' || $table eq 'user') {
        return $self->db_type eq 'sqlite' ? 'user' : 'users';
    }
    
    # For other tables, return as-is
    return $table;
}

sub _log_error {
    my ($self, $error_message, $context) = @_;
    
    # Start with the error message
    my $log_output = "Database Error: $error_message\n";
    
    # Add database type
    $log_output .= "  Database Type: " . $self->db_type . "\n";
    
    # Add SQL statement if available
    if ($context && $context->{sql}) {
        $log_output .= "  SQL Statement: " . $context->{sql} . "\n";
    }
    
    # Add bind parameters if available
    if ($context && $context->{bind_params}) {
        my $params = $context->{bind_params};
        if (ref($params) eq 'ARRAY' && @$params) {
            $log_output .= "  Bind Parameters: [" . join(", ", map { defined $_ ? "'$_'" : 'undef' } @$params) . "]\n";
        }
    }
    
    # Add any additional context information
    if ($context) {
        foreach my $key (keys %$context) {
            next if $key eq 'sql' || $key eq 'bind_params';  # Already handled
            my $value = $context->{$key};
            if (defined $value) {
                $log_output .= "  " . ucfirst($key) . ": $value\n";
            }
        }
    }
    
    # Log the formatted error
    warn $log_output;
    
    return;
}

sub _format_timestamp {
    my ($self, $timestamp) = @_;
    
    # If no timestamp provided, use current time
    $timestamp = time unless defined $timestamp;
    
    if ($self->db_type eq 'sqlite') {
        # SQLite: use Unix timestamp (integer)
        return int($timestamp);
    }
    elsif ($self->db_type eq 'postgres') {
        # PostgreSQL: convert Unix timestamp to TIMESTAMP format
        # If already a string (ISO format), return as-is
        if ($timestamp =~ /^\d{4}-\d{2}-\d{2}/) {
            return $timestamp;
        }
        # Convert Unix timestamp to ISO 8601 format
        my ($sec, $min, $hour, $mday, $mon, $year) = gmtime($timestamp);
        return sprintf("%04d-%02d-%02d %02d:%02d:%02d",
            $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
    }
    else {
        die "Unsupported database type for timestamp formatting: " . $self->db_type;
    }
}

sub _parse_timestamp {
    my ($self, $timestamp) = @_;
    
    return unless defined $timestamp;
    
    if ($self->db_type eq 'sqlite') {
        # SQLite: already Unix timestamp (integer)
        return int($timestamp);
    }
    elsif ($self->db_type eq 'postgres') {
        # PostgreSQL: convert TIMESTAMP to Unix timestamp
        # If already a Unix timestamp (integer), return as-is
        if ($timestamp =~ /^\d+$/) {
            return int($timestamp);
        }
        # Parse ISO 8601 format to Unix timestamp
        if ($timestamp =~ /^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})/) {
            require Time::Local;
            my ($year, $mon, $mday, $hour, $min, $sec) = ($1, $2, $3, $4, $5, $6);
            return Time::Local::timegm($sec, $min, $hour, $mday, $mon - 1, $year);
        }
        # Return as-is if we can't parse
        return $timestamp;
    }
    else {
        die "Unsupported database type for timestamp parsing: " . $self->db_type;
    }
}

sub new_user {
   my ($self, $opts) = @_;
   
   # Use helper method to get correct table name for database type
   my $table_name = $self->_get_table_name('users');
   
   # Format timestamp for database insertion
   # Store current time for both reg_date and last_visit
   my $current_time = time;
   $opts->{reg_date} = $self->_format_timestamp($current_time) if exists $opts->{reg_date} || !defined $opts->{reg_date};
   $opts->{last_visit} = $self->_format_timestamp($current_time) if exists $opts->{last_visit} || !defined $opts->{last_visit};
   
   my ( $stmt, @bind ) = $self->sql->insert( $table_name, $opts );
   
   eval {
       my $sth = $self->dbh->prepare($stmt);
       $sth->execute(@bind);
       
       # Use abstracted last_insert_id helper
       $opts->{id} = $self->_get_last_insert_id($table_name, 'id');
   };
   
   if ($@ || $self->dbh->err) {
       $self->_log_error(
           "Failed to create new user",
           {
               sql => $stmt,
               bind_params => \@bind,
               error => $@ || $self->dbh->errstr,
               table => $table_name,
           }
       );
       return;
   }
   
   # Set user object attributes with Unix timestamp for consistency
   $opts->{reg_date} = $current_time;
   $opts->{last_visit} = $current_time;
   $opts->{level}    = 2;
   $opts->{handle}   = $opts->{username} if $opts->{username};
   $opts->{bookmark} = hmac_sha1_hex( $opts->{id}, $self->secret );
   
   my $user = FB::User->new(%$opts);
   return $user;
}

sub fetch_user {
    my ( $self, $opts ) = @_;
    
    # Use helper method to get correct table name for database type
    my $table_name = $self->_get_table_name('users');
    
    my ( $stmt, @bind ) = $self->sql->select( $table_name, '*', $opts );
    
    my $href;
    eval {
        my $sth = $self->dbh->prepare($stmt);
        $sth->execute(@bind);
        $href = $sth->fetchrow_hashref;
    };
    
    if ($@ || $self->dbh->err) {
        $self->_log_error(
            "Failed to fetch user",
            {
                sql => $stmt,
                bind_params => \@bind,
                error => $@ || $self->dbh->errstr,
            }
        );
        return;
    }
    
    return unless $href && $href->{id};
    
    # Parse timestamps to Unix format for consistency in application
    $href->{reg_date} = $self->_parse_timestamp($href->{reg_date}) if defined $href->{reg_date};
    $href->{last_visit} = $self->_parse_timestamp($href->{last_visit}) if defined $href->{last_visit};
    $href->{facebook_deleted} = $self->_parse_timestamp($href->{facebook_deleted}) if defined $href->{facebook_deleted};
    
    $href->{user_id} = $href->{id};
    return FB::User->new(%$href);
}

sub update_user {
    my ( $self, $opts, $id ) = @_;
    
    # Use helper method to get correct table name for database type
    my $table_name = $self->_get_table_name('users');
    
    # Format last_visit timestamp for database
    $opts->{last_visit} = $self->_format_timestamp(time);
    
    # Format any other timestamp fields if present
    $opts->{reg_date} = $self->_format_timestamp($opts->{reg_date}) if exists $opts->{reg_date} && defined $opts->{reg_date};
    $opts->{facebook_deleted} = $self->_format_timestamp($opts->{facebook_deleted}) if exists $opts->{facebook_deleted} && defined $opts->{facebook_deleted};
    
    my ( $stmt, @bind ) =
      $self->sql->update( $table_name, $opts, { id => $id } );
    
    eval {
        my $sth = $self->dbh->prepare($stmt);
        $sth->execute(@bind);
    };
    
    if ($@ || $self->dbh->err) {
        $self->_log_error(
            "Failed to update user",
            {
                sql => $stmt,
                bind_params => \@bind,
                error => $@ || $self->dbh->errstr,
                user_id => $id,
            }
        );
        return;
    }
    
    return 1;
}

sub fetch_leaders {
    my $self = shift;
    my $table_name = $self->_get_table_name('users');
    my $sql  = <<SQL;
SELECT username, ROUND((chips - invested)*1.00 / NULLIF(invested, 0), 2) * 100 AS profit, chips
FROM $table_name
WHERE id != 1 
ORDER BY profit DESC
LIMIT 20
SQL
    my $ary_ref = $self->dbh->selectall_arrayref($sql);
    return $ary_ref;
}

sub reset_leaders {
    my $self = shift;
    my $table_name = $self->_get_table_name('users');

    my $sql = <<SQL;
UPDATE $table_name 
SET chips = 400, invested = 400 
SQL
    return $self->dbh->do($sql);

}

sub debit_chips {
    my ( $self, $user_id, $chips ) = @_;
    my $table_name = $self->_get_table_name('users');
    my $sql = <<SQL;
UPDATE $table_name 
SET chips = chips - $chips 
WHERE id = $user_id
SQL
    
    my $result = eval {
        $self->dbh->do($sql);
    };
    
    if ($@ || $self->dbh->err) {
        $self->_log_error(
            "Failed to debit chips",
            {
                sql => $sql,
                error => $@ || $self->dbh->errstr,
                user_id => $user_id,
                chips => $chips,
            }
        );
        return;
    }
    
    return $result;
}

sub credit_chips {
    my ( $self, $user_id, $chips ) = @_;
    my $table_name = $self->_get_table_name('users');
    my $sql = <<SQL;
UPDATE $table_name 
SET chips = chips + $chips 
WHERE id = $user_id 
SQL
    
    my $result = eval {
        $self->dbh->do($sql);
    };
    
    if ($@ || $self->dbh->err) {
        $self->_log_error(
            "Failed to credit chips",
            {
                sql => $sql,
                error => $@ || $self->dbh->errstr,
                user_id => $user_id,
                chips => $chips,
            }
        );
        return;
    }
    
    return $result;
}

sub fetch_chips {
    my ( $self, $user_id ) = @_;
    my $table_name = $self->_get_table_name('users');
    my $sql = <<SQL;
SELECT chips 
FROM $table_name 
WHERE id = ?
SQL

    my $chips;
    eval {
        my $sth = $self->dbh->prepare($sql);
        $sth->execute( $user_id );
        $chips = $sth->fetchrow_array || 0;
    };
    
    if ($@ || $self->dbh->err) {
        $self->_log_error(
            "Failed to fetch chips",
            {
                sql => $sql,
                bind_params => [$user_id],
                error => $@ || $self->dbh->errstr,
                user_id => $user_id,
            }
        );
        return 0;
    }
    
    return $chips;
}

sub credit_invested {
    my ( $self, $user_id, $chips ) = @_;
    my $table_name = $self->_get_table_name('users');
    my $sql = <<SQL;
UPDATE $table_name 
SET invested = invested + $chips
WHERE id = $user_id 
SQL
    
    my $result = eval {
        $self->dbh->do($sql);
    };
    
    if ($@ || $self->dbh->err) {
        $self->_log_error(
            "Failed to credit invested",
            {
                sql => $sql,
                error => $@ || $self->dbh->errstr,
                user_id => $user_id,
                chips => $chips,
            }
        );
        return;
    }
    
    return $result;
}

sub begin_transaction {
    my $self = shift;
    
    # Check if AutoCommit is enabled (required for transactions)
    unless ($self->dbh->{AutoCommit}) {
        warn "Transaction already in progress\n";
        return;
    }
    
    # Begin transaction by disabling AutoCommit
    eval {
        $self->dbh->{AutoCommit} = 0;
        $self->dbh->{RaiseError} = 1;
    };
    
    if ($@) {
        $self->_log_error(
            "Failed to begin transaction",
            {
                error => $@,
            }
        );
        return;
    }
    
    return 1;
}

sub commit_transaction {
    my $self = shift;
    
    # Check if we're in a transaction
    if ($self->dbh->{AutoCommit}) {
        warn "No transaction in progress to commit\n";
        return;
    }
    
    # Commit the transaction
    eval {
        $self->dbh->commit;
        $self->dbh->{AutoCommit} = 1;
    };
    
    if ($@) {
        $self->_log_error(
            "Failed to commit transaction",
            {
                error => $@,
            }
        );
        # Try to rollback on commit failure
        eval { $self->dbh->rollback; };
        $self->dbh->{AutoCommit} = 1;
        return;
    }
    
    return 1;
}

sub rollback_transaction {
    my $self = shift;
    
    # Check if we're in a transaction
    if ($self->dbh->{AutoCommit}) {
        warn "No transaction in progress to rollback\n";
        return;
    }
    
    # Rollback the transaction
    eval {
        $self->dbh->rollback;
        $self->dbh->{AutoCommit} = 1;
    };
    
    if ($@) {
        $self->_log_error(
            "Failed to rollback transaction",
            {
                error => $@,
            }
        );
        # Force AutoCommit back on even if rollback fails
        $self->dbh->{AutoCommit} = 1;
        return;
    }
    
    return 1;
}

1;