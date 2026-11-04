#!/usr/bin/env perl
# Copyright (C) 2026, California Vision
# Forecasting play-token wallet tests (Session 1). Play money only.
#
# Covers FB::Fc::Wallet: idempotent daily allotment, balance carryover,
# staking debits, over-stake/closed-question rejection, the absence of any
# purchase/transfer/cash-out path, and the FB session wiring (allotment on
# authenticated requests + fc_balance in session responses).
#
# Hermetic: scratch SQLite db built from db/fb.schema + db/fc.schema.
use strict;
use warnings;
$| = 1;
use Test::More;
use FindBin;
use File::Temp qw(tempdir);
use File::Spec;
use lib "$FindBin::Bin/../lib";
use Mojo::JSON ();

our $TMP = tempdir(CLEANUP => 1);
local $ENV{DATABASE_TYPE} = 'sqlite';
local $ENV{SQLITE_PATH} = $TMP;
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

use FB::Db;
use FB::Fc::Wallet;

# --- 1. Daily allotment is idempotent ----------------------------------------
subtest 'allotment is idempotent' => sub {
    my $w = FB::Fc::Wallet->new(db => FB::Db->new);
    my $r1 = $w->ensure_allotted(7, '2026-11-04');
    is($r1->{granted}, 1000, 'first touch grants 1000');
    is($r1->{balance}, 1000, 'balance is 1000');
    my $r2 = $w->ensure_allotted(7, '2026-11-04');
    is($r2->{granted}, 0, 'second touch same day grants nothing');
    is($r2->{balance}, 1000, 'balance unchanged');
    my $row = $w->db->dbh->selectrow_hashref(
        'SELECT allotted, balance FROM fc_wallet_daily WHERE user_id = 7 AND date = ?',
        undef, '2026-11-04');
    is($row->{allotted}, 1000, 'row records a single allotment');
    is($row->{balance}, 1000, 'row balance is 1000');
    my $n = $w->db->dbh->selectrow_array(
        'SELECT COUNT(*) FROM fc_wallet_daily WHERE user_id = 7 AND date = ?',
        undef, '2026-11-04');
    is($n, 1, 'exactly one row per user per day');
};

# --- 2. Balance carries forward across days -----------------------------------
subtest 'balance carries across days' => sub {
    my $w = FB::Fc::Wallet->new(db => FB::Db->new);
    $w->ensure_allotted(8, '2026-11-04');
    my $q = $w->create_question({ prompt => 'Carry?', status => 'open' });
    $w->stake(8, $q, 'YES', 200, 55);
    is($w->balance(8), 800, 'day 1 balance after stake');
    my $r = $w->ensure_allotted(8, '2026-11-05');
    is($r->{granted}, 1000, 'day 2 grants again');
    is($r->{balance}, 1800, 'day 2 starts at prior balance + 1000');
    is($w->balance(8), 1800, 'balance() tracks latest row');
};

# --- 3. Staking debits correctly ----------------------------------------------
subtest 'stake debits and records position' => sub {
    my $w = FB::Fc::Wallet->new(db => FB::Db->new);
    $w->ensure_allotted(9, '2026-11-04');
    my $q = $w->create_question({
        prompt => 'Will it rain?', resolution_criteria => 'Airport gauge > 0',
        resolution_date => '2026-11-10', created_by => 9,
    });
    my $pid = $w->stake(9, $q, 'NO', 250, 40);
    ok($pid, 'stake returns a position id');
    my $pos = $w->db->dbh->selectrow_hashref(
        'SELECT question_id, user_id, side, stake, price_at_entry FROM fc_positions WHERE id = ?',
        undef, $pid);
    is($pos->{question_id}, $q, 'position references question');
    is($pos->{user_id}, 9, 'position references user');
    is($pos->{side}, 'NO', 'side recorded');
    is($pos->{stake}, 250, 'stake recorded');
    is($pos->{price_at_entry}, 40, 'price recorded');
    is($w->balance(9), 750, 'wallet debited by the stake');
};

# --- 4. Over-stake is rejected -------------------------------------------------
subtest 'over-stake is rejected' => sub {
    my $w = FB::Fc::Wallet->new(db => FB::Db->new);
    $w->ensure_allotted(10, '2026-11-04');
    my $q = $w->create_question({ prompt => 'Expensive?', status => 'open' });
    my $err = do { local $@; eval { $w->stake(10, $q, 'YES', 5000, 50) }; $@ };
    like($err, qr/^FC:insufficient_balance:/, 'over-stake dies insufficient_balance');
    is($w->balance(10), 1000, 'balance untouched');
    my $n = $w->db->dbh->selectrow_array(
        'SELECT COUNT(*) FROM fc_positions WHERE user_id = 10');
    is($n, 0, 'no position recorded');
};

# --- 5. Invalid stakes are rejected --------------------------------------------
subtest 'invalid stakes rejected' => sub {
    my $w = FB::Fc::Wallet->new(db => FB::Db->new);
    $w->ensure_allotted(11, '2026-11-04');
    my $q = $w->create_question({ prompt => 'Valid?', status => 'open' });
    for my $case (
        [11, $q, 'MAYBE', 10, 50, 'invalid_side'],
        [11, $q, 'YES', 0, 50, 'invalid_stake'],
        [11, $q, 'YES', -5, 50, 'invalid_stake'],
        [11, $q, 'YES', 10, 101, 'invalid_price'],
        [11, 'q_missing', 'YES', 10, 50, 'no_such_question'],
    ) {
        my ($u, $qid, $side, $stake, $price, $code) = @$case;
        my $err = do { local $@; eval { $w->stake($u, $qid, $side, $stake, $price) }; $@ };
        like($err, qr/^FC:$code:/, "$code rejected");
    }
    $w->db->dbh->do("UPDATE fc_questions SET status = 'settled' WHERE id = ?", undef, $q);
    my $err = do { local $@; eval { $w->stake(11, $q, 'YES', 10, 50) }; $@ };
    like($err, qr/^FC:question_not_open:/, 'settled question rejected');
    is($w->balance(11), 1000, 'balance untouched by rejections');
};

# --- 6. No purchase / transfer / cash-out path ----------------------------------
subtest 'no purchase, transfer, or cash-out' => sub {
    for my $m (qw(purchase buy_tokens transfer send_tokens gift cash_out cashout redeem withdraw deposit)) {
        ok(!FB::Fc::Wallet->can($m), "no $m method");
    }
};

# --- 7. FB session wiring -------------------------------------------------------
{
    package FakeTx2;
    sub new { my ($c, %a) = @_; bless { sent => [], finished => 0, conn => 'x', %a }, $c }
    sub connection     { shift->{conn} }
    sub remote_address { '127.0.0.1' }
    sub send           { push @{shift->{sent}}, shift }
    sub finish         { shift->{finished} = 1 }
    sub is_finished    { shift->{finished} }
    sub is_websocket   { 1 }
    sub sent_msgs { map { Mojo::JSON::j($_) } @{shift->{sent}} }
}

subtest 'allotment hook and fc_balance in session API' => sub {
    require FB;
    my $fb = FB->new(address_block => {}, facebook_secret => 'test');
    my @tables = @{ $fb->db->dbh->selectcol_arrayref(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'fc\_%' ESCAPE '\\'") };
    is(scalar(@tables), 6, 'boot pre-warms all 6 fc tables');

    my $tx = FakeTx2->new(conn => 'w1');
    my $g = $fb->_guest_login({ websocket => $tx });
    $fb->request($g, ['guest_login']);
    my ($gl) = grep { $_->[0] eq 'guest_login' } $tx->sent_msgs;
    ok($gl && $gl->[1]{success}, 'guest_login succeeds');
    is($gl->[1]{fc_balance}, 1000, 'guest_login carries fc_balance');
    is($fb->fc_wallet->balance($g->user->id), 1000, 'hook allotted on first request');

    $fb->request($g, ['register', { username => 'wuser', password => 'pw1234',
        email => 'al@xy.com', handle => 'wuser' }]);
    my ($rr) = grep { $_->[0] eq 'register_res' } $tx->sent_msgs;
    ok($rr && $rr->[1]{success}, 'register succeeds');
    is($rr->[1]{fc_balance}, 1000, 'register_res carries fc_balance');

    $fb->request($g, ['login_info']);
    my ($li) = grep { $_->[0] eq 'login_info_res' } $tx->sent_msgs;
    is($li->[1]{fc_balance}, 1000, 'login_info_res carries fc_balance');
};

done_testing();
