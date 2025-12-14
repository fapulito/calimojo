/**
 * WebSocket Game Server
 *
 * Handles real-time multiplayer poker game interactions
 */
const { Server } = require('socket.io');
const TexasHoldem = require('../poker/games/Holdem');
const { jwtAuth, verifyToken } = require('../middleware/jwt');

class GameServer {
  constructor(httpServer) {
    this.io = new Server(httpServer, {
      cors: {
        origin: process.env.NODE_ENV === 'production'
          ? 'https://your-vercel-app.vercel.app'
          : 'http://localhost:3000',
        methods: ['GET', 'POST'],
        credentials: true
      }
    });

    this.games = new Map(); // gameId -> gameInstance
    this.playerConnections = new Map(); // socketId -> { playerId, gameId }
    this.waitingPlayers = new Map(); // playerId -> socket

    this._setupEventHandlers();
  }

  _setupEventHandlers() {
    this.io.on('connection', (socket) => {
      console.log('🔌 New WebSocket connection:', socket.id);

      // Handle disconnection
      socket.on('disconnect', () => this._handleDisconnect(socket));

      // Authentication
      socket.on('authenticate', (token) => this._handleAuthenticate(socket, token));

      // Game lobby actions
      socket.on('join_lobby', () => this._handleJoinLobby(socket));
      socket.on('leave_lobby', () => this._handleLeaveLobby(socket));
      socket.on('create_game', (gameOptions) => this._handleCreateGame(socket, gameOptions));
      socket.on('join_game', (gameId) => this._handleJoinGame(socket, gameId));
      socket.on('leave_game', () => this._handleLeaveGame(socket));

      // Game actions
      socket.on('game_action', (action) => this._handleGameAction(socket, action));
      socket.on('chat_message', (message) => this._handleChatMessage(socket, message));
    });
  }

  _handleDisconnect(socket) {
    console.log('❌ Disconnected:', socket.id);

    // Remove from player connections
    const connection = this.playerConnections.get(socket.id);
    if (connection) {
      this._handleLeaveGame(socket, connection.gameId);
      this.playerConnections.delete(socket.id);
    }

    // Remove from waiting players
    for (const [playerId, playerSocket] of this.waitingPlayers) {
      if (playerSocket.id === socket.id) {
        this.waitingPlayers.delete(playerId);
        break;
      }
    }
  }

  async _handleAuthenticate(socket, token) {
    try {
      if (!token) {
        socket.emit('auth_error', { error: 'No token provided' });
        return;
      }

      // Verify JWT token
      const decoded = await verifyToken(token);
      const playerId = decoded.userId;

      // Store authentication
      socket.playerId = playerId;
      socket.playerName = decoded.username;

      console.log(`🔐 Authenticated player: ${playerId} (${socket.id})`);
      socket.emit('auth_success', {
        playerId,
        username: decoded.username,
        email: decoded.email
      });

      // Add to waiting players
      this.waitingPlayers.set(playerId, socket);

    } catch (error) {
      console.error('Authentication error:', error.message);
      socket.emit('auth_error', { error: 'Invalid or expired token' });
    }
  }

  _handleJoinLobby(socket) {
    if (!socket.playerId) {
      socket.emit('error', { error: 'Not authenticated' });
      return;
    }

    console.log(`🏠 Player ${socket.playerId} joined lobby`);

    // Send available games
    const availableGames = this._getAvailableGames();
    socket.emit('lobby_update', availableGames);

    // Add to lobby
    socket.join('lobby');
  }

  _handleLeaveLobby(socket) {
    socket.leave('lobby');
    console.log(`🏠 Player ${socket.playerId} left lobby`);
  }

  _handleCreateGame(socket, gameOptions) {
    if (!socket.playerId) {
      socket.emit('error', { error: 'Not authenticated' });
      return;
    }

    try {
      // Create new game instance
      const gameId = `game_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
      const game = new TexasHoldem({
        smallBlind: gameOptions.smallBlind || 10,
        bigBlind: gameOptions.bigBlind || 20,
        ante: gameOptions.ante || 0
      });

      // Add creator to game
      game.addPlayer({
        id: socket.playerId,
        name: socket.playerName,
        chips: gameOptions.startingChips || 1000
      });

      // Store game
      this.games.set(gameId, game);

      // Add player to game
      this.playerConnections.set(socket.id, {
        playerId: socket.playerId,
        gameId: gameId
      });

      // Join game room
      socket.join(gameId);

      console.log(`🎮 Player ${socket.playerId} created game ${gameId}`);

      // Send game created confirmation
      socket.emit('game_created', {
        gameId,
        game: this._getGameInfo(gameId, socket.playerId)
      });

      // Notify lobby of new game
      this._broadcastAvailableGames();

    } catch (error) {
      console.error('Game creation error:', error);
      socket.emit('error', { error: 'Failed to create game' });
    }
  }

  _handleJoinGame(socket, gameId) {
    if (!socket.playerId) {
      socket.emit('error', { error: 'Not authenticated' });
      return;
    }

    if (!this.games.has(gameId)) {
      socket.emit('error', { error: 'Game not found' });
      return;
    }

    try {
      const game = this.games.get(gameId);

      // Check if game has started
      if (game.gameState !== 'waiting') {
        socket.emit('error', { error: 'Game already started' });
        return;
      }

      // Check if player is already in game
      if (game.players.some(p => p.id === socket.playerId)) {
        socket.emit('error', { error: 'Already in game' });
        return;
      }

      // Add player to game
      game.addPlayer({
        id: socket.playerId,
        name: socket.playerName,
        chips: 1000 // Default starting chips
      });

      // Track connection
      this.playerConnections.set(socket.id, {
        playerId: socket.playerId,
        gameId: gameId
      });

      // Join game room
      socket.join(gameId);

      console.log(`🎮 Player ${socket.playerId} joined game ${gameId}`);

      // Notify all players in game
      this.io.to(gameId).emit('player_joined', {
        playerId: socket.playerId,
        playerName: socket.playerName,
        game: this._getGameInfo(gameId, socket.playerId)
      });

      // Send current game state to new player
      socket.emit('game_state', this._getGameState(gameId, socket.playerId));

      // Update lobby
      this._broadcastAvailableGames();

    } catch (error) {
      console.error('Game join error:', error);
      socket.emit('error', { error: 'Failed to join game' });
    }
  }

  _handleLeaveGame(socket, gameId) {
    const connection = this.playerConnections.get(socket.id);
    if (!connection) return;

    gameId = gameId || connection.gameId;
    const playerId = connection.playerId;

    if (!this.games.has(gameId)) return;

    try {
      const game = this.games.get(gameId);

      // Remove player from game
      game.players = game.players.filter(p => p.id !== playerId);

      // Remove connection tracking
      this.playerConnections.delete(socket.id);

      // Leave game room
      socket.leave(gameId);

      console.log(`🎮 Player ${playerId} left game ${gameId}`);

      // Notify remaining players
      this.io.to(gameId).emit('player_left', {
        playerId,
        game: this._getGameInfo(gameId)
      });

      // If game is empty, remove it
      if (game.players.length === 0) {
        this.games.delete(gameId);
        console.log(`🗑️  Game ${gameId} removed (empty)`);
      }

      // Update lobby
      this._broadcastAvailableGames();

    } catch (error) {
      console.error('Game leave error:', error);
    }
  }

  _handleGameAction(socket, action) {
    const connection = this.playerConnections.get(socket.id);
    if (!connection) {
      socket.emit('error', { error: 'Not in a game' });
      return;
    }

    const { gameId } = connection;
    const game = this.games.get(gameId);

    if (!game) {
      socket.emit('error', { error: 'Game not found' });
      return;
    }

    try {
      let result;

      switch (action.type) {
        case 'start_game':
          result = game.startGame();
          break;

        case 'bet':
          result = game.bet(connection.playerId, action.amount);
          break;

        case 'call':
          result = game.call(connection.playerId);
          break;

        case 'check':
          result = game.check(connection.playerId);
          break;

        case 'fold':
          result = game.fold(connection.playerId);
          break;

        default:
          socket.emit('error', { error: 'Invalid action type' });
          return;
      }

      // Broadcast game state update to all players
      this.io.to(gameId).emit('game_update', this._getGameState(gameId, connection.playerId));

      // If game is over, announce winners
      if (game.gameState === 'showdown' && game.winners.length > 0) {
        this.io.to(gameId).emit('game_over', {
          winners: game.winners,
          gameId
        });
      }

    } catch (error) {
      console.error('Game action error:', error);
      socket.emit('error', { error: error.message });
    }
  }

  _handleChatMessage(socket, message) {
    const connection = this.playerConnections.get(socket.id);
    if (!connection) {
      socket.emit('error', { error: 'Not in a game' });
      return;
    }

    const { gameId } = connection;

    // Broadcast chat message to game room
    this.io.to(gameId).emit('chat_message', {
      playerId: connection.playerId,
      playerName: socket.playerName,
      message: message,
      timestamp: new Date().toISOString()
    });
  }

  _getAvailableGames() {
    return Array.from(this.games.entries()).map(([gameId, game]) => ({
      gameId,
      playerCount: game.players.length,
      maxPlayers: 10, // Default max
      smallBlind: game.smallBlind,
      bigBlind: game.bigBlind,
      gameState: game.gameState,
      createdAt: game.createdAt || new Date()
    }));
  }

  _getGameInfo(gameId, playerId = null) {
    const game = this.games.get(gameId);
    if (!game) return null;

    return {
      gameId,
      playerCount: game.players.length,
      maxPlayers: 10,
      smallBlind: game.smallBlind,
      bigBlind: game.bigBlind,
      gameState: game.gameState,
      players: game.players.map(p => ({
        id: p.id,
        name: p.name,
        chips: p.chips,
        isCurrentPlayer: p.id === playerId
      }))
    };
  }

  _getGameState(gameId, playerId = null) {
    const game = this.games.get(gameId);
    if (!game) return null;

    const gameState = game._getGameState();

    // Hide other players' cards if game is not over
    if (game.gameState !== 'showdown') {
      gameState.players = gameState.players.map(player => {
        if (player.id !== playerId) {
          return {
            ...player,
            hand: player.isFolded ? [] : ['??', '??'] // Hide cards
          };
        }
        return player;
      });
    }

    return gameState;
  }

  _broadcastAvailableGames() {
    const availableGames = this._getAvailableGames();
    this.io.to('lobby').emit('available_games', availableGames);
  }
}

module.exports = GameServer;