#!/usr/bin/env perl
# Login identity + persistence regression tests (player login flow).
#
# Covers the canonical Perl WebSocket login (Ships + FB.pm):
#  - new_user persists bookmark/username/level at creation (login_book round-trip)
#  - guest_login response carries username + bookmark
#  - register/authorize upgrade the auto-attached guest (no false "Already registered")
#  - failed login_book keeps the guest session alive
#  - update_profile persists name/avatar; logout detaches but keeps the socket
#  - Compat::Timer returns a Handle on every backend (+ cancel_timer exists)
#  - Ships rate limiting: HTTP 429 for app requests, static excluded, opt-out works
#
# Hermetic: builds a scratch SQLite db from db/fb.schema under File::Temp.
# No sockets, no Facebook, no PostgreSQL.
use strict;
use warnings;
$| = 1;   # stream TAP (a hang shows exactly where)
use Test::More;
use FindBin;
use File::Temp qw(tempdir);
use File::Spec;
use lib "$FindBin::Bin/../lib";

use Mojo::JSON qw(j);
use Digest::SHA qw(hmac_sha256);
use MIME::Base64 qw(encode_base64);

# --- Scratch database (localized for the whole file) -----------------------
our $TMP = tempdir(CLEANUP => 1);
our ($RESTART_UID, $RESTART_BOOK);   # carried from the flow subtest to the restart subtest
local $ENV{DATABASE_TYPE} = 'sqlite';
local $ENV{SQLITE_PATH} = $TMP;
delete local $ENV{DATABASE_URL};

sub build_schema {
    my $schema = File::Spec->catfile($FindBin::Bin, '..', 'db', 'fb.schema');
    open my $fh, '<', $schema or die "open $schema: $!";
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
    return $dbh;
}
build_schema();

use FB;
use FB::Db;
use FB::User;
use FB::Compat::Timer;

# --- Capturing fake websocket ----------------------------------------------
{
    package FakeTx;
    sub new {
        my ($class, %a) = @_;
        return bless { sent => [], finished => 0, conn => 'x', %a }, $class;
    }
    sub connection     { shift->{conn} }
    sub remote_address { '127.0.0.1' }
    sub send           { push @{shift->{sent}}, shift; }
    sub finish         { shift->{finished} = 1; }
    sub is_finished    { shift->{finished} }
    sub is_websocket   { 1 }
    sub sent_msgs {
        my $self = shift;
        return map { Mojo::JSON::j($_) } @{$self->{sent}};
    }
}

sub find_msg {
    my ($tx, $key) = @_;
    for my $m ($tx->sent_msgs) {
        return $m->[1] if ref $m eq 'ARRAY' && $m->[0] eq $key;
    }
    return;
}

sub fb_signed_request {
    my ($fbid, $secret) = @_;
    my $payload_b64 = encode_base64(j({ user_id => $fbid, algorithm => 'HMAC-SHA256' }), '');
    my $sig = encode_base64(hmac_sha256($payload_b64, $secret), '');
    $sig =~ tr[+/][-_];
    $sig =~ s/=+$//;
    return "$sig.$payload_b64";
}

# --- 1. new_user persists identity at creation ------------------------------
subtest 'new_user persists bookmark/username/level' => sub {
    my $db = FB::Db->new;
    my $guest = $db->new_user({ chips => 400, invested => 400 });
    ok($guest && $guest->id, 'guest user created');
    like($guest->bookmark // '', qr/^[0-9a-f]{40}$/, 'guest bookmark is 40-hex');
    is($guest->level, 2, 'guest level is 2');

    # Fresh read from disk (new handle state): identity must round-trip.
    my $by_id = $db->fetch_user({ id => $guest->id });
    ok($by_id, 'guest re-fetched by id');
    is($by_id->username, 'Guest' . $guest->id, 'guest username persisted');
    is($by_id->level, 2, 'guest level persisted');
    is($by_id->bookmark, $guest->bookmark, 'guest bookmark persisted');

    my $by_book = $db->fetch_user({ bookmark => $guest->bookmark });
    ok($by_book && $by_book->id == $guest->id, 'login_book lookup round-trips');

    my $named = $db->new_user({ username => 'testreg1', password => 'x',
        email => 'al@xy.com', handle => 'testreg1', chips => 0, invested => 0 });
    my $named_fetched = $db->fetch_user({ id => $named->id });
    is($named_fetched->username, 'testreg1', 'named username persisted');
    is($named_fetched->level, 2, 'named level persisted');
    like($named_fetched->bookmark // '', qr/^[0-9a-f]{40}$/, 'named bookmark persisted');
};

# --- 2. Full login flow over one FB instance ---------------------------------
subtest 'guest/register/login_book/logout flow' => sub {
    my $fb = FB->new(address_block => {}, facebook_secret => 'test');

    # guest_login response carries identity for client-side storage
    my $tx1 = FakeTx->new(conn => 't1');
    my $g1 = $fb->_guest_login({ websocket => $tx1 });
    ok($g1->has_user, 'connect attaches guest user');
    $fb->guest_login($g1);
    my $gl = find_msg($tx1, 'guest_login');
    ok($gl && $gl->{success} && $gl->{chips} == 400, 'guest_login succeeds with 400 chips');
    like($gl->{username} // '', qr/^Guest\d+$/, 'guest_login carries username');
    like($gl->{bookmark} // '', qr/^[0-9a-f]{40}$/, 'guest_login carries bookmark');

    # register upgrades the guest (no false "Already registered")
    $fb->request($g1, ['register', { username => 'flowuser', password => 'pw1234',
        email => 'al@xy.com', handle => 'flowuser' }]);
    my $rr = find_msg($tx1, 'register_res');
    ok($rr && $rr->{success}, 'register over guest succeeds');
    my $uid = $rr->{id};
    my $ubook = $rr->{bookmark};
    ($RESTART_UID, $RESTART_BOOK) = ($uid, $ubook);
    ok($uid && $uid != $gl->{user_id}, 'registered user replaces guest');
    like($ubook // '', qr/^[0-9a-f]{40}$/, 'register_res carries bookmark');
    ok(!$fb->user_map->{ $gl->{user_id} }, 'stale guest user_map entry dropped');

    # named account blocks re-registration
    $fb->request($g1, ['register', { username => 'other', password => 'pw1234',
        email => 'al@xy.com', handle => 'other' }]);
    my @rrs = grep { $_->[0] eq 'register_res' } $tx1->sent_msgs;
    ok(@rrs == 2 && !$rrs[-1][1]{success}, 'second register refused for named account');

    # login_book on a fresh connection restores the named identity (refresh)
    my $tx2 = FakeTx->new(conn => 't2');
    my $g2 = $fb->_guest_login({ websocket => $tx2 });
    $fb->guest_login($g2);
    my $transient = $g2->user->id;
    $fb->request($g2, ['login_book', { bookmark => $ubook }]);
    my $lr = find_msg($tx2, 'login_res');
    ok($lr && $lr->{success} && $lr->{id} == $uid, 'login_book restores identity');
    ok($transient != $uid, 'transient guest replaced');
    ok($tx1->{finished}, 'old connection force-logged out');

    # update_profile persists name/avatar to the row
    $fb->request($g2, ['update_profile', { first_name => 'Flow', last_name => 'User',
        picture => { data => { url => 'http://x/pic.png' } }, id => '1' }]);
    my $up = find_msg($tx2, 'update_profile_res');
    ok($up && $up->{success} && $up->{username} eq 'Flow', 'update_profile succeeds');
    my $row = $fb->db->fetch_user({ id => $uid });
    is($row->username, 'Flow', 'name persisted via username');
    is($row->first_name, 'Flow', 'first_name persisted');
    is($row->profile_pic, 'http://x/pic.png', 'avatar persisted');

    # stale bookmark: rejected, session stays alive as the same guest
    my $tx3 = FakeTx->new(conn => 't3');
    my $g3 = $fb->_guest_login({ websocket => $tx3 });
    $fb->guest_login($g3);
    my $g3id = $g3->user->id;
    $fb->request($g3, ['login_book', { bookmark => '0' x 40 }]);
    my $lb = find_msg($tx3, 'login_book_res');
    ok($lb && !$lb->{success}, 'stale bookmark rejected');
    ok(!$tx3->{finished} && $g3->has_user && $g3->user->id == $g3id,
        'guest session survives stale bookmark');

    # self logout detaches identity, keeps socket for re-guest
    $fb->request($g2, ['logout']);
    my $lo = find_msg($tx2, 'logout_res');
    ok($lo && $lo->{success}, 'logout_res success');
    ok(!$tx2->{finished}, 'socket stays open after logout');
    ok(!$g2->has_user, 'identity detached on logout');
    $fb->guest_login($g2);
    my @gls = grep { $_->[0] eq 'guest_login' } $tx2->sent_msgs;
    ok(@gls && $gls[-1][1]{user_id} != $uid, 're-guest mints a fresh identity');
};

# --- 3. Facebook authorize paths ---------------------------------------------
subtest 'authorize new + returning' => sub {
    my $fb = FB->new(address_block => {}, facebook_secret => 'test');
    my $signed = fb_signed_request('fb_1', 'test');

    my $tx1 = FakeTx->new(conn => 'a1');
    my $g1 = $fb->_guest_login({ websocket => $tx1 });
    $fb->guest_login($g1);
    $fb->request($g1, ['authorize', { status => 'connected',
        authResponse => { signedRequest => $signed } }]);
    my @ars = grep { $_->[0] eq 'authorize_res' } $tx1->sent_msgs;
    ok(@ars && $ars[0][1]{success}, 'signature verified');
    my $reg = find_msg($tx1, 'register_res');
    ok($reg && $reg->{success} && $reg->{facebook_id} eq 'fb_1',
        'new FB id registers with facebook_id');
    my $fbuid = $reg->{id};

    my $tx2 = FakeTx->new(conn => 'a2');
    my $g2 = $fb->_guest_login({ websocket => $tx2 });
    $fb->guest_login($g2);
    $fb->request($g2, ['authorize', { status => 'connected',
        authResponse => { signedRequest => $signed } }]);
    my $lr = find_msg($tx2, 'login_res');
    ok($lr && $lr->{success} && $lr->{id} == $fbuid, 'returning FB id logs in');

    # forged signature is rejected
    my $tx3 = FakeTx->new(conn => 'a3');
    my $g3 = $fb->_guest_login({ websocket => $tx3 });
    $fb->guest_login($g3);
    my $bad = fb_signed_request('fb_1', 'wrong-secret');
    $fb->request($g3, ['authorize', { status => 'connected',
        authResponse => { signedRequest => $bad } }]);
    my @bars = grep { $_->[0] eq 'authorize_res' } $tx3->sent_msgs;
    ok(@bars && !$bars[0][1]{success}, 'forged signature rejected');
    ok($g3->user->facebook_id ? 0 : 1, 'guest identity untouched by forgery');
};

# --- 4. Timer handle contract -------------------------------------------------
subtest 'Compat::Timer handle interface' => sub {
    my $h = FB::Compat::Timer::timer(60, 0, sub {});
    isa_ok($h, 'FB::Compat::Timer::Handle', 'timer() returns a Handle');
SKIP: {
        skip 'no Handle to probe', 2 unless ref($h) eq 'FB::Compat::Timer::Handle';
        my $r = $h->remaining;
        ok(defined $r && $r > 0 && $r <= 60, "remaining sane ($r)");
        ok(FB::Compat::Timer::cancel_timer($h), 'cancel_timer works');
    }
};

# --- 5. Rate limit wiring ------------------------------------------------------
# Synthetic in-process transactions (no sockets): full dispatch incl. hooks.
subtest 'Ships rate limiting' => sub {
    require Ships;
    my $app = Ships->new;
    $app->log->level('fatal');   # keep the 100-request loop quiet
    my $get = sub {
        my ($path) = @_;
        my $tx = Mojo::Transaction::HTTP->new;
        $tx->req->method('GET');
        $tx->req->url->parse($path);
        $tx->remote_address('127.0.0.1');
        $app->handler($tx);
        return $tx->res;
    };
    my $ok200 = 0;
    for (1 .. 100) {
        $ok200++ if $get->('/')->code == 200;
    }
    is($ok200, 100, '100 requests under the limit succeed');
    my $over = $get->('/');
    is($over->code, 429, '101st request gets 429');
    is($over->json->{error}, 'rate_limit_exceeded', '429 body carries error code');
    is($get->('/jquery.poker.main.js')->code, 200, 'static excluded');
    {
        local $ENV{MOJOPOKER_RATE_LIMIT} = 'off';
        is($get->('/')->code, 200, 'explicit dev opt-out disables limiting');
    }
};

# --- 6. Restart simulation: fresh instance, same database --------------------
subtest 'identity survives restart' => sub {
    ok($RESTART_UID && $RESTART_BOOK, 'flow subtest banked an identity');
    my $fb2 = FB->new(address_block => {}, facebook_secret => 'test');
    my $tx = FakeTx->new(conn => 'r1');
    my $g = $fb2->_guest_login({ websocket => $tx });
    $fb2->guest_login($g);
    $fb2->request($g, ['login_book', { bookmark => $RESTART_BOOK }]);
    my $lr = find_msg($tx, 'login_res');
    ok($lr && $lr->{success} && $lr->{id} == $RESTART_UID, 'bookmark restores after restart');
    is($lr->{first_name} // '', 'Flow', 'name survives restart');
    is($lr->{profile_pic} // '', 'http://x/pic.png', 'avatar survives restart');
};

done_testing();
