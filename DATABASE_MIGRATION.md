# Database Migration Guide

This guide provides step-by-step instructions for migrating your Mojo Poker database between SQLite and PostgreSQL.

## Table of Contents

- [Prerequisites](#prerequisites)
- [SQLite to PostgreSQL Migration](#sqlite-to-postgresql-migration)
- [PostgreSQL to SQLite Migration](#postgresql-to-sqlite-migration)
- [Verification Steps](#verification-steps)
- [Rollback Procedures](#rollback-procedures)
- [Common Issues](#common-issues)

## Prerequisites

Before starting any migration, ensure you have:

1. **Backup of your current database**
   ```bash
   # SQLite backup
   cp db/fb.db db/fb.db.backup
   cp db/poker.db db/poker.db.backup
   
   # PostgreSQL backup
   pg_dump $DATABASE_URL > backup_$(date +%Y%m%d_%H%M%S).sql
   ```

2. **Required tools installed**
   - `sqlite3` command-line tool
   - `psql` PostgreSQL client
   - Perl DBI modules: `DBD::SQLite` and `DBD::Pg`

3. **Target database configured**
   - For PostgreSQL: Have your DATABASE_URL or DB_* credentials ready
   - For SQLite: Ensure the target directory exists and is writable

4. **Application stopped**
   ```bash
   # Stop the Perl server
   pkill -f mojopoker.pl
   ```

## SQLite to PostgreSQL Migration

This migration is typically done when moving from local development to production.

### Step 1: Export SQLite Data

```bash
cd mojopoker-1.1.1/db

# Export the fb database
sqlite3 fb.db .dump > fb_export.sql

# Export the poker database (if used)
sqlite3 poker.db .dump > poker_export.sql
```

### Step 2: Prepare PostgreSQL Database

```bash
# Set your PostgreSQL connection
export DATABASE_URL="postgresql://user:pass@host:5432/dbname?sslmode=require"

# Create the schema
psql $DATABASE_URL -f postgres.schema

# Verify tables were created
psql $DATABASE_URL -c "\dt"
```

### Step 3: Transform SQLite Export

SQLite and PostgreSQL have different SQL dialects. You need to transform the export:

```bash
# Create a transformation script
cat > transform_sqlite_to_postgres.sh << 'EOF'
#!/bin/bash

INPUT_FILE=$1
OUTPUT_FILE=$2

# Remove SQLite-specific commands
sed -e '/^BEGIN TRANSACTION;/d' \
    -e '/^COMMIT;/d' \
    -e '/^PRAGMA/d' \
    -e '/^CREATE TABLE sqlite_sequence/,/);/d' \
    -e '/^DELETE FROM sqlite_sequence;/d' \
    -e '/^INSERT INTO sqlite_sequence/d' \
    $INPUT_FILE > $OUTPUT_FILE

# Convert table names
sed -i 's/CREATE TABLE "user"/CREATE TABLE "users"/g' $OUTPUT_FILE
sed -i 's/INSERT INTO "user"/INSERT INTO "users"/g' $OUTPUT_FILE

# Convert AUTOINCREMENT to SERIAL (if needed)
sed -i 's/INTEGER PRIMARY KEY AUTOINCREMENT/SERIAL PRIMARY KEY/g' $OUTPUT_FILE

# Convert datetime to timestamp
sed -i 's/datetime/timestamp/g' $OUTPUT_FILE

echo "Transformation complete: $OUTPUT_FILE"
EOF

chmod +x transform_sqlite_to_postgres.sh

# Run the transformation
./transform_sqlite_to_postgres.sh fb_export.sql fb_postgres.sql
```

### Step 4: Import Data to PostgreSQL

```bash
# Import the transformed data
psql $DATABASE_URL -f fb_postgres.sql

# Check for errors
if [ $? -eq 0 ]; then
    echo "Import successful!"
else
    echo "Import failed. Check errors above."
    exit 1
fi
```

### Step 5: Verify Data Integrity

```bash
# Count records in SQLite
echo "SQLite user count:"
sqlite3 fb.db "SELECT COUNT(*) FROM user;"

# Count records in PostgreSQL
echo "PostgreSQL users count:"
psql $DATABASE_URL -c "SELECT COUNT(*) FROM users;"

# Compare specific records
echo "Sample user from SQLite:"
sqlite3 fb.db "SELECT * FROM user LIMIT 1;"

echo "Sample user from PostgreSQL:"
psql $DATABASE_URL -c "SELECT * FROM users LIMIT 1;"
```

### Step 6: Update Application Configuration

```bash
# Update .env file
cat >> .env << EOF
DATABASE_TYPE=postgres
DATABASE_URL=$DATABASE_URL
EOF

# Remove SQLite configuration (optional)
sed -i '/SQLITE_PATH/d' .env
```

### Step 7: Test the Application

```bash
cd mojopoker-1.1.1

# Test database connection
perl -Ilib -MFB::Db -e 'my $db = FB::Db->new; print "Connected to: " . $db->db_type . "\n";'

# Run database tests
prove -v t/postgres_connection.t
prove -v t/user_persistence.t

# Start the application
perl script/mojopoker.pl daemon
```

## PostgreSQL to SQLite Migration

This migration is useful for creating local development copies from production data.

### Step 1: Export PostgreSQL Data

```bash
cd mojopoker-1.1.1/db

# Export data only (no schema)
pg_dump $DATABASE_URL --data-only --inserts > postgres_export.sql

# Or export with schema
pg_dump $DATABASE_URL > postgres_full_export.sql
```

### Step 2: Prepare SQLite Database

```bash
# Remove existing SQLite database (if any)
rm -f fb.db

# Create new database with schema
sqlite3 fb.db < fb.schema

# Verify schema
sqlite3 fb.db ".schema"
```

### Step 3: Transform PostgreSQL Export

```bash
# Create transformation script
cat > transform_postgres_to_sqlite.sh << 'EOF'
#!/bin/bash

INPUT_FILE=$1
OUTPUT_FILE=$2

# Remove PostgreSQL-specific commands
sed -e '/^SET /d' \
    -e '/^SELECT pg_catalog/d' \
    -e '/^ALTER TABLE.*OWNER TO/d' \
    -e '/^COMMENT ON/d' \
    -e '/^CREATE SEQUENCE/d' \
    -e '/^ALTER SEQUENCE/d' \
    -e '/^SELECT setval/d' \
    $INPUT_FILE > $OUTPUT_FILE

# Convert table names
sed -i 's/INSERT INTO users/INSERT INTO user/g' $OUTPUT_FILE
sed -i 's/INSERT INTO "users"/INSERT INTO "user"/g' $OUTPUT_FILE

# Remove schema qualifiers
sed -i 's/public\.//g' $OUTPUT_FILE

# Convert boolean values
sed -i "s/'t'/1/g" $OUTPUT_FILE
sed -i "s/'f'/0/g" $OUTPUT_FILE

# Convert timestamp format (if needed)
sed -i "s/timestamp without time zone/datetime/g" $OUTPUT_FILE

echo "Transformation complete: $OUTPUT_FILE"
EOF

chmod +x transform_postgres_to_sqlite.sh

# Run transformation
./transform_postgres_to_sqlite.sh postgres_export.sql sqlite_import.sql
```

### Step 4: Import Data to SQLite

```bash
# Import the data
sqlite3 fb.db < sqlite_import.sql

# Check for errors
if [ $? -eq 0 ]; then
    echo "Import successful!"
else
    echo "Import failed. Check errors above."
    exit 1
fi
```

### Step 5: Verify Data Integrity

```bash
# Count records in PostgreSQL
echo "PostgreSQL users count:"
psql $DATABASE_URL -c "SELECT COUNT(*) FROM users;"

# Count records in SQLite
echo "SQLite user count:"
sqlite3 fb.db "SELECT COUNT(*) FROM user;"

# Compare specific records
echo "Sample user from PostgreSQL:"
psql $DATABASE_URL -c "SELECT * FROM users LIMIT 1;"

echo "Sample user from SQLite:"
sqlite3 fb.db "SELECT * FROM user LIMIT 1;"
```

### Step 6: Update Application Configuration

```bash
# Update .env file
cat > .env << EOF
DATABASE_TYPE=sqlite
SQLITE_PATH=./db
EOF
```

### Step 7: Test the Application

```bash
cd mojopoker-1.1.1

# Test database connection
perl -Ilib -MFB::Db -e 'my $db = FB::Db->new; print "Connected to: " . $db->db_type . "\n";'

# Run database tests
prove -v t/sqlite_connection.t
prove -v t/user_persistence.t

# Start the application
perl script/mojopoker.pl daemon
```

## Verification Steps

After any migration, perform these verification steps:

### 1. Record Count Verification

```bash
# Create verification script
cat > verify_migration.sh << 'EOF'
#!/bin/bash

echo "=== Migration Verification ==="
echo ""

# Check user count
echo "User count:"
if [ "$DATABASE_TYPE" = "sqlite" ]; then
    sqlite3 db/fb.db "SELECT COUNT(*) FROM user;"
else
    psql $DATABASE_URL -t -c "SELECT COUNT(*) FROM users;"
fi

# Check for recent activity
echo ""
echo "Recent logins:"
if [ "$DATABASE_TYPE" = "sqlite" ]; then
    sqlite3 db/fb.db "SELECT login, last_login FROM user ORDER BY last_login DESC LIMIT 5;"
else
    psql $DATABASE_URL -t -c "SELECT login, last_login FROM users ORDER BY last_login DESC LIMIT 5;"
fi

# Check chip totals
echo ""
echo "Total chips in system:"
if [ "$DATABASE_TYPE" = "sqlite" ]; then
    sqlite3 db/fb.db "SELECT SUM(chips) FROM user;"
else
    psql $DATABASE_URL -t -c "SELECT SUM(chips) FROM users;"
fi

echo ""
echo "=== Verification Complete ==="
EOF

chmod +x verify_migration.sh
./verify_migration.sh
```

### 2. Application Functionality Test

```bash
# Test user creation
perl -Ilib -e '
use FB::Db;
my $db = FB::Db->new;
my $user = $db->new_user({
    login => "test_migration_" . time(),
    chips => 1000
});
print "Test user created with ID: " . $user->{id} . "\n" if $user;
'

# Test user fetch
perl -Ilib -e '
use FB::Db;
my $db = FB::Db->new;
my $user = $db->fetch_user({ id => 1 });
print "Fetched user: " . $user->{login} . "\n" if $user;
'
```

### 3. Run Full Test Suite

```bash
cd mojopoker-1.1.1
prove -v t/
```

## Rollback Procedures

If the migration fails or causes issues, follow these rollback steps:

### Rollback from PostgreSQL to SQLite

```bash
# Stop the application
pkill -f mojopoker.pl

# Restore SQLite backup
cp db/fb.db.backup db/fb.db
cp db/poker.db.backup db/poker.db

# Update .env
cat > .env << EOF
DATABASE_TYPE=sqlite
SQLITE_PATH=./db
EOF

# Restart application
cd mojopoker-1.1.1
perl script/mojopoker.pl daemon
```

### Rollback from SQLite to PostgreSQL

```bash
# Stop the application
pkill -f mojopoker.pl

# Restore PostgreSQL backup
psql $DATABASE_URL < backup_YYYYMMDD_HHMMSS.sql

# Update .env
cat > .env << EOF
DATABASE_TYPE=postgres
DATABASE_URL=$DATABASE_URL
EOF

# Restart application
cd mojopoker-1.1.1
perl script/mojopoker.pl daemon
```

## Common Issues

### Issue: Character Encoding Problems

**Symptoms:** Special characters appear as � or garbled text

**Solution:**
```bash
# For PostgreSQL import
psql $DATABASE_URL -c "SET client_encoding TO 'UTF8';"
psql $DATABASE_URL -f import.sql

# For SQLite
sqlite3 fb.db "PRAGMA encoding = 'UTF-8';"
```

### Issue: Primary Key Conflicts

**Symptoms:** "duplicate key value violates unique constraint"

**Solution:**
```bash
# Reset PostgreSQL sequences
psql $DATABASE_URL << EOF
SELECT setval('users_id_seq', (SELECT MAX(id) FROM users));
SELECT setval('logins_id_seq', (SELECT MAX(id) FROM logins));
EOF
```

### Issue: Foreign Key Violations

**Symptoms:** "foreign key constraint fails"

**Solution:**
```bash
# Temporarily disable foreign keys during import
# SQLite:
sqlite3 fb.db "PRAGMA foreign_keys = OFF;"
sqlite3 fb.db < import.sql
sqlite3 fb.db "PRAGMA foreign_keys = ON;"

# PostgreSQL:
psql $DATABASE_URL -c "SET session_replication_role = replica;"
psql $DATABASE_URL -f import.sql
psql $DATABASE_URL -c "SET session_replication_role = DEFAULT;"
```

### Issue: Table Name Mismatches

**Symptoms:** "relation 'user' does not exist" or "relation 'users' does not exist"

**Solution:**
```bash
# Check which table name is used
if [ "$DATABASE_TYPE" = "sqlite" ]; then
    sqlite3 fb.db ".tables"
else
    psql $DATABASE_URL -c "\dt"
fi

# The application handles this automatically via _get_table_name()
# But ensure your schema uses the correct name:
# - SQLite: 'user' (singular)
# - PostgreSQL: 'users' (plural)
```

### Issue: Timestamp Format Differences

**Symptoms:** Invalid timestamp values or date parsing errors

**Solution:**
```bash
# Convert Unix timestamps to PostgreSQL timestamps
psql $DATABASE_URL << EOF
UPDATE users 
SET last_login = to_timestamp(CAST(last_login AS bigint))
WHERE last_login ~ '^[0-9]+$';
EOF

# Convert PostgreSQL timestamps to Unix timestamps for SQLite
# (Usually handled automatically by the application)
```

### Issue: Migration Script Hangs

**Symptoms:** Import process appears frozen

**Solution:**
```bash
# Check for locks
# SQLite:
lsof db/fb.db

# PostgreSQL:
psql $DATABASE_URL -c "SELECT * FROM pg_stat_activity WHERE datname = 'your_db_name';"

# Kill blocking processes if needed
# Then retry with smaller batches
split -l 1000 import.sql import_batch_
for file in import_batch_*; do
    psql $DATABASE_URL -f $file
done
```

## Best Practices

1. **Always backup before migration** - Cannot be stressed enough
2. **Test on a copy first** - Never migrate production data directly
3. **Verify data integrity** - Count records and spot-check critical data
4. **Plan for downtime** - Migrations can take time for large databases
5. **Document your process** - Keep notes on what worked and what didn't
6. **Test the application** - Run full test suite after migration
7. **Monitor after migration** - Watch logs for any database-related errors
8. **Keep backups** - Don't delete old backups immediately after migration

## Automated Migration Script

For convenience, here's a complete automated migration script:

```bash
#!/bin/bash
# migrate_database.sh - Automated database migration

set -e  # Exit on error

SOURCE_TYPE=$1  # sqlite or postgres
TARGET_TYPE=$2  # sqlite or postgres

if [ -z "$SOURCE_TYPE" ] || [ -z "$TARGET_TYPE" ]; then
    echo "Usage: $0 <source_type> <target_type>"
    echo "Example: $0 sqlite postgres"
    exit 1
fi

echo "=== Mojo Poker Database Migration ==="
echo "Source: $SOURCE_TYPE"
echo "Target: $TARGET_TYPE"
echo ""

# Backup
echo "Creating backup..."
if [ "$SOURCE_TYPE" = "sqlite" ]; then
    cp db/fb.db db/fb.db.backup.$(date +%Y%m%d_%H%M%S)
else
    pg_dump $DATABASE_URL > backup_$(date +%Y%m%d_%H%M%S).sql
fi

# Export
echo "Exporting data..."
if [ "$SOURCE_TYPE" = "sqlite" ]; then
    sqlite3 db/fb.db .dump > export.sql
else
    pg_dump $DATABASE_URL --data-only --inserts > export.sql
fi

# Transform
echo "Transforming data..."
if [ "$SOURCE_TYPE" = "sqlite" ] && [ "$TARGET_TYPE" = "postgres" ]; then
    ./transform_sqlite_to_postgres.sh export.sql import.sql
elif [ "$SOURCE_TYPE" = "postgres" ] && [ "$TARGET_TYPE" = "sqlite" ]; then
    ./transform_postgres_to_sqlite.sh export.sql import.sql
else
    echo "Unsupported migration path"
    exit 1
fi

# Import
echo "Importing data..."
if [ "$TARGET_TYPE" = "sqlite" ]; then
    sqlite3 db/fb.db < import.sql
else
    psql $DATABASE_URL -f import.sql
fi

# Verify
echo "Verifying migration..."
./verify_migration.sh

echo ""
echo "=== Migration Complete ==="
echo "Please test the application before removing backups."
```

## Support

If you encounter issues not covered in this guide:

1. Check the application logs: `tail -f mojopoker-1.1.1/log/development.log`
2. Run the test suite: `prove -v t/`
3. Review the troubleshooting section in README.md
4. Open an issue on GitHub with migration logs and error messages

## Additional Resources

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [SQLite Documentation](https://www.sqlite.org/docs.html)
- [DBI Perl Module](https://metacpan.org/pod/DBI)
- [NeonDB Documentation](https://neon.tech/docs)
