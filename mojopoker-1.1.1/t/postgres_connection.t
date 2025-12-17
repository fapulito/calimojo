#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use lib 'lib';

# Test PostgreSQL connection error handling and DATABASE_URL parsing

# Test 1: Missing required environment variables
{
    local $ENV{DATABASE_TYPE} = 'postgres';
    delete $ENV{DATABASE_URL};
    delete $ENV{DB_HOST};
    delete $ENV{DB_USER};
    delete $ENV{DB_PASSWORD};
    
    eval {
        require FB::Db;
        my $db = FB::Db->new();
    };
    
    ok($@, 'Dies when required PostgreSQL env vars are missing');
    like($@, qr/Missing required environment variables/, 'Error message mentions missing variables');
    like($@, qr/DB_HOST/, 'Error message lists DB_HOST');
    like($@, qr/DB_USER/, 'Error message lists DB_USER');
    like($@, qr/DB_PASSWORD/, 'Error message lists DB_PASSWORD');
}

# Test 2: Partial missing variables
{
    local $ENV{DATABASE_TYPE} = 'postgres';
    delete $ENV{DATABASE_URL};
    $ENV{DB_HOST} = 'localhost';
    delete $ENV{DB_USER};
    delete $ENV{DB_PASSWORD};
    
    eval {
        require FB::Db;
        my $db = FB::Db->new();
    };
    
    ok($@, 'Dies when some PostgreSQL env vars are missing');
    like($@, qr/DB_USER/, 'Error message lists missing DB_USER');
    like($@, qr/DB_PASSWORD/, 'Error message lists missing DB_PASSWORD');
    # Verify only the missing variables are listed (not DB_HOST which was provided)
    my $missing_section = ($@ =~ /Missing required environment variables:\n(.*?)\n(?:Either|$)/s) ? $1 : '';
    unlike($missing_section, qr/DB_HOST/, 'Missing variables section does not include provided DB_HOST');
}

# Test 3: DATABASE_URL parsing (valid format)
{
    local $ENV{DATABASE_TYPE} = 'postgres';
    $ENV{DATABASE_URL} = 'postgresql://testuser:testpass@testhost:5433/testdb?sslmode=disable';
    delete $ENV{DB_HOST};
    delete $ENV{DB_USER};
    delete $ENV{DB_PASSWORD};
    
    # We can't actually connect, but we can verify the parsing doesn't die immediately
    eval {
        require FB::Db;
        my $db = FB::Db->new();
    };
    
    # Should fail on connection, not on parsing
    ok($@, 'Dies when connection fails');
    like($@, qr/PostgreSQL connection failed/, 'Error message indicates connection failure');
    like($@, qr/Host: testhost/, 'Error includes parsed host');
    like($@, qr/Port: 5433/, 'Error includes parsed port');
    like($@, qr/Database: testdb/, 'Error includes parsed database');
    like($@, qr/SSL Mode: disable/, 'Error includes parsed SSL mode');
}

# Test 4: DATABASE_URL parsing (postgres:// prefix)
{
    local $ENV{DATABASE_TYPE} = 'postgres';
    $ENV{DATABASE_URL} = 'postgres://user2:pass2@host2:5432/db2';
    delete $ENV{DB_HOST};
    delete $ENV{DB_USER};
    delete $ENV{DB_PASSWORD};
    
    eval {
        require FB::Db;
        my $db = FB::Db->new();
    };
    
    ok($@, 'Dies when connection fails with postgres:// prefix');
    like($@, qr/Host: host2/, 'Parses postgres:// prefix correctly');
}

# Test 5: DATABASE_URL with default port
{
    local $ENV{DATABASE_TYPE} = 'postgres';
    $ENV{DATABASE_URL} = 'postgresql://user3:pass3@host3/db3';
    delete $ENV{DB_HOST};
    delete $ENV{DB_USER};
    delete $ENV{DB_PASSWORD};
    
    eval {
        require FB::Db;
        my $db = FB::Db->new();
    };
    
    ok($@, 'Dies when connection fails without explicit port');
    like($@, qr/Port: 5432/, 'Uses default port 5432 when not specified');
}

# Test 6: Invalid DATABASE_URL format
{
    local $ENV{DATABASE_TYPE} = 'postgres';
    $ENV{DATABASE_URL} = 'invalid-url-format';
    delete $ENV{DB_HOST};
    delete $ENV{DB_USER};
    delete $ENV{DB_PASSWORD};
    
    eval {
        require FB::Db;
        my $db = FB::Db->new();
    };
    
    ok($@, 'Dies with invalid DATABASE_URL format');
    like($@, qr/DATABASE_URL format invalid/, 'Error message indicates invalid format');
}

# Test 7: Backward compatibility - DB_* variables still work
{
    local $ENV{DATABASE_TYPE} = 'postgres';
    delete $ENV{DATABASE_URL};
    $ENV{DB_HOST} = 'backcompat-host';
    $ENV{DB_USER} = 'backcompat-user';
    $ENV{DB_PASSWORD} = 'backcompat-pass';
    $ENV{DB_PORT} = 5434;
    $ENV{DB_NAME} = 'backcompat-db';
    $ENV{DB_SSLMODE} = 'prefer';
    
    eval {
        require FB::Db;
        my $db = FB::Db->new();
    };
    
    ok($@, 'Dies when connection fails with DB_* variables');
    like($@, qr/Host: backcompat-host/, 'Uses DB_HOST');
    like($@, qr/Port: 5434/, 'Uses DB_PORT');
    like($@, qr/Database: backcompat-db/, 'Uses DB_NAME');
    like($@, qr/SSL Mode: prefer/, 'Uses DB_SSLMODE');
}

done_testing();
