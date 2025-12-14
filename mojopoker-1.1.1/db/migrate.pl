#!/usr/bin/env perl

use strict;
use warnings;
use feature qw(say);
use DBI;
use Data::Dumper;
use Getopt::Long;

# Database Migration Script
# Migrates data from SQLite to PostgreSQL

my $config = {
    sqlite_path => $ENV{SQLITE_PATH} || '/opt/mojopoker/db',
    postgres_url => $ENV{DATABASE_URL},
    verbose => 0,
    dry_run => 0,
    help => 0
};

GetOptions(
    'sqlite-path=s' => \$config->{sqlite_path},
    'postgres-url=s' => \$config->{postgres_url},
    'verbose' => \$config->{verbose},
    'dry-run' => \$config->{dry_run},
    'help' => \$config->{help}
) or die "Invalid options\n";

show_help() if $config->{help};

unless ($config->{postgres_url}) {
    die "PostgreSQL URL is required. Set DATABASE_URL environment variable or use --postgres-url option.\n";
}

# Connect to SQLite database
my $sqlite_db = connect_sqlite();
unless ($sqlite_db) {
    die "Failed to connect to SQLite database\n";
}

# Connect to PostgreSQL database
my $postgres_db = connect_postgres();
unless ($postgres_db) {
    die "Failed to connect to PostgreSQL database\n";
}

print "Starting database migration...\n";

# Migrate users
migrate_users($sqlite_db, $postgres_db);

# Migrate other tables as needed
# migrate_tables($sqlite_db, $postgres_db);
# migrate_chat($sqlite_db, $postgres_db);
# migrate_leaderboard($sqlite_db, $postgres_db);

print "Database migration completed successfully!\n";

sub connect_sqlite {
    my $db_path = "$config->{sqlite_path}/poker.db";
    print "Connecting to SQLite database at $db_path...\n" if $config->{verbose};

    my $dbh = DBI->connect("dbi:SQLite:dbname=$db_path", "", "", {
        RaiseError => 1,
        AutoCommit => 1,
    }) or die "Cannot connect to SQLite database: $DBI::errstr";

    return $dbh;
}

sub connect_postgres {
    print "Connecting to PostgreSQL database...\n" if $config->{verbose};

    my $dbh = DBI->connect($config->{postgres_url}, "", "", {
        RaiseError => 1,
        AutoCommit => 0,  # Disable AutoCommit for proper transaction control
        pg_enable_utf8 => 1,
    }) or die "Cannot connect to PostgreSQL database: $DBI::errstr";

    return $dbh;
}

sub migrate_users {
    my ($sqlite_db, $postgres_db) = @_;

    print "Migrating users...\n" if $config->{verbose};

    # Get users from SQLite
    my $users = $sqlite_db->selectall_arrayref("SELECT * FROM user", { Slice => {} });

    unless (@$users) {
        print "No users found in SQLite database\n";
        return;
    }

    print "Found " . scalar(@$users) . " users to migrate\n" if $config->{verbose};

    return if $config->{dry_run};

    # Start PostgreSQL transaction
    eval {
        # Begin transaction
        $postgres_db->begin_work;

        # Prepare PostgreSQL insert statement with COALESCE for timestamp handling
        my $insert_stmt = $postgres_db->prepare(<<'END_SQL');
INSERT INTO users (
    id, facebook_id, username, password, email, birthday, handle,
    first_name, last_name, profile_pic, chips, invested, level,
    last_visit, created_at, updated_at
) VALUES (
    ?, ?, ?, ?, ?, ?, ?,
    ?, ?, ?, ?, ?, ?,
    COALESCE(?, CURRENT_TIMESTAMP),
    COALESCE(?, CURRENT_TIMESTAMP),
    COALESCE(?, CURRENT_TIMESTAMP)
)
ON CONFLICT (id) DO UPDATE SET
    facebook_id = EXCLUDED.facebook_id,
    username = EXCLUDED.username,
    password = EXCLUDED.password,
    email = EXCLUDED.email,
    birthday = EXCLUDED.birthday,
    handle = EXCLUDED.handle,
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    profile_pic = EXCLUDED.profile_pic,
    chips = EXCLUDED.chips,
    invested = EXCLUDED.invested,
    level = EXCLUDED.level,
    last_visit = EXCLUDED.last_visit,
    updated_at = CURRENT_TIMESTAMP
END_SQL

        # Migrate each user within the transaction
        foreach my $user (@$users) {
            # Use undef for NULL values - let PostgreSQL handle defaults
            # The INSERT statement will use COALESCE to handle NULL timestamps
            my $last_visit = $user->{last_visit};
            my $created_at = $user->{created_at};
            my $updated_at = $user->{updated_at};

            $insert_stmt->execute(
                $user->{id}, $user->{facebook_id}, $user->{username},
                $user->{password}, $user->{email}, $user->{birthday},
                $user->{handle}, $user->{first_name}, $user->{last_name},
                $user->{profile_pic}, $user->{chips}, $user->{invested},
                $user->{level}, $last_visit, $created_at, $updated_at
            );

            print "Migrated user: $user->{username} (ID: $user->{id})\n" if $config->{verbose};
        }

        # Commit transaction if all inserts succeed
        $postgres_db->commit;
        print "Users migration completed successfully within transaction\n";
    };

    # Handle any errors and rollback transaction
    if ($@) {
        warn "Error during user migration: $@";
        eval { $postgres_db->rollback };
        die "User migration failed. Transaction has been rolled back.\n";
    }
}

sub show_help {
    print <<'END_HELP';
Database Migration Script
Usage: perl migrate.pl [options]

Options:
  --sqlite-path    Path to SQLite database directory (default: /opt/mojopoker/db)
  --postgres-url   PostgreSQL connection URL (default: DATABASE_URL env var)
  --verbose        Show detailed migration information
  --dry-run        Test migration without actually writing to PostgreSQL
  --help           Show this help message

Environment Variables:
  SQLITE_PATH      Path to SQLite database directory
  DATABASE_URL     PostgreSQL connection URL

Example:
  DATABASE_URL="postgresql://user:password@localhost:5432/mojopoker" perl migrate.pl --verbose
END_HELP

    exit 0;
}