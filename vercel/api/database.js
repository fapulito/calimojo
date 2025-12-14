const express = require('express');
const router = express.Router();
const { pool } = require('../lib/db');
const User = require('../lib/models/User');
const Game = require('../lib/models/Game');
const authenticate = require('../lib/middleware/authenticate');

// User API Endpoints

// Get current user profile
router.get('/users/me', authenticate, async (req, res) => {
  try {
    const user = await User.findByPk(req.user.id);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json(user.getPublicProfile());
  } catch (error) {
    console.error('Error fetching user profile:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get user by ID
router.get('/users/:id', authenticate, async (req, res) => {
  try {
    const user = await User.findByPk(req.params.id);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json(user.getPublicProfile());
  } catch (error) {
    console.error('Error fetching user:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update user profile
router.put('/users/me', authenticate, async (req, res) => {
  try {
    const user = await User.findByPk(req.user.id);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const { displayName, username } = req.body;
    if (displayName) user.display_name = displayName;
    if (username) user.username = username;

    await user.save();
    res.json(user.getPublicProfile());
  } catch (error) {
    console.error('Error updating user profile:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get user chips balance
router.get('/users/me/chips', authenticate, async (req, res) => {
  try {
    const user = await User.findByPk(req.user.id);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json({ chips: user.chips });
  } catch (error) {
    console.error('Error fetching user chips:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Add chips to user (admin only)
router.post('/users/:id/chips', authenticate, async (req, res) => {
  try {
    // Check if user is admin
    const currentUser = await User.findByPk(req.user.id);
    if (!currentUser.is_admin) {
      return res.status(403).json({ error: 'Admin access required' });
    }

    const user = await User.findByPk(req.params.id);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const { amount } = req.body;
    if (!amount || amount <= 0) {
      return res.status(400).json({ error: 'Invalid amount' });
    }

    const newBalance = await user.addChips(amount);
    res.json({
      success: true,
      newBalance: newBalance,
      message: `Added ${amount} chips to user ${user.id}`
    });
  } catch (error) {
    console.error('Error adding chips:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Game API Endpoints

// Get all games
router.get('/games', async (req, res) => {
  try {
    const games = await Game.getAllGames();
    res.json(games.map(game => game.getGameInfo()));
  } catch (error) {
    console.error('Error fetching games:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get active games
router.get('/games/active', async (req, res) => {
  try {
    const games = await Game.getActiveGames();
    res.json(games.map(game => game.getGameInfo()));
  } catch (error) {
    console.error('Error fetching active games:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get game by ID
router.get('/games/:id', async (req, res) => {
  try {
    const game = await Game.findByPk(req.params.id);
    if (!game) {
      return res.status(404).json({ error: 'Game not found' });
    }
    res.json(game.getGameInfo());
  } catch (error) {
    console.error('Error fetching game:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create new game (admin only)
router.post('/games', authenticate, async (req, res) => {
  try {
    // Check if user is admin
    const currentUser = await User.findByPk(req.user.id);
    if (!currentUser.is_admin) {
      return res.status(403).json({ error: 'Admin access required' });
    }

    const { name, type, minPlayers, maxPlayers, smallBlind, bigBlind, ante, isTournament } = req.body;

    if (!name || !type) {
      return res.status(400).json({ error: 'Name and type are required' });
    }

    const game = await Game.createGame({
      name,
      type,
      minPlayers,
      maxPlayers,
      smallBlind,
      bigBlind,
      ante,
      isTournament
    });

    res.status(201).json(game.getGameInfo());
  } catch (error) {
    console.error('Error creating game:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update game (admin only)
router.put('/games/:id', authenticate, async (req, res) => {
  try {
    // Check if user is admin
    const currentUser = await User.findByPk(req.user.id);
    if (!currentUser.is_admin) {
      return res.status(403).json({ error: 'Admin access required' });
    }

    const game = await Game.findByPk(req.params.id);
    if (!game) {
      return res.status(404).json({ error: 'Game not found' });
    }

    const { name, minPlayers, maxPlayers, smallBlind, bigBlind, ante, isActive } = req.body;

    if (name) game.name = name;
    if (minPlayers) game.min_players = minPlayers;
    if (maxPlayers) game.max_players = maxPlayers;
    if (smallBlind) game.small_blind = smallBlind;
    if (bigBlind) game.big_blind = bigBlind;
    if (ante) game.ante = ante;
    if (isActive !== undefined) game.is_active = isActive;

    game.updated_at = new Date();
    await game.save();

    res.json(game.getGameInfo());
  } catch (error) {
    console.error('Error updating game:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Toggle game active status (admin only)
router.patch('/games/:id/toggle', authenticate, async (req, res) => {
  try {
    // Check if user is admin
    const currentUser = await User.findByPk(req.user.id);
    if (!currentUser.is_admin) {
      return res.status(403).json({ error: 'Admin access required' });
    }

    const game = await Game.findByPk(req.params.id);
    if (!game) {
      return res.status(404).json({ error: 'Game not found' });
    }

    const newStatus = await game.toggleActiveStatus();
    res.json({
      success: true,
      isActive: newStatus,
      message: `Game ${game.name} is now ${newStatus ? 'active' : 'inactive'}`
    });
  } catch (error) {
    console.error('Error toggling game status:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Database health check
router.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT NOW()');
    res.json({
      status: 'healthy',
      database: 'PostgreSQL',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Database health check failed:', error);
    res.status(503).json({
      status: 'unhealthy',
      error: 'Database connection failed'
    });
  }
});

module.exports = router;