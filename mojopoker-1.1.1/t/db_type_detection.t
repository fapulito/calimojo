#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Temp;
use lib 'lib';

# Test database type detection and configuration
# Requirements: 1.1, 1.2, 2.1

# We'll test the db_type attribute without triggering dbh creation
# by accessing the attribute directly after object construction

# Test 1: Default to sqlite when DATABASE_TYPE is not set
{
    local $ENV{DATABASE_TYPE} = undef;
    delete $ENV{DATABASE_TYPE};
    
    require FB::Db;
    # Create object without triggering dbh builder by passing dbh explicitly
    my $db = FB::Db->new(dbh => undef);
    is($db->db_type, 'sqlite', 'Defaults to sqlite when DATABASE_TYPE is not set');
}

# Test 2: Use sqlite when DATABASE_TYPE is set to 'sqlite'
{
    local $ENV{DATABASE_TYPE} = 'sqlite';
    
    require FB::Db;
    my $db = FB::Db->new(dbh => undef);
    is($db->db_type, 'sqlite', 'Uses sqlite when DATABASE_TYPE is "sqlite"');
}

# Test 3: Use postgres when DATABASE_TYPE is set to 'postgres'
{
    local $ENV{DATABASE_TYPE} = 'postgres';
    
    require FB::Db;
    my $db = FB::Db->new(dbh => undef);
    is($db->db_type, 'postgres', 'Uses postgres when DATABASE_TYPE is "postgres"');
}

# Test 4: Normalize 'postgresql' to 'postgres'
{
    local $ENV{DATABASE_TYPE} = 'postgresql';
    
    require FB::Db;
    my $db = FB::Db->new(dbh => undef);
    is($db->db_type, 'postgres', 'Normalizes "postgresql" to "postgres"');
}

# Test 5: Reject unsupported database types
{
    local $ENV{DATABASE_TYPE} = 'mysql';
    
    eval {
        require FB::Db;
        my $db = FB::Db->new(dbh => undef);
    };
    
    like($@, qr/Unsupported DATABASE_TYPE: mysql/, 'Rejects unsupported database type "mysql"');
}

# Test 6: Reject invalid database types
{
    local $ENV{DATABASE_TYPE} = 'invalid';
    
    eval {
        require FB::Db;
        my $db = FB::Db->new(dbh => undef);
    };
    
    like($@, qr/Unsupported DATABASE_TYPE: invalid/, 'Rejects invalid database type');
}

done_testing();
