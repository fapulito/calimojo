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

for my $player ('HousePlayer1', 'HousePlayer2') {
    my $bookmark = lc($player);
    $bookmark =~ s/player//;
    
    my $sth = $dbh->prepare("INSERT INTO users (username, chips, bookmark) VALUES (?, 1000000, ?) ON CONFLICT (username) DO UPDATE SET chips = 1000000");
    $sth->execute($player, $bookmark);
    print "Added/updated: $player\n";
}

print "\nCurrent users:\n";
my $sth = $dbh->prepare("SELECT id, username, chips FROM users ORDER BY id");
$sth->execute();
while (my $row = $sth->fetchrow_hashref) {
    print "  id=$row->{id} username=$row->{username} chips=$row->{chips}\n";
}

print "\nDone. Restart mojopoker: sudo systemctl restart mojopoker\n";
