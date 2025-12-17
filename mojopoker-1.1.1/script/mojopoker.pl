#!/usr/bin/env perl

use strict;
use warnings;
use feature qw(say);
use lib './lib';

# Load .env file if it exists
if (-f '.env') {
    open my $fh, '<', '.env' or warn "Could not open .env: $!";
    while (<$fh>) {
        chomp;
        next if /^\s*#/ || /^\s*$/;  # Skip comments and empty lines
        if (/^([^=]+)=(.*)$/) {
            my ($key, $value) = ($1, $2);
            $value =~ s/^["']|["']$//g;  # Remove quotes
            $ENV{$key} = $value unless exists $ENV{$key};
        }
    }
    close $fh;
}

use Ships;
use EV;
use Mojo::Server::Daemon;
use POSIX qw(setsid);

$ENV{MOJO_MODE}               = 'production';
$ENV{MOJO_INACTIVITY_TIMEOUT} = 0;
$ENV{MOJO_LOG_LEVEL} = 'fatal';

my @listen = ('http://*:3000');

my $daemon = Mojo::Server::Daemon->new(
    app                => Ships->new,
    listen             => [@listen],
    accepts            => 0,
    proxy              => 1,
);

# Fork and kill parent
die "Can't fork: $!" unless defined( my $pid = fork );
exit 0 if $pid;
POSIX::setsid or die "Can't start a new session: $!";

# pid file
open my $handle, '>', 'mojopoker.pid';
print $handle $$;
close $handle;

# Close filehandles
open STDIN,  '</dev/null';
open STDERR, '>&STDOUT';

$daemon->start;

open STDOUT, '>/dev/null';

EV::run;