;
(function($, window, document) {
    $.widget("poker.lobby", {
        options: {
            widthToHeight: 4 / 3,
            epochDiff: 0,
            inchan: {},
            colData: {
                1: ["Id", "int"],
                2: ["Stakes", "string"],
                3: ["Limit", "string"],
                4: ["Seats", "int"],
                5: ["Plrs", "string"],
                6: ["Wait", "int"],
                7: ["Avg Pot", "int"],
                8: ["Plrs/Flop", "int"],
                9: ["H/hr", "int"],
                10: ["Start", "int"],
                11: ["Game", "string"],
                12: ["Buy-In", "int"],
                13: ["State", "string"],
                14: ["Enrolled", "int"],
                15: ["Table", "int"],
                16: ["Speed", "string"],
                17: ["Login", "string"],
                18: ["Name", "string"],
                19: ["Location", "string"],
                20: ["Player", "string"],
                21: ["Chips", "int"],
                22: ["Seat", "int"],
                23: ["Block", "int"],
                24: ["Player Pool", "int"],
                25: ["#", "int"],
                26: ["Profit", "string"]
            },
            ringCols: [25, 11, 2, 3, 4, 5, 7, 8, 9],
            leaderCols: [25, 20, 26, 21],
            socialCols: [17, 18, 19],
            hydraCols: [1, 11, 2, 3, 4, 24],
            loginData: {},
            ringData: {},
            fastData: {},
            gameState: {
                0: "Closed",
                1: "Registering",
                2: "Late Reg.",
                3: "Full",
                4: "Playing",
                6: "Complete"
            },
            gameTabs: {
                all: ["All", 1],
                dealers: ["Dealer's Choice", 1],
                holdem: ["Hold'em", 1],
                holdemjokers: ["Hold'em (Jokers)", 1],
                pineapple: ["Pineapple", 1],
                crazypine: ["Crazy Pineapple", 1],
                omaha: ["Omaha", 1],
                omahahilo: ["Omaha Hi-Lo", 1],
                omahafive: ["5 Card Omaha", 2],
                omahafivehilo: ["5 Card Omaha Hi-Lo", 2],
                courcheval: ["Courcheval", 2],
                courchevalhilo: ["Courcheval Hi-Lo", 2],
                fivedraw: ["5 Card Draw", 2],
                drawjokers: ["5 Card Draw (Jokers)", 2],
                drawdeuces: ["5 Card Draw (Deuces)", 3],
                singledraw27: ["2-7 Single Draw", 3],
                tripledraw27: ["2-7 Triple Draw", 3],
                singledrawa5: ["A-5 Single Draw", 3],
                tripledrawa5: ["A-5 Triple Draw", 3],
                sevenstud: ["7 Card Stud", 3],
                razz: ["Razz", 3],
                sevenstudhilo: ["7 Card Stud Hi-Lo", 4],
                sevenstudjokers: ["7 Card Stud (Jokers)", 4],
                highchicago: ["High Chicago", 4],
                ftq: ["Follow the Queen", 4],
                bitch: ["The Bitch", 4],
                badugi: ["Badugi", 4],
                badacey: ["Badacey", 4],
                badeucy: ["Badeucy", 4]
            }
        },
        _create: function() {
            var v = this,
                e = v.options,
                f = v.element;

            clearInterval(e.clockTimer);

            $("#lobby-name").hide();
            $("#lobby-chips").hide();
            $("#main-chat").empty();

            // leaderboard table
            $("#lobby-leader").append(v._buildTable(e.leaderCols));

            // auto match button
            $("#lobby-match").click(function() {
               if ( $("#lobby-loginout").hasClass("login") ) {
                  v.modal_message("Please login to play.");
               } else {
                  v._autoMatch();
               }
            });

            // logout button
            $("#lobby-logout").click(function() {
                v._logout();
            });

            // help button
            $("#lobby-head2").on("click", function() {
                $( "#lobby-help" ).dialog({
                   modal: true,
                   buttons: {
                      Ok: function() {
                         $( this ).dialog( "close" );
                      }
                   }
                });
            });

            // build game tabs
            $("#ring-info").append(v._buildTable(e.ringCols));

            // chat form
            var si = $("#social-input");
            $("#social-form").submit(function(m) {
                m.preventDefault();
                var y = /^[\w\s\.\,\?!@#\$%^&\*\(\)_]{0,90}$/;
                if ( $("#lobby-loginout").hasClass("login") ) {
                   v.modal_message("Please login to chat.");
                } else if (y.test(si.val())) {
                  v._sendChatMessage(si.val());
                }
                si.val("")
            });

            // game tabs
            $.each(e.gameTabs, function(o, m) {
                f.find("#game-tabs" + m[1]).append($("<button />").attr({
                    id: o + "-tab",
                    info: o
                }).addClass("lobby-tab").html(m[0]))
            });

            // clicking behavior
            f.on("click", "#tabs .lobby-tab", function() {
                    var m = $(this);
                    f.find("#tabs > [type=" + m.parent().attr("type") + "] .lobby-tab.select").removeClass("select");
                    m.addClass("select")
                })
                .on("click", "#tabs > [type=game] .lobby-tab", function() {
                    var y = $(this).attr("info");
                    var o = f.find(".tab-info.games tbody tr");
                    if (y == "all") {
                        o.show()
                    } else {
                        o.filter("[game_class=" + y + "]").show();
                        o.filter("[game_class!=" + y + "]").hide()
                    }
                })

                // highlighter
                .on("click", ".tab-info tbody tr", function() {
                    var m = $(this);
                    m.siblings().removeClass("select");
                    m.addClass("select")
                })
                .on("click", "#ring-info tbody tr", function() {
                    var m = $(this).attr("table_id");
                    v._joinGame(m);
                })
                // button hover
                .on("mouseenter", "button.lobby-tab", function() {
                    $(this).addClass("tab-hover")
                })
                .on("mouseleave", "button.lobby-tab", function() {
                    $(this).removeClass("tab-hover")
                });

            // Initialize WebSocket connection
            v._initWebSocket();

            $(window).resize(function() {
                v.resizeLobby()
            });
            v.resizeLobby();
            $("#social-input").focus();
        },

        // NEW: WebSocket Integration
        _initWebSocket: function() {
            var v = this;
            console.log('🔌 Initializing WebSocket connection...');

            // Connect to WebSocket server
            v.socket = io('http://localhost:3000', {
                reconnection: true,
                reconnectionAttempts: 5,
                reconnectionDelay: 1000,
                autoConnect: true
            });

            // WebSocket event handlers
            v.socket.on('connect', function() {
                console.log('✅ WebSocket connected');
                v._checkLoginStatus();
            });

            v.socket.on('connect_error', function(error) {
                console.error('❌ WebSocket connection error:', error);
                v.modal_message('Failed to connect to game server. Please refresh the page.');
            });

            v.socket.on('disconnect', function(reason) {
                console.log('🔌 WebSocket disconnected:', reason);
            });

            v.socket.on('auth_success', function(data) {
                console.log('✅ Authentication successful');
                v._updateLobby(data);
                v._joinLobby();
            });

            v.socket.on('auth_error', function(error) {
                console.error('❌ Authentication failed:', error);
                v.modal_message('Authentication failed: ' + error.error);
            });

            v.socket.on('lobby_update', function(games) {
                console.log('🏠 Lobby update received', games);
                v._updateAvailableGames(games);
            });

            v.socket.on('available_games', function(games) {
                console.log('🎮 Available games update', games);
                v._updateAvailableGames(games);
            });

            v.socket.on('game_created', function(data) {
                console.log('🎮 Game created', data);
                v._joinGame(data.gameId);
            });

            v.socket.on('player_joined', function(data) {
                console.log('👥 Player joined game', data);
                v.modal_message('Joined game successfully!');
                // Redirect to game table
                window.location.href = '/game.html?gameId=' + data.gameId;
            });

            v.socket.on('game_state', function(state) {
                console.log('🎮 Game state update', state);
                // Update game UI
            });

            v.socket.on('error', function(error) {
                console.error('❌ Error:', error);
                v.modal_message('Error: ' + error.error);
            });
        },

        // NEW: Join Lobby
        _joinLobby: function() {
            var v = this;
            console.log('🏠 Joining lobby...');
            v.socket.emit('join_lobby');
        },

        // NEW: Join Game
        _joinGame: function(gameId) {
            var v = this;
            console.log('🎮 Attempting to join game:', gameId);

            // Check if authenticated
            if (!v._isAuthenticated()) {
                v.modal_message('Please login to join games.');
                return;
            }

            v.socket.emit('join_game', gameId);
        },

        // NEW: Create Game
        _createGame: function() {
            var v = this;
            console.log('🎮 Creating new game...');

            v.socket.emit('create_game', {
                smallBlind: 10,
                bigBlind: 20,
                startingChips: 1000
            });
        },

        // NEW: Auto Match
        _autoMatch: function() {
            var v = this;
            console.log('🎮 Auto matching...');
            v._createGame(); // For now, just create a game
        },

        // NEW: Check if authenticated
        _isAuthenticated: function() {
            // Check if we have a valid JWT token
            return localStorage.getItem('jwtToken') !== null;
        },

        // NEW: Send chat message
        _sendChatMessage: function(message) {
            var v = this;
            if (v.socket && v.socket.connected) {
                v.socket.emit('chat_message', message);
            } else {
                v.modal_message('Not connected to chat server');
            }
        },

        // NEW: Update available games list
        _updateAvailableGames: function(games) {
            var v = this,
                f = v.element;

            // Clear existing games
            f.find("#ring-info tbody").empty();

            // Add each game
            $.each(games, function(index, game) {
                $("<tr />").attr({
                    id: "lring" + game.gameId,
                    table_id: game.gameId,
                    game_class: "holdem"
                }).addClass("lring").append(
                    $("<td />").addClass("table-id").html(game.gameId),
                    $("<td />").html("Texas Hold'em"),
                    $("<td />").addClass().html(game.smallBlind + "/" + game.bigBlind),
                    $("<td />").addClass().html("No Limit"),
                    $("<td />").addClass().html(game.playerCount + "/" + game.maxPlayers),
                    $("<td />").addClass("plr-count").html("0"),
                    $("<td />").addClass("avg-pot").html("--"),
                    $("<td />").addClass("plrs-flop").html("--"),
                    $("<td />").addClass("hhr").html("--")
                ).appendTo(f.find("#ring-info tbody"));
            });

            // Update game count
            f.find("#game-count").text(games.length + " games available");
        },

        // Modified: Check login status with WebSocket
        _checkLoginStatus: function() {
            var v = this;

            // Check if we have a JWT token
            const token = localStorage.getItem('jwtToken');

            if (token) {
                // Authenticate with WebSocket
                v.socket.emit('authenticate', token);
            } else {
                // Show login button
                $("#lobby-loginout").removeClass("logout").addClass("login").off('click').click(function() {
                    // In a real app, you would open a login dialog
                    v.modal_message("Please login to play games.");
                });
            }
        },

        // Modified: Logout with WebSocket
        _logout: function() {
            var v = this;

            // Clear token
            localStorage.removeItem('jwtToken');

            // Disconnect WebSocket
            if (v.socket) {
                v.socket.disconnect();
            }

            // Update UI
            $("#lobby-loginout").removeClass("logout").addClass("login").off('click').click(function() {
                v.modal_message("You have been logged out.");
            });

            // Reset lobby
            v._updateLobby({});
        },

        // Rest of the original functions can remain mostly the same
        // ... (keeping other existing functions) ...

        watch_table_res: function(f) {
            var e = this,
                h = e.options,
                g = e.element;
            $("#table-ring").append($("<div />").attr("id", "tring" + f.table_id).table_ring(f))

            if (f.auto_seat && f.chair_id) {
               $("#tring" + f.table_id + " .seat" + f.chair_id + " > .open-graphic").click();
            }
        },
        _destroy: function() {},
        destroy: function() {},
        register_res: function(g) {
            var f = this,
                e;
            if (g.success) {
                f.login_success(g)
            }
        },
        update_profile_res: function(g) {
            var f = this,
                e;
            if (g.success) {
                f._update_lobby(g)
            }
        },
        _buildTable: function(h) {
            var e = this,
                i = e.options,
                g = e.element;
            var f = "";
            $.each(h, function(m, j) {
                var o = i.colData[j][0];
                var l = i.colData[j][1];
                f += '<th data-sort-dir="asc" data-sort="' + l + '">' + o + "</th>"
            });
            return $("<div/>").addClass("table-box").append($("<table />").append($("<thead />").append($("<tr>").html(f)), $("<tbody />")).stupidtable().bind("aftertablesort", function(l, n) {
                $this = $(this);
                var j = $this.find("th");
                j.find(".arro").remove();
                var m = n.direction === "asc" ? "↑" : "↓";
                j.eq(n.column).append('<span class="arro">' + m + "</span>")
            }))
        },
        resizeLobby: function() {
            var h = this.options,
                newWidth = window.innerWidth * .9,
                newHeight = window.innerHeight * .9,
                newWidthToHeight = newWidth / newHeight;

            if (newWidthToHeight > h.widthToHeight) {
                newWidth = newHeight * h.widthToHeight;
            } else {
                newHeight = newWidth / h.widthToHeight;
            }
            this.element.css({
                height: newHeight + "px",
                width: newWidth + "px",
                marginTop: (-newHeight / 2) + "px",
                marginLeft: (-newWidth / 2) + "px",
                fontSize: (newWidth / 680) + "em"
            });
        },
        guest_login: function(f) {
            var e = this,
                h = e.options,
                g = e.element;
            e._update_lobby(f);

            h.epochDiff = (new Date).getTime() - (f.epoch * 1000);
            h.myData = {
                login_id: f.login_id,
                username: f.username,
                chips: f.chips
            };

            $("#lobby-name").html(h.myData.username);

            e._reset_timer(f.timer);
            e._check_login_status();
        },
        _reset_timer: function(t) {
            var e = this,
                h = e.options;

            clearInterval(h.clockTimer);
            h.distance = t;

            var counter = $("#lobby-countdown > span");

            h.clockTimer = setInterval(function() {
                h.distance -= 1;
                var hours = Math.floor((h.distance % (86400)) / (3600));
                var minutes = Math.floor((h.distance % 3600) / 60);
                var seconds = Math.floor(h.distance % 60);

                counter.html(hours + 'h ' + minutes + 'm ' + seconds + 's');

                if (h.distance <= 0) {
                    e._reset_timer(604800);
                }
            }, 1000);
        },
        modal_message: function(message) {
            var h = this;

            $("#modal-box").empty().append( $("<p />").html(message) );
            $("#modal-box").dialog({
                title: "Alert",
                position: {
                    my: "center",
                    at: "center",
                    of: window
                },
                modal: true,
                buttons: [{
                    text: "Okay",
                    click: function() {
                        $("#modal-box").empty();
                        $(this).dialog("close");
                    }
                }]
            });
        },
        login_success: function(f) {
            var e = this,
                h = e.options,
                g = e.element;
            $("#lobby-name").show();
            $("#lobby-chips").show();
            e._update_lobby(f)
        },
        login_res: function(f) {
            if (f.success) {
                this.login_success(f)
            }
        },
        authorize_res: function(f) {
            var v = this;
            if (f.success) {
                // Store JWT token
                localStorage.setItem('jwtToken', f.accessToken);

                // Update UI
                $("#lobby-loginout").removeClass("login").addClass("logout").off('click').click(function() {
                    v._logout();
                });

                // Get user profile
                v.socket.emit('get_profile');
            } else {
                v.modal_message('Login failed: ' + (f.error || 'Unknown error'));
            }
        },
        login_update: function(f) {
            var e = this,
                h = e.options,
                g = e.element;
            e._update_lobby(f);
        },
        login_info_res: function(f) {
            var e = this,
                h = e.options,
                g = e.element;
            if (f.success) {
                e._update_lobby(f);
            }
        },
        join_channel_res: function(f) {
            var e = this,
                h = e.options,
                g = e.element;
            h.inchan[f.channel] = f.success ? true : false
        },
        unjoin_channel_res: function(f) {
            var e = this,
                h = e.options,
                g = e.element;
            h.inchan[f.channel] = f.success ? false : true
        },
        notify_message: function(g) {
            var f = this,
                l = f.options,
                h = f.element;

            var e = $("#" + g.channel + "-chat");
            e.append($("<div />").addClass("chat-msg").append(
                $("<span />").addClass("chat-pic").css("background-image", "url(" + g.profile_pic + ")"),
                $("<span />").addClass("chat-content").html(g.username + ': ' + g.message)
            ));

            e.animate({
                scrollTop: e[0].scrollHeight
            })
        },
        notify_leaders: function(f) {
            var table = $("#lobby-leader tbody");
            table.empty();
            $.each(f.leaders, function(index, obj) {
                var count = 1;
                var row = $("<tr >").append("<td >").html(index + 1);
                $.each(obj, function(key, value) {
                    var col = $("<td >").html(value);
                    if (count == 2) {
                       if (value < 0) {
                          col.addClass("red");
                          col.html(value + '%');
                       } else {
                          col.addClass("green");
                          col.html('+' + value + '%');
                       }
                    } else {
                       col.html(value);
                    }
                    row.append(col);
                    count++;
                });
                table.append(row);
            });
        },
        notify_login: function(f) {
            var e = this,
                h = e.options,
                g = e.element;
            this.notify_logout(f);
            f.color = "rgb(" + Math.floor(Math.random() * 256) + "," + Math.floor(Math.random() * 256) + "," + Math.floor(Math.random() * 256) + ")";
            h.loginData[f.login_id] = f;
        },
        notify_logout: function(f) {
            var e = this,
                h = e.options,
                g = e.element;
            delete h.loginData[f.login_id];
            g.find("#social-info .table-box tbody tr[login_id=" + f.login_id + "]").remove()
        },
        ring_snap: function(f) {
            var e = this,
                h = e.options,
                g = e.element;
            $.each(f, function(j, l) {
                h.ringData[l.table_id] = l
            });
            e._build_ring_tab()
        },
        _build_ring_tab: function() {
            var e = this,
                h = e.options,
                g = e.element;
            var f = g.find("#ring-info tbody");
            f.empty();
            $.each(h.ringData, function(l, j) {
                var m = j.small_blind + "/" + j.big_blind;
                var i = j.game_class == "dealers" ? "--" : j.limit;
                $("<tr />").attr({
                    id: "lring" + l,
                    table_id: j.table_id,
                    game_class: j.game_class
                }).addClass("lring").append(
                    $("<td />").addClass("table-id").html(j.table_id),
                    $("<td />").html(h.gameTabs[j.game_class][0]),
                    $("<td />").addClass().html(m),
                    $("<td />").addClass().html(i),
                    $("<td />").addClass().html(j.chair_count),
                    $("<td />").addClass("plr-count"),
                    $("<td />").addClass("avg-pot"),
                    $("<td />").addClass("plrs-flop"),
                    $("<td />").addClass("hhr")
                ).appendTo(f);
                e._update_ring_tab(j);
            });
            g.find("#all-tab").trigger("click");
            g.find("#ring-info thead th:eq(5)").trigger("click");
        },
        notify_create_ring: function(f) {
            var e = this,
                h = e.options,
                g = e.element;
            h.ringData[f.table_id] = f;
            e._build_ring_tab()
        },
        notify_destroy_ring: function(e) {
            delete this.options.ringData[e.table_id];
            this.element.find("#lring" + e.table_id).remove()
        },
        notify_lr_update: function(f) {
            var e = this,
                h = e.options,
                g = e.element;
            $.extend(h.ringData[f.table_id], f);
            e._update_ring_tab(f)
        },
        _update_lobby: function(g) {
            var t = this,
                o = t.options;

            $.extend(o.myData, g);

            var e = {
                chips: function(l) {
                    $("#lobby-chips span").html(l);
                },
                username: function(l) {
                    $("#lobby-name").html(l);
                }
            };
            $.each(g, function(l, m) {
                if (l in e) {
                    e[l](m)
                }
            })
        },
        _update_ring_tab: function(g) {
            var f = this,
                j = f.options,
                i = f.element;
            var h = i.find("#lring" + g.table_id);
            var e = {
                avg_pot: function(l) {
                    h.find(".avg-pot").html(l)
                },
                plrs_flop: function(l) {
                    h.find(".plrs-flop").html(l)
                },
                hhr: function(l) {
                    h.find(".hhr").html(l)
                },
                plr_map: function(m) {
                    var n = h.find(".plr-count");
                    var l = 0;
                    for (k in m) {
                        l++
                    }
                    n.html(l)
                }
            };
            $.each(g, function(l, m) {
                if (l in e) {
                    e[l](m)
                }
            })
        },
        _msgHandler: function(g, f) {
            var e = {};
            if (g in e) {
                e[g](f)
            }
        },
        _setOption: function(g, i) {
            var f = this,
                j = f.options,
                h = f.element;
            var e = {};
            if (g in e) {
                j[g] = i;
                e[g](i)
            }
        }
    })
})(jQuery, window, document);