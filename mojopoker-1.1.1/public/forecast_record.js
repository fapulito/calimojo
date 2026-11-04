/* Copyright (C) 2026, California Vision — Resolution record client (Session 3). Play money only. */
/* Bookmark + escaping helpers mirror forecast.js (two small pages, no shared bundle). */
var ForecastRecord = (function() {
    var ws = null, wsUrl = null, pageId = null, authed = false, record = null;

    function esc(s) {
        return String(s == null ? '' : s).replace(/[&<>"']/g, function(c) {
            return {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[c];
        });
    }

    function status(msg) { $('#fc-status').text(msg); }
    function send(arr) { ws.send(JSON.stringify(arr)); }

    function storedBookmark() {
        try { return localStorage.getItem('mojopoker.bookmark'); } catch (e) { return null; }
    }
    function storeBookmark(bm) {
        if (!bm) { return; }
        try { localStorage.setItem('mojopoker.bookmark', bm); } catch (e) {}
    }
    function clearBookmark() {
        try { localStorage.removeItem('mojopoker.bookmark'); } catch (e) {}
    }

    function fetchRecord() {
        send(['fc_record', {resolution_id: pageId}]);
    }

    function windowText(rec) {
        if (rec.status === 'settled') {
            return 'Settled.';
        }
        var now = Math.floor(Date.now() / 1000);
        var dl = new Date(rec.challenge_deadline * 1000).toLocaleString();
        if (rec.status === 'challenged') {
            return 'Challenged — under manual review. Settlement blocked.';
        }
        if (now < rec.challenge_deadline) {
            return 'Challenge window open until ' + dl + '.';
        }
        return 'Challenge window closed ' + dl + '. Ready to settle.';
    }

    function render(rec) {
        record = rec;
        var box = $('#fc-record').empty();
        var cls = rec.outcome === 'YES' ? 'fc-outcome-yes' : 'fc-outcome-no';
        var html = '<div class="fc-q">' +
            '<div class="fc-prompt">' + esc(rec.prompt) + '</div>' +
            '<div class="fc-criteria">' + esc(rec.criteria) + '</div>' +
            '<div class="fc-outcome ' + cls + '">Outcome: ' + esc(rec.outcome) + '</div>' +
            '<div class="fc-record-status">Status: ' + esc(rec.status) + ' — ' + esc(windowText(rec)) + '</div>' +
            '<h2>Reasoning</h2><div class="fc-reasoning">' + esc(rec.reasoning) + '</div>' +
            '<h2>Cited sources</h2>';
        if (rec.sources_used && rec.sources_used.length) {
            html += '<ul class="fc-sources">';
            for (var i = 0; i < rec.sources_used.length; i++) {
                var s = rec.sources_used[i];
                html += '<li>' + esc(s.source) + (s.ref ? ' — ' + esc(s.ref) : '') + '</li>';
            }
            html += '</ul>';
        } else {
            html += '<p class="fc-empty">No sources cited.</p>';
        }
        html += '<h2>Challenges (' + (rec.challenges ? rec.challenges.length : 0) + ')</h2>';
        if (rec.challenges && rec.challenges.length) {
            html += '<ul class="fc-sources">';
            for (var j = 0; j < rec.challenges.length; j++) {
                var c = rec.challenges[j];
                html += '<li>User ' + esc(c.user_id) + ' [' + esc(c.status) + ']: ' + esc(c.reason) + '</li>';
            }
            html += '</ul>';
        } else {
            html += '<p class="fc-empty">No challenges filed.</p>';
        }
        box.html(html + '</div>');
        if (authed && rec.status !== 'settled') {
            $('#fc-actions').show();
        } else {
            $('#fc-actions').hide();
        }
    }

    function onMessage(ev) {
        var m;
        try { m = JSON.parse(ev.data); } catch (e) { return; }
        var k = m[0], v = m[1] || {};
        if (k === 'guest_login') {
            var bm = storedBookmark();
            if (bm && bm !== v.bookmark) {
                send(['login_book', {bookmark: bm}]);
            } else {
                fetchRecord();
            }
        } else if (k === 'login_res') {
            if (!v.success) {
                status('Login failed: ' + (v.reason || ''));
                fetchRecord();
                return;
            }
            authed = true;
            storeBookmark(v.bookmark);
            status('');
            fetchRecord();
        } else if (k === 'login_book_res') {
            if (!v.success) {
                clearBookmark();
            }
            fetchRecord();
        } else if (k === 'fc_record_res') {
            if (!v.success) {
                if (v.reason === 'no_such_resolution') {
                    send(['fc_record', {question_id: pageId}]);
                    return;
                }
                if (v.reason === 'not_resolved') {
                    $('#fc-record').html('<p class="fc-empty">No resolution for this question yet.</p>');
                    status('');
                    return;
                }
                status('Could not load record: ' + (v.reason || ''));
                return;
            }
            status('');
            render(v.record);
        } else if (k === 'fc_challenge_res') {
            if (!v.success) {
                status('Challenge failed: ' + (v.reason || ''));
                return;
            }
            status('Challenge filed. The resolution is under manual review.');
            $('#fc-challenge-reason').val('');
            fetchRecord();
        } else if (k === 'fc_settle_res') {
            if (!v.success) {
                status('Settle failed: ' + (v.reason || ''));
                return;
            }
            status('Settled ' + v.outcome + ': ' + v.total_paid + ' paid across ' + v.positions + ' position(s).');
            fetchRecord();
        } else if (k === 'logout_res' || k === 'forced_logout') {
            status('Session ended. Reload to continue.');
        }
    }

    function init(opts) {
        wsUrl = opts.ws;
        pageId = opts.id;
        $('#fc-challenge-btn').on('click', function() {
            if (!record) {
                return;
            }
            var reason = $('#fc-challenge-reason').val();
            if (!reason || !/\S/.test(reason)) {
                status('Give a reason for the challenge.');
                return;
            }
            send(['fc_challenge', {resolution_id: record.resolution_id, reason: reason}]);
        });
        $('#fc-settle-btn').on('click', function() {
            if (!record) {
                return;
            }
            status('Settling…');
            send(['fc_settle', {question_id: record.question_id}]);
        });
        try {
            ws = new WebSocket(wsUrl);
        } catch (e) {
            status('Could not connect.');
            return;
        }
        ws.onopen = function() {
            status('Connected. Loading…');
            send(['guest_login']);
        };
        ws.onmessage = onMessage;
        ws.onclose = function() { status('Disconnected. Reload to reconnect.'); };
        ws.onerror = function() { status('Connection error.'); };
    }

    return { init: init };
})();
