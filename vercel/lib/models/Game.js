const { DataTypes } = require('sequelize');
const { sequelize } = require('../db');

// Check if we're in mock mode - check if sequelize.define is the mock version
const isMockMode = typeof sequelize.define !== 'function' || sequelize.define.toString().includes('Mock sequelize.define');

// Mock game prototype
const GamePrototype = {
  getGameInfo: function() {
    return {
      id: this.id,
      name: this.name,
      type: this.game_type,
      players: `${this.min_players}-${this.max_players}`,
      blinds: this.small_blind > 0 ? `${this.small_blind}/${this.big_blind}` : 'None',
      ante: this.ante,
      isActive: this.is_active,
      isTournament: this.is_tournament
    };
  },

  toggleActiveStatus: async function() {
    this.is_active = !this.is_active;
    return this.is_active;
  }
};

// Create and export Game model
if (isMockMode) {
  console.log('🔧 Using mock Game model');
  module.exports = {
    findByPk: async (id) => {
      console.log('Mock Game.findByPk:', id);
      const game = Object.create(GamePrototype);
      game.id = id;
      game.name = `Test Game ${id}`;
      game.game_type = 'holdem';
      game.min_players = 2;
      game.max_players = 10;
      game.small_blind = 10;
      game.big_blind = 20;
      game.is_active = true;
      return game;
    },

    findAll: async (options) => {
      console.log('Mock Game.findAll:', options);
      const games = [
        { id: 1, name: 'Texas Holdem', game_type: 'holdem', min_players: 2, max_players: 10, small_blind: 10, big_blind: 20, is_active: true },
        { id: 2, name: 'Omaha Hi-Lo', game_type: 'omaha', min_players: 2, max_players: 9, small_blind: 5, big_blind: 10, is_active: true }
      ].map(game => {
        const gameObj = Object.create(GamePrototype);
        Object.assign(gameObj, game);
        return gameObj;
      });
      return games;
    },

    create: async (data) => {
      console.log('Mock Game.create:', data);
      const game = Object.create(GamePrototype);
      game.id = 3;
      Object.assign(game, data);
      game.is_active = false;
      return game;
    },

    createGame: async function(gameData) {
      return this.create({
        name: gameData.name,
        game_type: gameData.type,
        min_players: gameData.minPlayers || 2,
        max_players: gameData.maxPlayers || 10,
        small_blind: gameData.smallBlind || 0,
        big_blind: gameData.bigBlind || 0,
        ante: gameData.ante || 0,
        is_tournament: gameData.isTournament || false
      });
    },

    getActiveGames: async function() {
      const games = await this.findAll();
      return games.filter(game => game.is_active);
    },

    getAllGames: async function() {
      return await this.findAll();
    }
  };
} else {
  console.log('🔧 Using real Sequelize Game model');
  const Game = sequelize.define('Game', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    name: {
      type: DataTypes.STRING(255),
      allowNull: false
    },
    game_type: {
      type: DataTypes.STRING(50),
      allowNull: false
    },
    min_players: {
      type: DataTypes.INTEGER,
      defaultValue: 2
    },
    max_players: {
      type: DataTypes.INTEGER,
      defaultValue: 10
    },
    small_blind: {
      type: DataTypes.INTEGER,
      defaultValue: 0
    },
    big_blind: {
      type: DataTypes.INTEGER,
      defaultValue: 0
    },
    ante: {
      type: DataTypes.INTEGER,
      defaultValue: 0
    },
    is_active: {
      type: DataTypes.BOOLEAN,
      defaultValue: false
    },
    is_tournament: {
      type: DataTypes.BOOLEAN,
      defaultValue: false
    },
    created_at: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW
    },
    updated_at: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW
    }
  }, {
    tableName: 'games',
    timestamps: false
  });

  // Add custom methods
  Game.createGame = async function(gameData) {
    return await this.create({
      name: gameData.name,
      game_type: gameData.type,
      min_players: gameData.minPlayers || 2,
      max_players: gameData.maxPlayers || 10,
      small_blind: gameData.smallBlind || 0,
      big_blind: gameData.bigBlind || 0,
      ante: gameData.ante || 0,
      is_tournament: gameData.isTournament || false
    });
  };

  Game.getActiveGames = async function() {
    return await this.findAll({
      where: { is_active: true },
      order: [['created_at', 'DESC']]
    });
  };

  Game.getAllGames = async function() {
    return await this.findAll({
      order: [['created_at', 'DESC']]
    });
  };

  module.exports = Game;
}