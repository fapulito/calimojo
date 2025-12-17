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
    my ($class, $id, $repeat, $start_time, $after) = @_;
    return bless { 
        id => $id, 
        repeat => $repeat,
        start_time => $start_time || time(),
        after => $after || 0,
    }, $class;
}
sub remaining { 
    my $self = shift;
    my $elapsed = time() - $self->{start_time};
    my $remaining = $self->{after} - $elapsed;
    return $remaining > 0 ? $remaining : 0;
}

package FB::Compat::Timer;

sub timer {
    my ($after, $repeat, $cb) = @_;
    
    if ($USE_EV) {
        return EV::timer($after, $repeat, $cb);
    } else {
        # Use Mojo::IOLoop as fallback
        my $id;
        my $start_time = time();
        if ($repeat) {
            $id = Mojo::IOLoop->recurring($repeat => $cb);
        } else {
            $id = Mojo::IOLoop->timer($after => $cb);
        }
        return FB::Compat::Timer::Handle->new($id, $repeat, $start_time, $after);
    }
}

1;
