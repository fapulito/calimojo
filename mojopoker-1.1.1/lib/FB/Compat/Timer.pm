package FB::Compat::Timer;
# Compatibility layer for EV::timer on Windows
# Falls back to Mojo::IOLoop if EV is not available

use strict;
use warnings;

our $USE_EV;

BEGIN {
    $USE_EV = eval { require EV; 1 };
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
    # Remove both initial and recurring timers if they exist
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
    
    if ($USE_EV) {
        return EV::timer($after, $repeat, $cb);
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

1;
