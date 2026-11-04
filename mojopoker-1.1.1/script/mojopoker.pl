#!/usr/bin/env perl
# CHANGE NOTICE (Session 5 deploy prep, 2026-11-04, California Vision):
# - PORT env selects the listen port (default 3000); MOJOPOKER_FOREGROUND=1
#   skips the fork/setsid/pidfile/stdout-discard so containers stay attached
#   and keep their logs. Daemon behavior unchanged otherwise.

use strict;
use warnings;
use feature qw(say);
use lib './lib';

# Load .env file if it exists
if (-f '.env' && open my $fh, '<', '.env') {
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
} elsif (-f '.env') {
    warn "Could not open .env: $!";
}

use Ships;
use EV;
use Mojo::Server::Daemon;
use POSIX qw(setsid);

$ENV{MOJO_MODE}               = 'production';
$ENV{MOJO_INACTIVITY_TIMEOUT} = 0;
$ENV{MOJO_LOG_LEVEL} = 'fatal';

my $port = $ENV{PORT} // 3000;
my @listen = ("http://*:$port");

my $daemon = Mojo::Server::Daemon->new(
    app                => Ships->new,
    listen             => [@listen],
    accepts            => 0,
    proxy              => 1,
);

# Containers must stay in the foreground: PID 1 exiting ends the container,
# and Fly collects logs from stdout/stderr. MOJOPOKER_FOREGROUND=1 skips the
# fork/setsid/pidfile dance and keeps all output attached.
unless ($ENV{MOJOPOKER_FOREGROUND}) {
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
}

$daemon->start;

unless ($ENV{MOJOPOKER_FOREGROUND}) {
    open STDOUT, '>/dev/null';
}

EV::run;
