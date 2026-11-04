/* Copyright (C) 2026, California Vision — Forecast page client (Sessions 2-3). Play money only. */
var Forecast = (function() {
    var ws = null, wsUrl = null, myLevel = 0, myId = null, doneCache = { resolved: null, settled: null };

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

    function bar(q) {
        var html = '<div class="fc-bar">' +
            '<div class="fc-yes" style="width:' + q.prob_yes + '%">YES ' + q.prob_yes + '%</div>' +
            '<div class="fc-no" style="width:' + q.prob_no + '%">NO ' + q.prob_no + '%</div></div>' +
            '<div class="fc-totals">' + q.yes_total + ' YES / ' + q.no_total + ' NO staked';
        if (q.my_yes || q.my_no) {
            html += ' — you: ' + q.my_yes + ' YES / ' + q.my_no + ' NO';
        }
        return html + '</div>';
    }

    function questionHtml(q) {
        var html = '<div class="fc-q">' +
            '<div class="fc-prompt">' + esc(q.prompt) + '</div>' +
            '<div class="fc-criteria">' + esc(q.resolution_criteria) + '</div>' +
            '<div class="fc-meta">Resolves: ' + esc(q.resolution_date || 'TBD') + '</div>' +
            bar(q) +
            '<div class="fc-stake" data-qid="' + esc(q.id) + '">' +
            '<input type="number" class="fc-amt" min="1" value="10">' +
            '<button class="fc-btn" data-side="YES">Stake YES</button>' +
            '<button class="fc-btn" data-side="NO">Stake NO</button>' +
            '<span class="fc-msg"></span></div>';
        if (myId !== null && (myLevel >= 4 || String(myId) === String(q.created_by))) {
            html += '<div class="fc-resolve" data-qid="' + esc(q.id) + '">' +
                '<button class="fc-resolve-btn">Resolve</button>' +
                '<span class="fc-msg"></span></div>';
        }
        return html + '</div>';
    }

    function renderOpen(questions) {
        var box = $('#fc-open').empty();
        if (!questions.length) {
            box.html('<p class="fc-empty">No open questions right now.</p>');
            return;
        }
        for (var i = 0; i < questions.length; i++) {
            box.append(questionHtml(questions[i]));
        }
    }

    function renderRep(v) {
        var t;
        if ((v.won + v.lost) > 0) {
            t = v.won + ' won · ' + v.lost + ' lost · Brier ' +
                ((v.brier === null || v.brier === undefined) ? '—' : Number(v.brier).toFixed(2));
        } else {
            t = 'no settled positions yet';
        }
        $('#fc-rep-text').text(t);
    }

    function renderDone() {
        if (doneCache.resolved === null || doneCache.settled === null) {
            return;
        }
        var questions = doneCache.resolved.concat(doneCache.settled);
        var box = $('#fc-resolved').empty();
        if (!questions.length) {
            box.html('<p class="fc-empty">Nothing resolved yet.</p>');
            return;
        }
        for (var i = 0; i < questions.length; i++) {
            var q = questions[i];
            var mine = (q.my_yes || q.my_no) ? ' — you: ' + q.my_yes + ' YES / ' + q.my_no + ' NO' : '';
            box.append('<div class="fc-q">' +
                '<div class="fc-prompt">' + esc(q.prompt) + '</div>' +
                '<div class="fc-meta">' + esc(q.status) + ' · final: ' +
                q.yes_total + ' YES / ' + q.no_total + ' NO' + esc(mine) + '</div>' +
                '<a href="/forecast/record/' + esc(q.id) + '">View resolution record</a></div>');
        }
    }

    function renderDrafts(drafts) {
        var box = $('#fc-drafts').empty();
        if (!drafts.length) {
            box.html('<p class="fc-empty">No drafts waiting.</p>');
            return;
        }
        for (var i = 0; i < drafts.length; i++) {
            var q = drafts[i];
            box.append('<div class="fc-q">' +
                '<div class="fc-prompt">' + esc(q.prompt) + '</div>' +
                '<div class="fc-criteria">' + esc(q.resolution_criteria) + '</div>' +
                '<div class="fc-meta">Resolves: ' + esc(q.resolution_date || 'TBD') + '</div>' +
                '<button class="fc-approve" data-qid="' + esc(q.id) + '">Approve</button> ' +
                '<button class="fc-reject" data-qid="' + esc(q.id) + '">Reject</button>' +
                '<span class="fc-msg"></span></div>');
        }
    }

    function refresh() {
        send(['fc_list']);
        send(['fc_list', {status: 'resolved'}]);
        send(['fc_list', {status: 'settled'}]);
        send(['fc_reputation']);
        if (myLevel >= 4) {
            send(['fc_list', {status: 'draft'}]);
        }
    }

    function onMessage(ev) {
        var m;
        try { m = JSON.parse(ev.data); } catch (e) { return; }
        var k = m[0], v = m[1] || {};
        if (k === 'guest_login') {
            $('#fc-user').text(v.username + ' (Guest)');
            $('#fc-balance').text(v.fc_balance);
            var bm = storedBookmark();
            if (bm && bm !== v.bookmark) {
                send(['login_book', {bookmark: bm}]);
            } else {
                refresh();
            }
        } else if (k === 'login_res') {
            if (!v.success) {
                status('Login failed: ' + (v.reason || ''));
                refresh();
                return;
            }
            $('#fc-user').text(v.username);
            $('#fc-balance').text(v.fc_balance);
            myLevel = v.level || 0;
            myId = (v.id === null || v.id === undefined) ? null : v.id;
            storeBookmark(v.bookmark);
            if (myLevel >= 4) {
                $('#fc-admin').show();
            }
            refresh();
        } else if (k === 'login_book_res') {
            if (!v.success) {
                clearBookmark();
            }
            refresh();
        } else if (k === 'fc_list_res') {
            if (!v.success) {
                status('Could not load questions.');
                return;
            }
            status('');
            if (v.status === 'draft') {
                renderDrafts(v.questions || []);
            } else if (v.status === 'resolved' || v.status === 'settled') {
                doneCache[v.status] = v.questions || [];
                renderDone();
            } else {
                renderOpen(v.questions || []);
            }
        } else if (k === 'fc_stake_res') {
            if (!v.success) {
                status('Stake failed: ' + (v.reason || ''));
                return;
            }
            $('#fc-balance').text(v.balance);
            status('Staked at ' + v.price + '%. New balance: ' + v.balance + '.');
            refresh();
        } else if (k === 'fc_resolve_res') {
            if (!v.success) {
                status('Resolve failed: ' + (v.reason || ''));
                return;
            }
            status('Resolved ' + v.outcome + '. Challenge window open.');
            refresh();
        } else if (k === 'fc_reputation_res') {
            if (!v.success) {
                return;
            }
            renderRep(v);
        } else if (k === 'fc_generate_res') {
            if (!v.success) {
                status('Generate failed: ' + (v.reason || ''));
                return;
            }
            status('Drafted ' + (v.draft_ids || []).length + ' questions.');
            refresh();
        } else if (k === 'fc_approve_res' || k === 'fc_reject_res') {
            if (!v.success) {
                status('Moderation failed: ' + (v.reason || ''));
                return;
            }
            refresh();
        } else if (k === 'logout_res' || k === 'forced_logout') {
            status('Session ended. Reload to continue as a guest.');
        }
    }

    function init(opts) {
        wsUrl = opts.ws;
        $('#fc-open').on('click', '.fc-btn', function() {
            var box = $(this).closest('.fc-stake');
            var amt = parseInt(box.find('.fc-amt').val(), 10);
            if (!(amt > 0)) {
                box.find('.fc-msg').text('Enter a positive stake.');
                return;
            }
            box.find('.fc-msg').text('');
            send(['fc_stake', {question_id: box.data('qid'), side: $(this).data('side'), stake: amt}]);
        });
        $('#fc-open').on('click', '.fc-resolve-btn', function() {
            var box = $(this).closest('.fc-resolve');
            box.find('.fc-msg').text('');
            status('Resolving…');
            send(['fc_resolve', {question_id: box.data('qid')}]);
        });
        $('#fc-generate-btn').on('click', function() {
            var t = $('#fc-topic').val();
            status('Generating drafts…');
            if (t) {
                send(['fc_generate', {topic: t}]);
            } else {
                send(['fc_generate']);
            }
        });
        $('#fc-drafts').on('click', '.fc-approve', function() {
            send(['fc_approve', {question_id: $(this).data('qid')}]);
        });
        $('#fc-drafts').on('click', '.fc-reject', function() {
            send(['fc_reject', {question_id: $(this).data('qid')}]);
        });
        try {
            ws = new WebSocket(wsUrl);
        } catch (e) {
            status('Could not connect.');
            return;
        }
        ws.onopen = function() {
            status('Connected. Logging in…');
            send(['guest_login']);
        };
        ws.onmessage = onMessage;
        ws.onclose = function() { status('Disconnected. Reload to reconnect.'); };
        ws.onerror = function() { status('Connection error.'); };
    }

    return { init: init };
})();
