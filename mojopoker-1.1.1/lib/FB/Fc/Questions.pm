# Copyright (C) 2026, California Vision
# Forecast question service (Sessions 2-3): drafts, approval, listing with
# parimutuel implied probabilities. Play money only.
package FB::Fc::Questions;
use strict;
use warnings;
use Moo;
use File::Basename qw(dirname);
use File::Spec;
use List::Util qw(shuffle);
use Mojo::JSON qw(j);

use FB::Fc::Model;
use FB::Fc::Wallet;

# Pseudo-volume per side so untouched and first-stake questions display
# sanely (an empty question shows 50/50).
use constant SEED_PER_SIDE => 50;

has 'db' => (
    is       => 'ro',
    required => 1,
    isa      => sub { die "Not a FB::Db" unless $_[0]->isa('FB::Db') },
);

has 'model' => (
    is      => 'ro',
    default => sub { FB::Fc::Model->new },
);

has 'wallet' => (
    is      => 'ro',
    default => sub { my $self = shift; FB::Fc::Wallet->new(db => $self->db) },
);

sub _die {
    my ($code, $msg) = @_;
    die "FC:$code: $msg";
}

sub fixture_dir {
    my $mod = $INC{'FB/Fc/Questions.pm'} or _die('fixtures', 'cannot locate module path');
    return File::Spec->catfile(dirname($mod), '..', '..', '..', 'fixtures');
}

sub _load_headlines {
    my ($self) = @_;
    my $file = File::Spec->catfile($self->fixture_dir, 'fc_headlines.json');
    open my $fh, '<', $file or _die('fixtures', "open $file: $!");
    local $/;
    my $data = eval { j(scalar <$fh>) };
    close $fh;
    _die('fixtures', "bad $file: $@") if $@;
    return $data;
}

# Sample $count (3-5) headlines: within $topic, or round-robin mixed.
sub sample_headlines {
    my ($self, $topic, $count) = @_;
    $count //= 4;
    _die('bad_count', 'count must be 3..5')
        unless defined $count && $count =~ /^[3-5]$/;
    my $data = $self->_load_headlines;
    my @topics = sort grep { ref $data->{$_} eq 'ARRAY' } keys %$data;
    if (defined $topic) {
        _die('bad_topic', 'unknown topic') unless grep { $_ eq $topic } @topics;
        @topics = ($topic);
    }
    my @pools = map { [ shuffle @{ $data->{$_} } ] } @topics;
    my @out;
    while (@out < $count) {
        my $took = 0;
        for my $pool (@pools) {
            last if @out >= $count;
            if (@$pool) { push @out, shift @$pool; $took = 1; }
        }
        last unless $took;
    }
    _die('bad_count', 'not enough headlines') unless @out >= 3;
    return \@out;
}

# Draft one question per headline cluster via the model. Drafts land in
# fc_questions with status=draft. Returns the new ids.
sub generate_from_headlines {
    my ($self, $headlines, $created_by) = @_;
    _die('bad_headlines', 'need 3..5 headline strings')
        unless ref $headlines eq 'ARRAY' && @$headlines >= 3 && @$headlines <= 5
        && !grep { !defined $_ || !length $_ } @$headlines;
    my $drafts = $self->model->generate('draft_questions',
        { headlines => $headlines, count => scalar @$headlines });
    my $snapshot = j({ headlines => $headlines });
    my @ids;
    for my $d (@$drafts) {
        next unless ref $d eq 'HASH' && defined $d->{prompt} && length $d->{prompt};
        my $id = $self->wallet->gen_id('q');
        $self->db->dbh->do(
            'INSERT INTO fc_questions (id, prompt, resolution_criteria, resolution_date, status, created_by, source_snapshot, resolution_source, source_ref, settlement_rule) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            undef, $id, $d->{prompt}, $d->{resolution_criteria},
            $d->{resolution_date}, 'draft', $created_by, $snapshot,
            $d->{resolution_source}, $d->{source_ref}, $d->{settlement_rule});
        push @ids, $id;
    }
    _die('no_valid_drafts', 'model returned no usable drafts') unless @ids;
    return \@ids;
}

sub get {
    my ($self, $question_id) = @_;
    return $self->db->dbh->selectrow_hashref(
        'SELECT id, prompt, resolution_criteria, resolution_date, status, created_by, source_snapshot FROM fc_questions WHERE id = ?',
        undef, $question_id);
}

sub _as_open {
    my ($self, $question_id, $to, $action) = @_;
    my $q = $self->get($question_id);
    _die('no_such_question', 'unknown question') unless $q;
    _die('not_draft', "only drafts can be $action") unless $q->{status} eq 'draft';
    $self->db->dbh->do('UPDATE fc_questions SET status = ? WHERE id = ?',
        undef, $to, $question_id);
    return 1;
}

# Admin approve: draft -> open.
sub approve {
    my ($self, $question_id) = @_;
    return $self->_as_open($question_id, 'open', 'approved');
}

# Admin reject: draft -> void (kept for audit, never takes stakes).
sub reject {
    my ($self, $question_id) = @_;
    return $self->_as_open($question_id, 'void', 'rejected');
}

sub _totals {
    my ($self, $question_id) = @_;
    my $row = $self->db->dbh->selectrow_hashref(
        q{SELECT COALESCE(SUM(CASE WHEN side = 'YES' THEN stake END), 0) AS yes_total,
                  COALESCE(SUM(CASE WHEN side = 'NO' THEN stake END), 0) AS no_total
           FROM fc_positions WHERE question_id = ?},
        undef, $question_id);
    return ($row->{yes_total} + 0, $row->{no_total} + 0);
}

# Parimutuel implied probability (integer percent, seeded per side).
sub implied_prob {
    my ($self, $question_id) = @_;
    _die('no_such_question', 'unknown question') unless $self->get($question_id);
    my ($yes, $no) = $self->_totals($question_id);
    my $seed  = SEED_PER_SIDE;
    my $total = $yes + $no;
    my $prob_yes = int(($yes + $seed) * 100 / ($total + 2 * $seed) + 0.5);
    return {
        prob_yes  => $prob_yes,
        prob_no   => 100 - $prob_yes,
        yes_total => $yes + 0,
        no_total  => $no + 0,
        total     => $total + 0,
    };
}

# Questions of one status (open/draft/resolved/settled) with probabilities
# + the caller's own staked totals per question.
sub list_with_probs {
    my ($self, $status, $user_id) = @_;
    $status //= 'open';
    _die('bad_status', 'bad status') unless $status =~ /^(?:open|draft|resolved|settled)$/;
    my $rows = $self->db->dbh->selectall_arrayref(
        'SELECT id, prompt, resolution_criteria, resolution_date, status, created_by FROM fc_questions WHERE status = ? ORDER BY id ASC',
        { Slice => {} }, $status);
    my %mine;
    if (defined $user_id) {
        my $mine = $self->db->dbh->selectall_arrayref(
            'SELECT question_id, side, SUM(stake) FROM fc_positions WHERE user_id = ? GROUP BY question_id, side',
            undef, $user_id);
        for my $r (@$mine) {
            $mine{ $r->[0] }{ $r->[1] } = $r->[2] + 0;
        }
    }
    my $seed = SEED_PER_SIDE;
    for my $q (@$rows) {
        my ($yes, $no) = $self->_totals($q->{id});
        my $total = $yes + $no;
        my $prob_yes = int(($yes + $seed) * 100 / ($total + 2 * $seed) + 0.5);
        $q->{prob_yes}  = $prob_yes;
        $q->{prob_no}   = 100 - $prob_yes;
        $q->{yes_total} = $yes + 0;
        $q->{no_total}  = $no + 0;
        $q->{total}     = $total + 0;
        $q->{my_yes}    = ($mine{ $q->{id} }{YES} // 0) + 0;
        $q->{my_no}     = ($mine{ $q->{id} }{NO} // 0) + 0;
    }
    return $rows;
}

1;

__END__

=head1 NAME

FB::Fc::Questions - forecast question loop service (Session 2)

=head1 FLOW

Headlines (fixture file or caller-supplied) go to the model, which drafts
yes/no questions with resolution criteria and dates. Drafts land with
status=draft; an admin approves (draft -> open) or rejects (draft -> void).
Open questions take YES/NO stakes through L<FB::Fc::Wallet>.

=head1 IMPLIED PROBABILITY

Parimutuel share with pseudo-volume: with seed S=50 per side,
YES% = (YES+S)*100/(total+2S), NO% = 100-YES%. Empty questions show 50/50
and the first stake moves the bar sanely.

=cut
