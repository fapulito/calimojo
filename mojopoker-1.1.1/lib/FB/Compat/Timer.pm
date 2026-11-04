package FB::Compat::Timer;
# Compatibility layer for EV::timer on Windows
# Falls back to Mojo::IOLoop if EV is not available

use strict;
use warnings;

our $USE_EV;

BEGIN {
    # Native EV timers only off Windows: this layer exists to give
    # Windows Mojo timers, and Strawberry's EV XS is unreliable here
    # (watcher destroy/method calls fault). Linux keeps native EV.
    $USE_EV = ($^O ne 'MSWin32') && eval { require EV; 1 };
    unless ($USE_EV) {
        require Mojo::IOLoop;
    }
}

# Wrapper object to mimic EV::Timer interface
package FB::Compat::Timer::Handle;
sub new {
    my ($class, $id, $repeat, $start_time, $after, $recurring_id) = @_;
    return bless { 
        id => $id, 
        repeat => $repeat,
        start_time => $start_time // time(),
        after => $after // 0,
        recurring_id => $recurring_id,  # Track recurring timer ID for cancellation
    }, $class;
}

sub cancel {
    my $self = shift;
    # Dropping the native watcher stops it: per the EV docs, a watcher is
    # automatically stopped when its object is destroyed. No EV methods
    # are called here by design (the app never calls watcher methods).
    delete $self->{ev_watcher};
    # Remove both initial and recurring timers if they exist (Mojo backend)
    Mojo::IOLoop->remove($self->{id}) if $self->{id};
    Mojo::IOLoop->remove($self->{recurring_id}) if $self->{recurring_id};
}
sub remaining { 
    my $self = shift;
    my $elapsed = time() - $self->{start_time};
    my $after = $self->{after} // 0;
    my $repeat = $self->{repeat};
    
    # Handle recurring timers
    if ($repeat && $repeat > 0 && $elapsed > $after) {
        # Timer has fired at least once, compute time until next repeat
        my $since_first = $elapsed - $after;
        my $cycle_elapsed = $since_first % $repeat;
        my $remaining = $repeat - $cycle_elapsed;
        # Return 0 at exact firing times, otherwise positive value
        return $remaining > 0 ? $remaining : 0;
    }
    
    # One-shot timer or before first firing
    my $remaining = $after - $elapsed;
    return $remaining > 0 ? $remaining : 0;
}

package FB::Compat::Timer;

sub timer {
    my ($after, $repeat, $cb) = @_;

    # Callers may pass Time::Seconds objects (e.g. the FB prize timer);
    # numify so arithmetic and the native watchers get plain seconds.
    $after  = 0 + $after;
    $repeat = 0 + $repeat;

    if ($USE_EV) {
        # Wrap the native watcher so every backend returns the same
        # Handle interface (remaining/cancel), which raw EV::Timer lacks.
        my $start_time = time();
        my $ev = EV::timer($after, $repeat, $cb);
        my $handle = FB::Compat::Timer::Handle->new(
            undef, $repeat, $start_time, $after, undef);
        $handle->{ev_watcher} = $ev;
        return $handle;
    } else {
        # Use Mojo::IOLoop as fallback
        my $start_time = time();
        my $handle;
        
        if ($repeat) {
            # EV::timer($after, $repeat, $cb) fires first after $after seconds,
            # then every $repeat seconds. Mojo::IOLoop->recurring starts immediately.
            # We need to use a one-shot timer for initial delay, then start recurring.
            my $recurring_id;
            my $initial_id = Mojo::IOLoop->timer($after => sub {
                $cb->();  # First firing after $after
                $recurring_id = Mojo::IOLoop->recurring($repeat => $cb);
                # Update handle with recurring ID for cancellation
                $handle->{recurring_id} = $recurring_id if $handle;
            });
            $handle = FB::Compat::Timer::Handle->new($initial_id, $repeat, $start_time, $after, undef);
        } else {
            my $id = Mojo::IOLoop->timer($after => $cb);
            $handle = FB::Compat::Timer::Handle->new($id, $repeat, $start_time, $after, undef);
        }
        return $handle;
    }
}

# Cancel a handle created by timer(). FB::Session::Manager uses this
# when a seated player reconnects inside the grace period.
sub cancel_timer {
    my ($handle) = @_;
    return unless $handle && ref($handle) && $handle->can('cancel');
    $handle->cancel;
    return 1;
}

1;
