#!/usr/bin/env perl
use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin/lib";

# Load .env file
for my $env_path ('.env', "$RealBin/.env", "$RealBin/../.env") {
    if (-f $env_path && open my $fh, '<', $env_path) {
        while (<$fh>) {
            chomp;
            next if /^\s*#/ || /^\s*$/;
            if (/^([^=]+)=(.*)$/) {
                my ($key, $value) = ($1, $2);
                $value =~ s/^["']|["']$//g;
                $ENV{$key} = $value unless exists $ENV{$key};
            }
        }
        close $fh;
        last;
    }
}

use FB::Db;

my $db = FB::Db->new;
my $dbh = $db->dbh;

print "Adding house players...\n";

# Create 7 house players (HousePlayer1 through HousePlayer7)
# Requirements 7.1, 7.2, 7.3: Ensure at least 7 house player accounts exist,
# each with 1000000 chips, following the naming pattern HousePlayer followed by a number
for my $i (1..7) {
    my $player = "HousePlayer$i";
    my $bookmark = "house$i";
    
    # Check if player exists
    my $check = $dbh->prepare("SELECT id FROM user WHERE username = ?");
    $check->execute($player);
    my $exists = $check->fetchrow_hashref;
    
    if ($exists) {
        # Update existing player
        my $sth = $dbh->prepare("UPDATE user SET chips = 1000000 WHERE username = ?");
        $sth->execute($player);
        print "Updated: $player (chips: 1000000)\n";
    } else {
        # Insert new player
        my $sth = $dbh->prepare("INSERT INTO user (username, chips, bookmark) VALUES (?, 1000000, ?)");
        $sth->execute($player, $bookmark);
        print "Added: $player (chips: 1000000)\n";
    }
}

print "\nCurrent users:\n";
my $sth = $dbh->prepare("SELECT id, username, chips FROM user ORDER BY id");
$sth->execute();
while (my $row = $sth->fetchrow_hashref) {
    print "  id=$row->{id} username=$row->{username} chips=$row->{chips}\n";
}

print "\nDone. Restart mojopoker: sudo systemctl restart mojopoker\n";
