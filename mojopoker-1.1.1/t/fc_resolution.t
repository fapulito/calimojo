#!/usr/bin/env perl
# Copyright (C) 2026, California Vision
# Forecast resolution tests (Session 3). Play money only.
#
# Covers FB::Fc::Resolution: evidence storage, resolve guards, the challenge
# window (early/challenged settlement refused), pro-rata settlement payouts,
# Brier-score reputation updates, VOID refunds, the schema migration for
# pre-Session-3 databases, and the fc_* websocket endpoints + record route.
#
# Hermetic: scratch SQLite db built from db/fb.schema + db/fc.schema;
# FORECAST_FIXTURE=1 (no network, no API key).
use strict;
use warnings;
$| = 1;
use Test::More;
use FindBin;
use File::Temp qw(tempdir);
use File::Spec;
use lib "$FindBin::Bin/../lib";
use Mojo::JSON qw(j);

our $TMP = tempdir(CLEANUP => 1);
local $ENV{DATABASE_TYPE} = 'sqlite';
local $ENV{SQLITE_PATH} = $TMP;
delete local $ENV{DATABASE_URL};
local $ENV{FORECAST_FIXTURE} = '1';

sub schema_sql {
    my ($file) = @_;
    my $path = File::Spec->catfile($FindBin::Bin, '..', 'db', $file);
    open my $fh, '<', $path or die "open $path: $!";
    local $/;
    my $sql = <$fh>;
    close $fh;
    return $sql;
}

sub apply_sql {
    my ($dir, $sql) = @_;
    require DBI;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$dir/fb.db", '', '',
        { RaiseError => 1, AutoCommit => 1 });
    for my $stmt (split /;\s*\n/, $sql) {
        $stmt =~ s/^\s+|\s+$//g;
        next unless length $stmt;
        $dbh->do($stmt);
    }
}
apply_sql($TMP, schema_sql('fb.schema'));
apply_sql($TMP, schema_sql('fc.schema'));

use FB::Db;
use FB::Fc::Wallet;
use FB::Fc::Resolution;

my $DB = FB::Db->new;
my $W = FB::Fc::Wallet->new(db => $DB);
my $R = FB::Fc::Resolution->new(db => $DB, wallet => $W);

sub past_ts { $DB->_format_timestamp(time - 86400) }

sub mkq {
    my (%o) = @_;
    return $W->create_question({
        prompt              => $o{prompt} // 'Q?',
        resolution_criteria => 'criteria',
        resolution_date     => $o{date} // past_ts(),
        status              => $o{status} // 'open',
        created_by          => $o{by},
    });
}

sub force_past_deadline {
    my ($rid) = @_;
    $DB->dbh->do('UPDATE fc_resolutions SET challenge_deadline = ? WHERE id = ?',
        undef, $DB->_format_timestamp(time - 10), $rid);
}

sub dies_like {
    my ($code, $qr, $name) = @_;
    my $err = do { local $@; eval { $code->(); }; $@ };
    like($err, $qr, $name);
}

# --- 1. Resolution stores evidence --------------------------------------------
subtest 'resolution stores evidence' => sub {
    my $qid = mkq(prompt => 'Evidence?', by => 7);
    my $t0 = time;
    my $out = $R->resolve($qid, 7, 0);
    is($out->{outcome}, 'YES', 'fixture resolves YES');
    ok(length($out->{reasoning} // '') > 0, 'reasoning returned');
    is(scalar(@{ $out->{sources_used} }), 2, 'two sources returned');
    like($out->{resolution_id}, qr/^res_/, 'resolution id minted');
    ok(abs($out->{challenge_deadline} - ($t0 + 120 * 60)) < 120, 'default window is 2h');

    my $row = $DB->dbh->selectrow_hashref(
        'SELECT evidence_json, status FROM fc_resolutions WHERE id = ?', undef, $out->{resolution_id});
    is($row->{status}, 'proposed', 'resolution starts proposed');
    my $ev = j($row->{evidence_json});
    is($ev->{outcome}, 'YES', 'evidence carries outcome');
    ok(length($ev->{reasoning} // '') > 0, 'evidence carries reasoning');
    is(scalar(@{ $ev->{sources_used} }), 2, 'evidence carries sources');
    is($ev->{resolved_by}, 7, 'evidence carries resolver');
    ok(length($ev->{question} // '') > 0, 'evidence snapshots question');
    my $qs = $DB->dbh->selectrow_array(
        'SELECT status FROM fc_questions WHERE id = ?', undef, $qid);
    is($qs, 'resolved', 'question flips to resolved');
};

# --- 2. Resolve guards ---------------------------------------------------------
subtest 'resolve guards' => sub {
    my $future = mkq(prompt => 'Future?', by => 7, date => $DB->_format_timestamp(time + 86400));
    dies_like(sub { $R->resolve($future, 7, 0) }, qr/^FC:too_early:/, 'future date refused');
    my $stranger = mkq(prompt => 'Stranger?', by => 7);
    dies_like(sub { $R->resolve($stranger, 8, 0) }, qr/^FC:not_authorized:/, 'non-author refused');
    my $draft = mkq(prompt => 'Draft?', by => 7, status => 'draft');
    dies_like(sub { $R->resolve($draft, 7, 0) }, qr/^FC:question_not_resolvable:/, 'draft refused');
    dies_like(sub { $R->resolve('q_nope', 7, 0) }, qr/^FC:no_such_question:/, 'unknown refused');
    my $twice = mkq(prompt => 'Twice?', by => 7);
    $R->resolve($twice, 7, 0);
    dies_like(sub { $R->resolve($twice, 7, 0) }, qr/^FC:already_resolved:/, 'double resolve refused');
    my $adm = mkq(prompt => 'Admin?', by => 7);
    my $out = $R->resolve($adm, 99, 1);
    is($out->{outcome}, 'YES', 'admin may resolve any question');
};

# --- 3. Early settlement refused -----------------------------------------------
subtest 'early settlement refused' => sub {
    my $qid = mkq(prompt => 'Early?', by => 30);
    $W->stake(31, $qid, 'YES', 100, 60);
    $W->stake(32, $qid, 'NO', 300, 40);
    $R->resolve($qid, 30, 0);
    dies_like(sub { $R->settle($qid, 30, 0) }, qr/^FC:window_open:/, 'settle inside window refused');
    is($W->balance(31), 900, 'winner balance untouched');
    is($W->balance(32), 700, 'loser balance untouched');
    my $qs = $DB->dbh->selectrow_array(
        'SELECT status FROM fc_questions WHERE id = ?', undef, $qid);
    is($qs, 'resolved', 'question stays resolved');
};

# --- 4. Challenge flags for review ---------------------------------------------
subtest 'challenge flags for review' => sub {
    my $qid = mkq(prompt => 'Challenged?', by => 40);
    $W->stake(41, $qid, 'YES', 100, 60);
    my $res = $R->resolve($qid, 40, 0);
    my $ch = $R->challenge($res->{resolution_id}, 41, 'sources look stale');
    like($ch->{challenge_id}, qr/^ch_/, 'challenge id minted');
    is($ch->{status}, 'challenged', 'filing flags challenged');
    my $row = $DB->dbh->selectrow_hashref(
        'SELECT reason, status FROM fc_challenges WHERE id = ?', undef, $ch->{challenge_id});
    is($row->{reason}, 'sources look stale', 'reason stored');
    is($row->{status}, 'open', 'challenge starts open');
    dies_like(sub { $R->settle($qid, 40, 0) }, qr/^FC:challenged:/, 'settle blocked while challenged');
    my $ch2 = $R->challenge($res->{resolution_id}, 42, 'second opinion');
    ok($ch2->{challenge_id}, 'second challenge recorded');
    my $rs = $DB->dbh->selectrow_array(
        'SELECT status FROM fc_resolutions WHERE id = ?', undef, $res->{resolution_id});
    is($rs, 'challenged', 'status stays challenged, never auto-reversed');
    dies_like(sub { $R->challenge($res->{resolution_id}, 41, '  ') },
        qr/^FC:bad_reason:/, 'blank reason refused');
    dies_like(sub { $R->challenge('res_nope', 41, 'x') },
        qr/^FC:no_such_resolution:/, 'unknown resolution refused');

    my $late = mkq(prompt => 'Late?', by => 40);
    my $rl = $R->resolve($late, 40, 0);
    force_past_deadline($rl->{resolution_id});
    dies_like(sub { $R->challenge($rl->{resolution_id}, 41, 'too late') },
        qr/^FC:window_closed:/, 'late challenge refused');
};

# --- 5. Settlement pays pro-rata -----------------------------------------------
subtest 'settlement pays pro-rata' => sub {
    my $qid = mkq(prompt => 'Payout?', by => 50);
    $W->stake(51, $qid, 'YES', 100, 60);
    $W->stake(52, $qid, 'NO', 300, 40);
    my $res = $R->resolve($qid, 50, 0);
    force_past_deadline($res->{resolution_id});
    my $s = $R->settle($qid, 50, 0);
    is($s->{outcome}, 'YES', 'outcome reported');
    is($s->{winners}, 1, 'one winner paid');
    is($s->{total_paid}, 400, 'whole pool paid out');
    is($s->{positions}, 2, 'two positions settled');
    is($W->balance(51), 1300, 'winner 1000-100+400');
    is($W->balance(52), 700, 'loser keeps 1000-300');
    my $won51 = $DB->dbh->selectrow_array(
        'SELECT won FROM fc_positions WHERE question_id = ? AND user_id = 51', undef, $qid);
    my $won52 = $DB->dbh->selectrow_array(
        'SELECT won FROM fc_positions WHERE question_id = ? AND user_id = 52', undef, $qid);
    is($won51, 1, 'winner marked won');
    is($won52, 0, 'loser marked lost');
    my $q = $DB->dbh->selectrow_hashref(
        'SELECT status FROM fc_questions WHERE id = ?', undef, $qid);
    is($q->{status}, 'settled', 'question settled');
    my $r = $DB->dbh->selectrow_hashref(
        'SELECT status, settled_at FROM fc_resolutions WHERE id = ?', undef, $res->{resolution_id});
    is($r->{status}, 'settled', 'resolution settled');
    ok(defined $r->{settled_at}, 'settled_at stamped');
    dies_like(sub { $R->settle($qid, 50, 0) }, qr/^FC:already_settled:/, 'double settle refused');
};

# --- 6. Brier updates ----------------------------------------------------------
subtest 'brier updates' => sub {
    my $rep51 = $R->reputation(51);
    is($rep51->{won}, 1, 'winner has one win');
    is($rep51->{lost}, 0, 'winner has no losses');
    is($rep51->{brier}, 0.16, 'winner brier (0.6-1)^2');
    my $rep52 = $R->reputation(52);
    is($rep52->{won}, 0, 'loser has no wins');
    is($rep52->{lost}, 1, 'loser has one loss');
    is($rep52->{brier}, 0.36, 'loser brier (0.6-0)^2');
    my $rep_new = $R->reputation(999);
    is($rep_new->{won}, 0, 'unknown user zero wins');
    is($rep_new->{lost}, 0, 'unknown user zero losses');
    ok(!defined $rep_new->{brier}, 'unknown user brier undef');

    # Second settlement recomputes from scratch across questions.
    my $q2 = mkq(prompt => 'Second?', by => 50);
    $W->stake(51, $q2, 'NO', 50, 30);
    $W->stake(52, $q2, 'YES', 50, 30);
    my $res2 = $R->resolve($q2, 50, 0);
    force_past_deadline($res2->{resolution_id});
    $R->settle($q2, 50, 0);
    my $r51 = $R->reputation(51);
    is($r51->{won}, 1, 'user 51 still one win');
    is($r51->{lost}, 1, 'user 51 now one loss');
    is($r51->{brier}, 0.325, 'user 51 brier mean of 0.16, 0.49');
    my $r52 = $R->reputation(52);
    is($r52->{won}, 1, 'user 52 now one win');
    is($r52->{lost}, 1, 'user 52 still one loss');
    is($r52->{brier}, 0.425, 'user 52 brier mean of 0.36, 0.49');
    is($W->balance(51), 1250, 'user 51 lost second stake');
    is($W->balance(52), 750, 'user 52 won second pool');
};

# --- 7. VOID refunds -----------------------------------------------------------
subtest 'void refunds stakes, skips reputation' => sub {
    my $qid = mkq(prompt => 'Void?', by => 60);
    $W->stake(61, $qid, 'YES', 100, 50);
    $W->stake(62, $qid, 'NO', 200, 50);
    my $res = $R->resolve($qid, 60, 0);
    $DB->dbh->do("UPDATE fc_resolutions SET outcome = 'VOID' WHERE id = ?", undef, $res->{resolution_id});
    force_past_deadline($res->{resolution_id});
    my $s = $R->settle($qid, 60, 0);
    is($s->{outcome}, 'VOID', 'void reported');
    is($s->{total_paid}, 300, 'all stakes refunded');
    is($W->balance(61), 1000, 'user 61 fully refunded');
    is($W->balance(62), 1000, 'user 62 fully refunded');
    my $n = $DB->dbh->selectrow_array(
        'SELECT COUNT(*) FROM fc_reputation WHERE user_id IN (61, 62)');
    is($n, 0, 'void carries no reputation signal');
};

# --- 8. Configurable window ----------------------------------------------------
subtest 'challenge window is configurable' => sub {
    local $ENV{FORECAST_CHALLENGE_MINUTES} = '5';
    my $r5 = FB::Fc::Resolution->new(db => $DB, wallet => $W);
    is($r5->challenge_window_minutes, 5, 'demo window reads env');
    my $qid = mkq(prompt => 'Demo?', by => 70);
    my $t0 = time;
    my $out = $r5->resolve($qid, 70, 0);
    ok(abs($out->{challenge_deadline} - ($t0 + 300)) < 90, 'deadline is ~5 minutes out');
    local $ENV{FORECAST_CHALLENGE_MINUTES} = 'abc';
    my $rbad = FB::Fc::Resolution->new(db => $DB, wallet => $W);
    is($rbad->challenge_window_minutes, 120, 'bad value falls back to 120');
};

# --- 9. Migration ----------------------------------------------------------------
subtest 'migrates pre-session-3 databases' => sub {
    my $tmp2 = tempdir(CLEANUP => 1);
    my $old = schema_sql('fc.schema');
    my $status_line = "    status TEXT NOT NULL DEFAULT 'proposed' CHECK (status IN ('proposed', 'challenged', 'settled')),\n";
    my $won_tail = ",\n    won INTEGER CHECK (won IN (0, 1))";
    is(scalar($old =~ s/\Q$status_line\E//), 1, 'strip status for old shape');
    is(scalar($old =~ s/\Q$won_tail\E//), 1, 'strip won for old shape');
    apply_sql($tmp2, schema_sql('fb.schema'));
    apply_sql($tmp2, $old);
    require DBI;
    my $dbh2 = DBI->connect("dbi:SQLite:dbname=$tmp2/fb.db", '', '', { RaiseError => 1, AutoCommit => 1 });
    $dbh2->do("INSERT INTO fc_questions (id, prompt, status) VALUES ('oq', 'Old?', 'resolved')");
    $dbh2->do("INSERT INTO fc_resolutions (id, question_id, outcome) VALUES ('ores', 'oq', 'YES')");
    $dbh2->do("INSERT INTO fc_positions (id, question_id, user_id, side, stake, price_at_entry, created_at)"
        . " VALUES ('opos', 'oq', 5, 'YES', 10, 50, 'x')");
    local $ENV{SQLITE_PATH} = $tmp2;
    my $db2 = FB::Db->new;
    is(FB::Fc::Wallet->ensure_schema($db2), 1, 'ensure runs on old database');
    my @rcols = map { $_->[1] } @{ $dbh2->selectall_arrayref('PRAGMA table_info(fc_resolutions)') };
    ok(grep(/^status$/, @rcols), 'status column added');
    my @pcols = map { $_->[1] } @{ $dbh2->selectall_arrayref('PRAGMA table_info(fc_positions)') };
    ok(grep(/^won$/, @pcols), 'won column added');
    my @tables = @{ $dbh2->selectcol_arrayref(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'fc_reputation'") };
    is(scalar(@tables), 1, 'reputation table created');
    my $st = $dbh2->selectrow_array("SELECT status FROM fc_resolutions WHERE id = 'ores'");
    is($st, 'proposed', 'old row backfills to proposed');
    is(FB::Fc::Wallet->ensure_schema($db2), 1, 'ensure is idempotent');
};

# --- 10. Record shape -----------------------------------------------------------
subtest 'resolution record shape' => sub {
    my $qid = mkq(prompt => 'Record?', by => 80);
    is($R->get_resolution_for_question($qid), undef, 'open question has no resolution');
    is($R->get_resolution_record('res_nope'), undef, 'unknown record is undef');
    $W->stake(81, $qid, 'YES', 100, 60);
    my $res = $R->resolve($qid, 80, 0);
    $R->challenge($res->{resolution_id}, 81, 'needs review');
    force_past_deadline($res->{resolution_id});
    # Challenged: settle stays blocked; record still renders.
    dies_like(sub { $R->settle($qid, 80, 0) }, qr/^FC:challenged:/, 'challenged settle blocked');
    my $rec = $R->get_resolution_record($res->{resolution_id});
    is($rec->{outcome}, 'YES', 'record outcome');
    is($rec->{status}, 'challenged', 'record status');
    ok(length($rec->{reasoning} // '') > 0, 'record reasoning');
    is(scalar(@{ $rec->{sources_used} }), 2, 'record sources');
    is($rec->{question_id}, $qid, 'record question link');
    ok(length($rec->{prompt} // '') > 0, 'record prompt');
    ok($rec->{resolved_at} > 0, 'record resolved_at epoch');
    ok($rec->{challenge_deadline} > 0, 'record deadline epoch');
    ok(!defined $rec->{settled_at}, 'record unsettled');
    is(scalar(@{ $rec->{challenges} }), 1, 'record lists challenge');
    is($rec->{challenges}[0]{user_id}, 81, 'challenge user');
    is($rec->{challenges}[0]{reason}, 'needs review', 'challenge reason');
    my $row = $R->get_resolution_for_question($qid);
    is($row->{id}, $res->{resolution_id}, 'question maps to resolution');
};

# --- 11. Endpoint wiring ---------------------------------------------------------
{
    package FakeTx4;
    sub new { my ($c, %a) = @_; bless { sent => [], finished => 0, conn => 'x', %a }, $c }
    sub connection     { shift->{conn} }
    sub remote_address { '127.0.0.1' }
    sub send           { push @{shift->{sent}}, shift }
    sub finish         { shift->{finished} = 1 }
    sub is_finished    { shift->{finished} }
    sub is_websocket   { 1 }
    sub sent_msgs { map { Mojo::JSON::j($_) } @{shift->{sent}} }
}

sub find_msg4 {
    my ($tx, $key) = @_;
    for my $m ($tx->sent_msgs) {
        return $m->[1] if ref $m eq 'ARRAY' && $m->[0] eq $key;
    }
    return;
}

subtest 'endpoint wiring' => sub {
    require FB;
    my $fb = FB->new(address_block => {}, facebook_secret => 'test');
    my $atx = FakeTx4->new(conn => 'au1');
    my $au = $fb->_guest_login({ websocket => $atx });
    $fb->request($au, ['guest_login']);
    my $qid = $fb->fc_wallet->create_question({
        prompt => 'Wired?', resolution_criteria => 'c',
        resolution_date => $fb->db->_format_timestamp(time - 100),
        status => 'open', created_by => $au->user->id });

    $fb->request($au, ['fc_resolve', { question_id => $qid }]);
    my $rz = find_msg4($atx, 'fc_resolve_res');
    ok($rz && $rz->{success} && $rz->{outcome} eq 'YES', 'author resolves over WS');
    my $rid = $rz->{resolution_id};

    my $gtx = FakeTx4->new(conn => 'g9');
    my $gu = $fb->_guest_login({ websocket => $gtx });
    $fb->request($gu, ['guest_login']);
    $fb->request($gu, ['fc_challenge', { resolution_id => $rid, reason => 'stale sources' }]);
    my $ch = find_msg4($gtx, 'fc_challenge_res');
    ok($ch && $ch->{success}, 'level-2 session files challenge');

    $fb->request($au, ['fc_settle', { question_id => $qid }]);
    my $st = find_msg4($atx, 'fc_settle_res');
    ok($st && !$st->{success} && $st->{reason} eq 'challenged', 'settle blocked while challenged');

    $fb->request($gu, ['fc_record', { question_id => $qid }]);
    my $rc = find_msg4($gtx, 'fc_record_res');
    ok($rc && $rc->{success} && @{ $rc->{record}{challenges} } == 1, 'public record shows challenge');

    $fb->request($gu, ['fc_reputation']);
    my $rp = find_msg4($gtx, 'fc_reputation_res');
    ok($rp && $rp->{success} && $rp->{won} == 0, 'reputation endpoint answers');

    $gu->user->level(0);
    $fb->request($gu, ['fc_challenge', { resolution_id => $rid, reason => 'x' }]);
    my ($denied) = grep { $_->[0] eq 'permission_denied' } $gtx->sent_msgs;
    ok($denied, 'level-0 session denied challenge');
};

# --- 12. Record route --------------------------------------------------------------
subtest 'record route' => sub {
    require Ships;
    my $app = Ships->new;
    $app->log->level('fatal');
    my $get = sub {
        my ($path) = @_;
        my $tx = Mojo::Transaction::HTTP->new;
        $tx->req->method('GET');
        $tx->req->url->parse($path);
        $tx->remote_address('127.0.0.1');
        $app->handler($tx);
        return ($tx->res, $tx);
    };
    my ($res, undef) = $get->('/forecast/record/res_abc123');
    is($res->code, 200, 'GET record page renders');
    like($res->body // '', qr/id="fc-record"/, 'page has record container');
    like($res->body // '', qr/res_abc123/, 'page carries the id');
    like($res->body // '', qr/forecast_record\.js/, 'page loads record client');
    my ($bad, undef) = $get->('/forecast/record/a!b');
    is($bad->code, 302, 'bad id redirects');
    like($bad->headers->location // '', qr{/forecast$}, 'redirect targets forecast');
};

done_testing();
