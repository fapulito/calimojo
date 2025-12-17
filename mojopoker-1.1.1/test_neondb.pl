#!/usr/bin/env perl
use strict;
use warnings;
use lib './lib';
use FB::Db;

print "Testing NeonDB connection...\n";

my $db = FB::Db->new;
print "Driver: " . $db->dbh->{Driver}{Name} . "\n";

# Test fetch_chips for user 2 (testuser)
my $chips = $db->fetch_chips(2);
print "User 2 chips: $chips\n";

# Test fetch_user
my $user = $db->fetch_user({ username => 'testuser' });
if ($user) {
    print "Found user: id=" . $user->id . " username=" . ($user->username || 'null') . " chips=" . $user->chips . "\n";
} else {
    print "User not found!\n";
}

# Test fetch_user by bookmark
my $user2 = $db->fetch_user({ bookmark => 'test123' });
if ($user2) {
    print "Found by bookmark: id=" . $user2->id . " chips=" . $user2->chips . "\n";
} else {
    print "User not found by bookmark!\n";
}

print "Done.\n";
