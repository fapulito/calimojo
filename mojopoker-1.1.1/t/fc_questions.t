#!/usr/bin/env perl
# Copyright (C) 2026, California Vision
# Forecast question loop tests (Session 2). Play money only.
#
# Covers fixture-mode draft generation, the approve/reject flow, and
# parimutuel staking through the Session 1 wallet, at both service level
# and through the websocket command endpoints.
#
# Hermetic: scratch SQLite db; FORECAST_FIXTURE=1 (no network, no API key).
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
local $ENV{FORECAST_FIXTURE} = '1';
delete local $ENV{DATABASE_URL};

sub apply_schema {
    my ($file) = @_;
    my $path = File::Spec->catfile($FindBin::Bin, '..', 'db', $file);
    open my $fh, '<', $path or die "open $path: $!";
    local $/;
    my $sql = <$fh>;
    close $fh;
    require DBI;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$TMP/fb.db", '', '',
        { RaiseError => 1, AutoCommit => 1 });
    for my $stmt (split /;\s*\n/, $sql) {
        $stmt =~ s/^\s+|\s+$//g;
        next unless length $stmt;
        $dbh->do($stmt);
    }
}
apply_schema('fb.schema');
apply_schema('fc.schema');

sub read_fixture {
    my ($file) = @_;
    my $path = File::Spec->catfile($FindBin::Bin, '..', 'fixtures', $file);
    open my $fh, '<', $path or die "open $path: $!";
    local $/;
    my $data = j(scalar <$fh>);
    close $fh;
    return $data;
}

use FB::Db;
use FB::Fc::Model;
use FB::Fc::Questions;

{
    package FakeTx3;
    sub new { my ($c, %a) = @_; bless { sent => [], finished => 0, conn => 'x', %a }, $c }
    sub connection     { shift->{conn} }
    sub remote_address { '127.0.0.1' }
    sub send           { push @{shift->{sent}}, shift }
    sub finish         { shift->{finished} = 1 }
    sub is_finished    { shift->{finished} }
    sub is_websocket   { 1 }
    sub sent_msgs { map { Mojo::JSON::j($_) } @{shift->{sent}} }
}

sub find_msg {
    my ($tx, $key) = @_;
    for my $m ($tx->sent_msgs) {
        return $m->[1] if ref $m eq 'ARRAY' && $m->[0] eq $key;
    }
    return;
}

my @HEADLINES = (
    'Federal Reserve holds benchmark rate steady, signals one cut before year-end',
    'EV battery plant milestone promises sub-$80 per kWh cells next year',
    'Summer box office tops five billion in strongest season since 2019',
    'Forecasters predict above-average Atlantic hurricane season with six major storms',
);

# --- 1. Headlines fixture ------------------------------------------------------
subtest 'headlines fixture is non-sports' => sub {
    my $h = read_fixture('fc_headlines.json');
    for my $t (qw(economics tech culture weather)) {
        ok(ref $h->{$t} eq 'ARRAY' && @{$h->{$t}} >= 3, "topic $t has headlines");
    }
    my $all = j($h);
    unlike($all, qr/\b(football|basketball|baseball|soccer|tennis|golf|olympics?|super\s?bowl|world\s?cup|\bnfl\b|\bnba\b|\bmlb\b|\bnhl\b|wimbledon|champions\sleague|touchdown|home\srun|grand\sslam)\b/i,
        'no sports content');
};

# --- 2. Draft generation in fixture mode ----------------------------------------
subtest 'draft generation in fixture mode' => sub {
    my $m = FB::Fc::Model->new;
    ok($m->is_fixture, 'fixture mode active');
    my $db = FB::Db->new;
    my $q = FB::Fc::Questions->new(db => $db, model => $m);
    my $ids = $q->generate_from_headlines(\@HEADLINES, 42);
    my $fix = read_fixture('fc_draft_questions.json');
    is(scalar @$ids, scalar @{$fix->{drafts}}, 'one draft per canned entry');
    ok(scalar @$ids >= 2, 'one headline set produces >= 2 drafts');
    my $row = $db->dbh->selectrow_hashref(
        'SELECT prompt, resolution_criteria, resolution_date, status, created_by, source_snapshot, resolution_source, source_ref, settlement_rule FROM fc_questions WHERE id = ?',
        undef, $ids->[0]);
    is($row->{prompt}, $fix->{drafts}[0]{prompt}, 'draft prompt matches fixture');
    ok(length($row->{resolution_criteria} // ''), 'criteria present');
    like($row->{resolution_date} // '', qr/^\d{4}-\d{2}-\d{2}$/, 'date is ISO');
    is($row->{status}, 'draft', 'drafts land as draft');
    is($row->{created_by}, 42, 'creator recorded');
    like($row->{source_snapshot} // '', qr/Federal Reserve/, 'headlines snapshotted');
    is($row->{resolution_source}, $fix->{drafts}[0]{resolution_source}, 'settlement source persisted');
    is($row->{source_ref}, $fix->{drafts}[0]{source_ref}, 'settlement ref persisted');
    is($row->{settlement_rule}, $fix->{drafts}[0]{settlement_rule}, 'settlement rule persisted');
    my $err = do { local $@; eval { $q->generate_from_headlines(['only one'], 42) }; $@ };
    like($err, qr/^FC:bad_headlines:/, 'fewer than 3 headlines rejected');
};

# --- 3. Approve / reject flow -----------------------------------------------------
subtest 'approve flow' => sub {
    my $db = FB::Db->new;
    my $q = FB::Fc::Questions->new(db => $db);
    my $ids = $q->generate_from_headlines(\@HEADLINES, 42);
    ok($q->approve($ids->[0]), 'approve ok');
    is($q->get($ids->[0])->{status}, 'open', 'draft -> open');
    my $err = do { local $@; eval { $q->approve($ids->[0]) }; $@ };
    like($err, qr/^FC:not_draft:/, 're-approve refused');
    ok($q->reject($ids->[1]), 'reject ok');
    is($q->get($ids->[1])->{status}, 'void', 'draft -> void');
    $err = do { local $@; eval { $q->approve('q_missing') }; $@ };
    like($err, qr/^FC:no_such_question:/, 'missing question refused');
};

# --- 4. Stake updates implied probability ------------------------------------------
subtest 'stake moves parimutuel probability' => sub {
    require FB;
    my $fb = FB->new(address_block => {}, facebook_secret => 'test');
    my $tx = FakeTx3->new(conn => 's1');
    my $g = $fb->_guest_login({ websocket => $tx });
    $fb->request($g, ['guest_login']);
    my $qid = $fb->fc_questions->generate_from_headlines(\@HEADLINES, 1)->[0];
    $fb->fc_questions->approve($qid);
    my $p0 = $fb->fc_questions->implied_prob($qid);
    is($p0->{prob_yes}, 50, 'empty question shows 50/50');

    $fb->request($g, ['fc_stake', { question_id => $qid, side => 'YES', stake => 100 }]);
    my $r1 = find_msg($tx, 'fc_stake_res');
    ok($r1 && $r1->{success}, 'YES stake succeeds');
    is($r1->{price}, 50, 'price is the displayed pre-stake probability');
    is($r1->{balance}, 900, 'wallet balance drops by the stake');
    is($r1->{question}{prob_yes}, 75, 'YES stake moves probability to 75');
    is($r1->{question}{yes_total}, 100, 'YES total recorded');

    $fb->request($g, ['fc_stake', { question_id => $qid, side => 'NO', stake => 100 }]);
    my @rs = grep { $_->[0] eq 'fc_stake_res' } $tx->sent_msgs;
    my $r2 = $rs[-1][1];
    ok($r2->{success}, 'NO stake succeeds');
    is($r2->{price}, 25, 'NO price was the displayed 25');
    is($r2->{question}{prob_yes}, 50, 'market returns to 50/50');
    is($fb->fc_wallet->balance($g->user->id), 800, 'both stakes debited');

    $fb->request($g, ['fc_stake', { question_id => $qid, side => 'YES', stake => 5000 }]);
    @rs = grep { $_->[0] eq 'fc_stake_res' } $tx->sent_msgs;
    is($rs[-1][1]{reason}, 'insufficient_balance', 'over-stake rejected at endpoint');
};

# --- 5. Endpoint wiring: list / generate / moderate -------------------------------
subtest 'endpoint wiring' => sub {
    require FB;
    my $fb = FB->new(address_block => {}, facebook_secret => 'test');
    my $admin_tx = FakeTx3->new(conn => 'a1');
    my $admin = $fb->_guest_login({ websocket => $admin_tx });
    $admin->user->level(4);
    my $guest_tx = FakeTx3->new(conn => 'g1');
    my $guest = $fb->_guest_login({ websocket => $guest_tx });
    $fb->request($guest, ['guest_login']);

    $fb->request($admin, ['fc_generate', { topic => 'tech', count => 3 }]);
    my $gen = find_msg($admin_tx, 'fc_generate_res');
    ok($gen && $gen->{success} && @{$gen->{draft_ids} || []} >= 2, 'admin generate makes drafts');

    $fb->request($guest, ['fc_generate', {}]);
    my ($denied) = grep { $_->[0] eq 'permission_denied' } $guest_tx->sent_msgs;
    ok($denied, 'guest cannot generate');

    my $did = $gen->{draft_ids}[0];
    $fb->request($guest, ['fc_list']);
    my $open = find_msg($guest_tx, 'fc_list_res');
    ok($open && $open->{success}, 'guest lists open questions');
    ok(!grep({ $_->{id} eq $did } @{$open->{questions}}), 'draft hidden from open list');

    $fb->request($guest, ['fc_list', { status => 'draft' }]);
    ($denied) = grep { $_->[0] eq 'permission_denied' } $guest_tx->sent_msgs;
    ok($denied, 'guest cannot list drafts');

    $fb->request($admin, ['fc_list', { status => 'draft' }]);
    my $drafts = find_msg($admin_tx, 'fc_list_res');
    ok($drafts && $drafts->{success} && grep({ $_->{id} eq $did } @{$drafts->{questions}}),
        'admin sees draft queue');

    $fb->request($guest, ['fc_approve', { question_id => $did }]);
    ($denied) = grep { $_->[0] eq 'permission_denied' } $guest_tx->sent_msgs;
    ok($denied, 'guest cannot approve');

    $fb->request($admin, ['fc_approve', { question_id => $did }]);
    my $ap = find_msg($admin_tx, 'fc_approve_res');
    ok($ap && $ap->{success} && $ap->{status} eq 'open', 'admin approve opens');

    $fb->request($guest, ['fc_list']);
    my @lists = grep { $_->[0] eq 'fc_list_res' } $guest_tx->sent_msgs;
    my ($now) = grep { $_->{id} eq $did } @{$lists[-1][1]{questions}};
    ok($now && $now->{prob_yes} == 50, 'approved question listed at 50/50');
};

# --- 6. Forecast page route ---------------------------------------------------------
subtest 'forecast route and nav link' => sub {
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
        return $tx->res;
    };
    my $fc = $get->('/forecast');
    is($fc->code, 200, 'GET /forecast renders');
    like($fc->body // '', qr/id="fc-open"/, 'page has questions container');
    like($fc->body // '', qr/forecast\.js/, 'page loads forecast.js');
    my $main = $get->('/');
    like($main->body // '', qr/href="forecast"/, 'poker UI links to forecast');
};

# --- 7. Live-mode configuration (no network) ----------------------------------------
subtest 'live mode config without network' => sub {
    {
        local $ENV{FORECAST_FIXTURE};
        local $ENV{MODEL_API_KEY} = 'test-key-123';
        delete local $ENV{META_MODEL_API_KEY};
        delete local $ENV{MODEL_API_BASE_URL};
        delete local $ENV{MODEL_API_MODEL};
        my $m = FB::Fc::Model->new;
        ok(!$m->is_fixture, 'fixture off without FORECAST_FIXTURE');
        is($m->api_key, 'test-key-123', 'canonical MODEL_API_KEY read');
        is($m->api_base_url, 'https://api.meta.ai/v1', 'default base URL');
        is($m->model, 'muse-spark-1.3', 'default model');
    }
    {
        local $ENV{FORECAST_FIXTURE};
        delete local $ENV{MODEL_API_KEY};
        local $ENV{META_MODEL_API_KEY} = 'alias-key';
        my $m = FB::Fc::Model->new;
        is($m->api_key, 'alias-key', 'META_MODEL_API_KEY alias works');
    }
    {
        local $ENV{FORECAST_FIXTURE};
        local $ENV{MODEL_API_KEY} = 'k';
        local $ENV{MODEL_API_BASE_URL} = 'https://x.test/v9';
        local $ENV{MODEL_API_MODEL} = 'custom-1';
        my $m = FB::Fc::Model->new;
        is($m->api_base_url, 'https://x.test/v9', 'base URL overridable');
        is($m->model, 'custom-1', 'model overridable');
    }
    {
        local $ENV{FORECAST_FIXTURE};
        delete local $ENV{MODEL_API_KEY};
        delete local $ENV{META_MODEL_API_KEY};
        my $m = FB::Fc::Model->new;
        my $err = do { local $@; eval { $m->generate('draft_questions', { headlines => ['a', 'b', 'c'] }) }; $@ };
        like($err, qr/^FC:no_api_key:/, 'live without key fails before network');
    }
};

done_testing();
