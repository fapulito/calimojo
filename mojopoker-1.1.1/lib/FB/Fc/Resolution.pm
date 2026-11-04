# Copyright (C) 2026, California Vision
# Forecast resolution, challenge window, settlement, and reputation (Session 3).
# resolve() asks the model (fixture-capable) for YES/NO + reasoning + sources,
# stores everything in fc_resolutions.evidence_json, and opens a challenge
# window. challenge() flags a resolution for manual review (never auto-
# reverses). settle() pays winners pro-rata from the pool after the window
# and refreshes per-user reputation (won/lost + Brier score).
package FB::Fc::Resolution;
use strict;
use warnings;
use Moo;
use Mojo::JSON qw(j);
use FB::Fc::Model;
use FB::Fc::Wallet;

has 'db' => (is => 'ro', required => 1);

has 'model' => (
    is      => 'ro',
    default => sub { FB::Fc::Model->new },
);

has 'wallet' => (
    is      => 'ro',
    default => sub { my $self = shift; FB::Fc::Wallet->new(db => $self->db) },
);

# Challenge window in minutes: FORECAST_CHALLENGE_MINUTES (=5 for demos),
# else 120 (settlement blocked until resolved_at + 2h).
has 'challenge_window_minutes' => (
    is      => 'ro',
    default => sub {
        my $v = $ENV{FORECAST_CHALLENGE_MINUTES};
        return ($v // '') =~ /^\d+$/ && $v > 0 ? $v + 0 : 120;
    },
);

sub _die {
    my ($code, $detail) = @_;
    die "FC:$code" . (defined $detail && length $detail ? ": $detail" : '');
}

sub _question {
    my ($self, $question_id) = @_;
    return $self->db->dbh->selectrow_hashref(
        'SELECT * FROM fc_questions WHERE id = ?', undef, $question_id);
}

sub _resolution_for {
    my ($self, $question_id) = @_;
    return $self->db->dbh->selectrow_hashref(
        'SELECT * FROM fc_resolutions WHERE question_id = ?', undef, $question_id);
}

# resolve($question_id, $user_id, $is_admin, $snippets?)
# Past-dated open question -> model verdict -> proposed resolution + window.
sub resolve {
    my ($self, $question_id, $user_id, $is_admin, $snippets) = @_;
    my $q = $self->_question($question_id);
    _die('no_such_question', $question_id) unless $q;
    if ($self->_resolution_for($question_id)) {
        _die('already_resolved', $question_id);
    }
    _die('question_not_resolvable', "status is $q->{status}")
        unless ($q->{status} // '') eq 'open';
    unless ($is_admin || (($q->{created_by} // '') eq $user_id)) {
        _die('not_authorized', 'only the author or an admin may resolve');
    }
    my $now = time;
    my $rdate = $self->db->_parse_timestamp($q->{resolution_date});
    _die('too_early', 'resolution date is in the future') if $rdate > $now;
    $snippets //= $self->model->default_snippets;
    _die('bad_snippets', 'snippets must be an array')
        unless ref $snippets eq 'ARRAY';
    for my $s (@$snippets) {
        _die('bad_snippets', 'each snippet needs source and text')
            unless ref $s eq 'HASH' && $s->{source} && $s->{text};
    }
    my $verdict = $self->model->generate('resolve', {
        prompt   => $q->{prompt},
        criteria => $q->{resolution_criteria},
        snippets => $snippets,
    });
    my $outcome = $verdict->{outcome} // '';
    _die('bad_outcome', "model returned '$outcome'")
        unless $outcome eq 'YES' || $outcome eq 'NO';
    my $used = ref $verdict->{sources_used} eq 'ARRAY' ? $verdict->{sources_used} : [];
    my @sources = map {
        +{ source => $_->{source} // '?', ref => $_->{ref} // '' }
    } grep { ref $_ eq 'HASH' } @$used;
    my $evidence = {
        outcome      => $outcome,
        reasoning    => $verdict->{reasoning} // '',
        sources_used => \@sources,
        question     => $q->{prompt},
        criteria     => $q->{resolution_criteria},
        resolved_by  => $user_id,
    };
    my $rid = $self->wallet->gen_id('res');
    my $deadline = $now + $self->challenge_window_minutes * 60;
    my $dbh = $self->db->dbh;
    $dbh->do(
        'INSERT INTO fc_resolutions (id, question_id, outcome, evidence_json, resolved_at, challenge_deadline, status)'
        . ' VALUES (?, ?, ?, ?, ?, ?, ?)',
        undef, $rid, $question_id, $outcome, j($evidence),
        $self->db->_format_timestamp($now),
        $self->db->_format_timestamp($deadline), 'proposed');
    $dbh->do("UPDATE fc_questions SET status = 'resolved' WHERE id = ?", undef, $question_id);
    return {
        resolution_id      => $rid,
        outcome            => $outcome,
        reasoning          => $evidence->{reasoning},
        sources_used       => \@sources,
        challenge_deadline => $deadline,
    };
}

# challenge($resolution_id, $user_id, $reason)
# Records the challenge and flags the resolution for manual review.
# Never reverses the outcome on its own.
sub challenge {
    my ($self, $resolution_id, $user_id, $reason) = @_;
    my $r = $self->db->dbh->selectrow_hashref(
        'SELECT * FROM fc_resolutions WHERE id = ?', undef, $resolution_id);
    _die('no_such_resolution', $resolution_id) unless $r;
    _die('bad_reason', 'a reason is required')
        unless defined $reason && $reason =~ /\S/;
    _die('already_settled', $resolution_id) if ($r->{status} // '') eq 'settled';
    my $deadline = $self->db->_parse_timestamp($r->{challenge_deadline});
    _die('window_closed', 'challenge deadline has passed') if time > $deadline;
    my $cid = $self->wallet->gen_id('ch');
    my $dbh = $self->db->dbh;
    $dbh->do(
        'INSERT INTO fc_challenges (id, resolution_id, user_id, reason, status) VALUES (?, ?, ?, ?, ?)',
        undef, $cid, $resolution_id, $user_id, $reason, 'open');
    $dbh->do("UPDATE fc_resolutions SET status = 'challenged' WHERE id = ?", undef, $resolution_id);
    return { challenge_id => $cid, status => 'challenged' };
}

# settle($question_id, $user_id, $is_admin)
# After the window, unchallenged: winners paid pro-rata from the pool.
sub settle {
    my ($self, $question_id, $user_id, $is_admin) = @_;
    my $q = $self->_question($question_id);
    _die('no_such_question', $question_id) unless $q;
    unless ($is_admin || (($q->{created_by} // '') eq $user_id)) {
        _die('not_authorized', 'only the author or an admin may settle');
    }
    my $r = $self->_resolution_for($question_id);
    _die('not_resolved', $question_id) unless $r;
    my $status = $r->{status} // '';
    _die('already_settled', $question_id) if $status eq 'settled';
    _die('challenged', 'resolution is under manual review') if $status eq 'challenged';
    my $deadline = $self->db->_parse_timestamp($r->{challenge_deadline});
    _die('window_open', 'challenge window is still open') if time < $deadline;
    my $dbh = $self->db->dbh;
    my $positions = $dbh->selectall_arrayref(
        'SELECT * FROM fc_positions WHERE question_id = ?', { Slice => {} }, $question_id);
    my ($paid, $winners) = (0, 0);
    eval {
        $dbh->begin_work;
        # Mark settled first: the reputation refresh below only counts
        # positions whose resolution row already reads 'settled'.
        my $now = time;
        $dbh->do("UPDATE fc_resolutions SET status = 'settled', settled_at = ? WHERE id = ?",
            undef, $self->db->_format_timestamp($now), $r->{id});
        $dbh->do("UPDATE fc_questions SET status = 'settled' WHERE id = ?", undef, $question_id);
        if (($r->{outcome} // '') eq 'VOID') {
            # Void: full-stake refunds, no winners, no reputation signal.
            for my $p (@$positions) {
                $paid += $p->{stake};
                $self->wallet->settle_credit($p->{user_id}, $p->{stake} + 0);
            }
        }
        else {
            my @won = grep { $_->{side} eq $r->{outcome} } @$positions;
            my $pool = 0;
            $pool += $_->{stake} for @$positions;
            my $wtot = 0;
            $wtot += $_->{stake} for @won;
            if ($pool > 0 && $wtot > 0) {
                for my $p (@won) {
                    # Integer pro-rata; dust stays in the pool (burned).
                    my $share = int($p->{stake} * $pool / $wtot);
                    if ($share > 0) {
                        $paid += $share;
                        $winners++;
                        $self->wallet->settle_credit($p->{user_id}, $share);
                    }
                }
            }
            $dbh->do('UPDATE fc_positions SET won = CASE WHEN side = ? THEN 1 ELSE 0 END WHERE question_id = ?',
                undef, $r->{outcome}, $question_id);
            my %holders = map { $_->{user_id} => 1 } @$positions;
            $self->_refresh_reputation($_) for keys %holders;
        }
        $dbh->commit;
        1;
    } or do {
        my $err = $@ || 'unknown error';
        eval { $dbh->rollback };
        die $err;
    };
    return {
        outcome    => $r->{outcome},
        winners    => $winners,
        total_paid => $paid + 0,
        positions  => scalar @$positions,
    };
}

# Recomputes one user's reputation from their settled YES/NO positions:
# won/lost counts plus the mean Brier score, where each position's forecast
# is its price_at_entry as the probability its side wins.
sub _refresh_reputation {
    my ($self, $user_id) = @_;
    my $rows = $self->db->dbh->selectall_arrayref(
        'SELECT p.won, p.price_at_entry, p.side FROM fc_positions p'
        . ' JOIN fc_resolutions r ON r.question_id = p.question_id'
        . ' WHERE p.user_id = ? AND r.status = ? AND r.outcome <> ?',
        { Slice => {} }, $user_id, 'settled', 'VOID');
    my ($won, $n, $brier_sum) = (0, 0, 0);
    for my $row (@$rows) {
        my $actual = $row->{won} ? 1 : 0;
        $won += $actual;
        $n++;
        my $prob = ($row->{price_at_entry} + 0) / 100;
        $prob = 1 - $prob if ($row->{side} // '') eq 'NO';
        $brier_sum += ($prob - $actual) ** 2;
    }
    my $brier = $n ? sprintf('%.4f', $brier_sum / $n) + 0 : undef;
    my $now_fmt = $self->db->_format_timestamp(time);
    my $updated = $self->db->dbh->do(
        'UPDATE fc_reputation SET won = ?, lost = ?, brier = ?, updated_at = ? WHERE user_id = ?',
        undef, $won, $n - $won, $brier, $now_fmt, $user_id);
    if ($updated == 0) {
        $self->db->dbh->do(
            'INSERT INTO fc_reputation (user_id, won, lost, brier, updated_at) VALUES (?, ?, ?, ?, ?)',
            undef, $user_id, $won, $n - $won, $brier, $now_fmt);
    }
    return { user_id => $user_id + 0, won => $won + 0, lost => $n - $won, brier => $brier };
}

# reputation($user_id) -> { user_id, won, lost, brier } (brier undef = none).
sub reputation {
    my ($self, $user_id) = @_;
    my $row = $self->db->dbh->selectrow_hashref(
        'SELECT user_id, won, lost, brier FROM fc_reputation WHERE user_id = ?', undef, $user_id);
    return $row
        ? { user_id => $row->{user_id} + 0, won => $row->{won} + 0,
            lost => $row->{lost} + 0, brier => $row->{brier} }
        : { user_id => $user_id + 0, won => 0, lost => 0, brier => undef };
}

# Full public record for a resolution id: outcome, reasoning, cited
# sources, window state, and filed challenges.
sub get_resolution_record {
    my ($self, $resolution_id) = @_;
    my $r = $self->db->dbh->selectrow_hashref(
        'SELECT * FROM fc_resolutions WHERE id = ?', undef, $resolution_id);
    return undef unless $r;
    my $q = $self->_question($r->{question_id});
    my $ev = eval { j($r->{evidence_json} // '{}') } // {};
    $ev = {} unless ref $ev eq 'HASH';
    my $challenges = $self->db->dbh->selectall_arrayref(
        'SELECT user_id, reason, status FROM fc_challenges WHERE resolution_id = ? ORDER BY rowid',
        { Slice => {} }, $resolution_id);
    return {
        resolution_id      => $r->{id},
        question_id        => $r->{question_id},
        prompt             => $q ? $q->{prompt} : '',
        criteria           => $q ? $q->{resolution_criteria} : '',
        outcome            => $r->{outcome},
        status             => $r->{status},
        reasoning          => $ev->{reasoning} // '',
        sources_used       => ref $ev->{sources_used} eq 'ARRAY' ? $ev->{sources_used} : [],
        resolved_at        => $self->db->_parse_timestamp($r->{resolved_at}),
        challenge_deadline => $self->db->_parse_timestamp($r->{challenge_deadline}),
        settled_at         => defined $r->{settled_at} ? $self->db->_parse_timestamp($r->{settled_at}) : undef,
        challenges         => $challenges,
    };
}

# Resolution row for a question id (undef when unresolved).
sub get_resolution_for_question {
    my ($self, $question_id) = @_;
    return $self->_resolution_for($question_id);
}

1;

__END__

=head1 NAME

FB::Fc::Resolution - resolve, challenge, settle, reputation (Session 3)

=head1 FLOW

An open question past its resolution date is resolved by its author (or an
admin): the model returns YES/NO with reasoning and cited sources, stored in
C<fc_resolutions.evidence_json>, and a challenge window opens (default 120
minutes, C<FORECAST_CHALLENGE_MINUTES> to override, 5 for demos). Any
authenticated user may file a challenge with a reason during the window; the
first filing flags the resolution C<challenged> for manual review and blocks
settlement. There is no auto-reversal. After the window, an unchallenged
resolution settles: winners are paid from the pool pro-rata in play tokens
(integer shares; dust is burned), positions are marked won/lost, and each
staker's reputation (won/lost counts plus mean Brier score over settled
YES/NO positions) is recomputed. VOID resolutions refund every stake in full
and carry no reputation signal.

=head1 METHODS

=over 4

=item resolve($question_id, $user_id, $is_admin, $snippets?)

=item challenge($resolution_id, $user_id, $reason)

=item settle($question_id, $user_id, $is_admin)

=item reputation($user_id)

=item get_resolution_record($resolution_id)

=item get_resolution_for_question($question_id)

All failures die C<FC:...>. Timestamps compare as epoch seconds in Perl so
both engines behave the same.

=back

=cut
