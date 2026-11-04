# Copyright (C) 2026, California Vision
# Forecasting play-token wallet + staking (Session 1).
# Play money only: no purchase, transfer-for-value, or cash-out path exists
# in this module by design. Do not add one.
package FB::Fc::Wallet;
use strict;
use warnings;
use Moo;
use File::Basename qw(dirname);
use File::Spec;

use constant DAILY_ALLOTMENT => 1000;

has 'db' => (
    is       => 'ro',
    required => 1,
    isa      => sub { die "Not a FB::Db" unless $_[0]->isa('FB::Db') },
);

sub _die {
    my ($code, $msg) = @_;
    die "FC:$code: $msg";
}

# Current calendar day (UTC) as TEXT 'YYYY-MM-DD'.
sub today {
    my @t = gmtime(time);
    return sprintf '%04d-%02d-%02d', $t[5] + 1900, $t[4] + 1, $t[3];
}

# Unique TEXT surrogate key (both engines lack a shared auto-increment).
# Shared with the other FB::Fc::* modules.
sub gen_id {
    my ($self, $prefix) = @_;
    require Time::HiRes;
    my $t = Time::HiRes::time();
    return sprintf '%s_%d_%06d_%d_%04d',
        $prefix, int($t), int(($t - int($t)) * 1_000_000), $$, int(rand(10000));
}

sub schema_file {
    my $mod = $INC{'FB/Fc/Wallet.pm'} or _die('schema', 'cannot locate module path');
    return File::Spec->catfile(dirname($mod), '..', '..', '..', 'db', 'fc.schema');
}

# Idempotently create the fc_* tables (safe to call at boot and in tests).
sub ensure_schema {
    my ($class, $db) = @_;
    $db or _die('schema', 'database handle required');
    my $file = $class->schema_file;
    open my $fh, '<', $file or _die('schema', "open $file: $!");
    local $/;
    my $sql = <$fh>;
    close $fh;
    for my $stmt (split /;\s*\n/, $sql) {
        $stmt =~ s/^\s+|\s+$//g;
        next unless length $stmt;
        $db->dbh->do($stmt);
    }
    # Session 3 migrations on pre-existing tables (fresh databases get them
    # from fc.schema; duplicate-column errors are ignored portably and
    # silently, since up-to-date databases hit them on every boot).
    my $dbh = $db->dbh;
    for my $alter (
        "ALTER TABLE fc_resolutions ADD COLUMN status TEXT NOT NULL DEFAULT 'proposed'",
        'ALTER TABLE fc_positions ADD COLUMN won INTEGER CHECK (won IN (0, 1))',
    ) {
        local $dbh->{PrintError} = 0;
        eval { $dbh->do($alter) };
        if ($@ && $@ !~ /duplicate|already exists/i) {
            die $@;
        }
    }
    return 1;
}

sub _row_for {
    my ($self, $user_id, $date) = @_;
    return $self->db->dbh->selectrow_hashref(
        'SELECT user_id, date, allotted, balance FROM fc_wallet_daily WHERE user_id = ? AND date = ?',
        undef, $user_id, $date);
}

sub _latest_row {
    my ($self, $user_id) = @_;
    return $self->db->dbh->selectrow_hashref(
        'SELECT user_id, date, allotted, balance FROM fc_wallet_daily WHERE user_id = ? ORDER BY date DESC LIMIT 1',
        undef, $user_id);
}

# Grant the daily 1000 play tokens on first touch of the day. Idempotent:
# repeated calls the same day grant nothing. Returns
# { date, granted (0 or 1000 by this call), balance }.
sub ensure_allotted {
    my ($self, $user_id, $date) = @_;
    $date //= $self->today;
    my $dbh = $self->db->dbh;
    if (my $row = $self->_row_for($user_id, $date)) {
        return { date => $date, granted => 0, balance => $row->{balance} + 0 };
    }
    my $prev    = $self->_latest_row($user_id);
    my $balance = ($prev ? $prev->{balance} : 0) + DAILY_ALLOTMENT;
    eval {
        $dbh->do('INSERT INTO fc_wallet_daily (user_id, date, allotted, balance) VALUES (?, ?, ?, ?)',
            undef, $user_id, $date, DAILY_ALLOTMENT, $balance);
    };
    if ($@) {
        # Lost a race with a concurrent first touch: re-read, else rethrow.
        if (my $row = eval { $self->_row_for($user_id, $date) }) {
            return { date => $date, granted => 0, balance => $row->{balance} + 0 };
        }
        die $@;
    }
    return { date => $date, granted => DAILY_ALLOTMENT, balance => $balance };
}

# Current spendable play-token balance (0 when no wallet row exists yet).
sub balance {
    my ($self, $user_id) = @_;
    my $row = $self->_latest_row($user_id);
    return $row ? $row->{balance} + 0 : 0;
}

# Settlement-only credit for winnings/refunds, called by FB::Fc::Resolution.
# NOT a generic deposit: there is still no purchase, transfer-for-value, or
# cash-out path. Returns the new balance.
sub settle_credit {
    my ($self, $user_id, $amount) = @_;
    _die('invalid_amount', 'amount must be a positive integer')
        unless defined $amount && $amount =~ /^\d+$/ && $amount > 0;
    $self->ensure_allotted($user_id);
    $self->db->dbh->do(
        'UPDATE fc_wallet_daily SET balance = balance + ? WHERE user_id = ? AND date = ?',
        undef, $amount, $user_id, $self->today);
    return $self->balance($user_id);
}

# Minimal question row (staking prerequisite). Sessions 2-3 own drafts,
# approval, resolution, and settlement; only open questions take stakes here.
sub create_question {
    my ($self, $opts) = @_;
    $opts->{prompt} //= '';
    _die('missing_prompt', 'prompt is required') unless length $opts->{prompt};
    my $status = $opts->{status} // 'open';
    _die('invalid_status', 'bad status')
        unless $status =~ /^(?:draft|open|resolved|settled|void)$/;
    my $id = $self->gen_id('q');
    $self->db->dbh->do(
        'INSERT INTO fc_questions (id, prompt, resolution_criteria, resolution_date, status, created_by, source_snapshot) VALUES (?, ?, ?, ?, ?, ?, ?)',
        undef, $id, $opts->{prompt}, $opts->{resolution_criteria},
        $opts->{resolution_date}, $status, $opts->{created_by}, $opts->{source_snapshot});
    return $id;
}

sub _question {
    my ($self, $question_id) = @_;
    return $self->db->dbh->selectrow_hashref(
        'SELECT id, status FROM fc_questions WHERE id = ?', undef, $question_id);
}

# Stake play tokens on an open question. Atomically debits today's wallet
# row and records the position. Dies FC:invalid_* / FC:no_such_question /
# FC:question_not_open / FC:insufficient_balance. Returns the position id.
sub stake {
    my ($self, $user_id, $question_id, $side, $stake, $price) = @_;
    _die('invalid_side', 'side must be YES or NO')
        unless defined $side && $side =~ /^(?:YES|NO)$/;
    _die('invalid_stake', 'stake must be a positive integer')
        unless defined $stake && $stake =~ /^\d+$/ && $stake > 0;
    _die('invalid_price', 'price must be an integer 0..100')
        unless defined $price && $price =~ /^\d+$/ && $price >= 0 && $price <= 100;
    my $q = $self->_question($question_id);
    _die('no_such_question', 'unknown question') unless $q;
    _die('question_not_open', 'question is not open') unless $q->{status} eq 'open';

    $self->ensure_allotted($user_id);
    my $date = $self->today;
    my $db   = $self->db;
    my $dbh  = $db->dbh;
    my $outer_txn = !$dbh->{AutoCommit};
    $db->begin_transaction unless $outer_txn;
    my $pos_id = $self->gen_id('pos');
    eval {
        my $rows = $dbh->do(
            'UPDATE fc_wallet_daily SET balance = balance - ? WHERE user_id = ? AND date = ? AND balance >= ?',
            undef, $stake, $user_id, $date, $stake);
        _die('insufficient_balance', "balance too low for stake $stake")
            unless $rows == 1;
        $dbh->do(
            'INSERT INTO fc_positions (id, question_id, user_id, side, stake, price_at_entry, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
            undef, $pos_id, $question_id, $user_id, $side, $stake, $price,
            $db->_format_timestamp(time));
        $db->commit_transaction unless $outer_txn;
    };
    if (my $err = $@) {
        $db->rollback_transaction unless $outer_txn;
        die $err;
    }
    return $pos_id;
}

1;

__END__

=head1 NAME

FB::Fc::Wallet - forecasting play-token wallet and staking (Session 1)

=head1 PLAY MONEY ONLY

Tokens are granted daily, staked on forecast questions, and displayed in the
client. There is deliberately no purchase, transfer-for-value, or cash-out
path anywhere in this module. Do not add one.

=head1 METHODS

=over 4

=item ensure_schema($db)

Idempotently applies C<db/fc.schema> (all five fc_* tables + indexes).
Runs at server boot (FB::BUILD) and in tests.

=item ensure_allotted($user_id [, $date])

Grants 1000 play tokens on the first touch of a calendar day (UTC); later
calls the same day grant nothing. The new day starts at the previous
balance plus 1000. Returns C<{ date, granted, balance }>.

=item balance($user_id)

Current spendable balance (0 when the user has no wallet row yet).

=item create_question(\%opts)

Minimal open-question row (prompt required). Staking prerequisite; the
draft/approve and resolution flows arrive in later sessions.

=item stake($user_id, $question_id, $side, $stake, $price)

Debits the wallet and records a YES/NO position at integer price 0..100.
Dies C<FC:insufficient_balance> when short (also C<FC:invalid_*>,
C<FC:no_such_question>, C<FC:question_not_open>).

=item settle_credit($user_id, $amount)

Settlement-only credit for winnings and refunds. Not a deposit path.

=item gen_id($prefix)

Unique TEXT surrogate key shared with the other C<FB::Fc::*> modules.

=back

=cut
