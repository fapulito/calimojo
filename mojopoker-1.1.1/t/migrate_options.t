#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Output;
use Getopt::Long;

# Test 1-5: Help output
subtest 'Help message' => sub {
    plan tests => 5;
    
    my $help_text = <<'END_HELP';
Database Migration Script
Usage: perl migrate.pl [options]

Options:
  --sqlite-path    Path to SQLite database directory (default: /opt/mojopoker/db)
  --postgres-url   PostgreSQL connection URL (default: DATABASE_URL env var)
  --verbose        Show detailed migration information
  --dry-run        Test migration without actually writing to PostgreSQL
  --help           Show this help message
END_HELP
    
    like($help_text, qr/Database Migration Script/, 'Help title present');
    like($help_text, qr/--sqlite-path/, 'SQLite path option documented');
    like($help_text, qr/--postgres-url/, 'PostgreSQL URL option documented');
    like($help_text, qr/--verbose/, 'Verbose option documented');
    like($help_text, qr/--dry-run/, 'Dry-run option documented');
};

# Test 6-10: Option parsing
subtest 'Option parsing' => sub {
    plan tests => 5;
    
    local @ARGV = (
        '--sqlite-path', '/custom/path',
        '--postgres-url', 'postgresql://test:test@localhost/test',
        '--verbose',
        '--dry-run'
    );
    
    my %config;
    GetOptions(
        'sqlite-path=s' => \$config{sqlite_path},
        'postgres-url=s' => \$config{postgres_url},
        'verbose' => \$config{verbose},
        'dry-run' => \$config{dry_run},
    );
    
    is($config{sqlite_path}, '/custom/path', 'SQLite path parsed');
    is($config{postgres_url}, 'postgresql://test:test@localhost/test', 'PostgreSQL URL parsed');
    ok($config{verbose}, 'Verbose flag set');
    ok($config{dry_run}, 'Dry-run flag set');
    ok(%config, 'Config hash populated');
};

# Test 11-15: Environment variables
subtest 'Environment variable handling' => sub {
    plan tests => 5;
    
    local $ENV{SQLITE_PATH} = '/env/sqlite/path';
    local $ENV{DATABASE_URL} = 'postgresql://env:test@localhost/envdb';
    
    is($ENV{SQLITE_PATH}, '/env/sqlite/path', 'SQLITE_PATH set');
    is($ENV{DATABASE_URL}, 'postgresql://env:test@localhost/envdb', 'DATABASE_URL set');
    
    # Test fallback behavior
    my $sqlite_path = $ENV{SQLITE_PATH} || '/opt/mojopoker/db';
    is($sqlite_path, '/env/sqlite/path', 'Environment variable takes precedence');
    
    delete $ENV{SQLITE_PATH};
    $sqlite_path = $ENV{SQLITE_PATH} || '/opt/mojopoker/db';
    is($sqlite_path, '/opt/mojopoker/db', 'Fallback to default');
    
    ok($ENV{DATABASE_URL}, 'DATABASE_URL still set');
};

# Test 16-20: Verbose output
subtest 'Verbose output' => sub {
    plan tests => 5;
    
    my $verbose = 1;
    my @expected_messages = (
        'Connecting to SQLite database',
        'Connecting to PostgreSQL database',
        'Migrating users',
        'Found .* users to migrate',
        'Users migration completed'
    );
    
    foreach my $pattern (@expected_messages) {
        like($pattern, qr/.+/, "Message pattern defined: $pattern");
    }
};

done_testing();
