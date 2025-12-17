#!/usr/bin/env perl
# Windows-compatible Mojo Poker server
# Usage: perl script/mojopoker_win.pl

use strict;
use warnings;
use feature qw(say);
use FindBin;
use lib "$FindBin::Bin/../lib";

# Change to the script directory so relative paths work
chdir "$FindBin::Bin/..";

$ENV{MOJO_MODE}               = 'development';
$ENV{MOJO_INACTIVITY_TIMEOUT} = 0;
$ENV{MOJO_LOG_LEVEL}          = 'debug';

# Wrap in eval to catch startup errors
eval {
    require Ships;
    require Mojo::Server::Daemon;
    
    my @listen = ('http://*:3000');
    
    my $daemon = Mojo::Server::Daemon->new(
        app    => Ships->new,
        listen => [@listen],
    );
    
    print "=" x 50 . "\n";
    print "  Mojo Poker Server Starting\n";
    print "=" x 50 . "\n";
    print "  URL: http://localhost:3000\n";
    print "  Press Ctrl+C to stop\n";
    print "=" x 50 . "\n\n";
    
    $daemon->run;
};

if ($@) {
    print "\n" . "=" x 50 . "\n";
    print "  SERVER ERROR\n";
    print "=" x 50 . "\n";
    print "$@\n";
    print "=" x 50 . "\n";
    print "Press Enter to exit...\n";
    <STDIN>;
}
