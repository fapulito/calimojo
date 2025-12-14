const { DataTypes } = require('sequelize');
const { sequelize } = require('../db');

// Check if we're in mock mode - check if sequelize.define is the mock version
const isMockMode = typeof sequelize.define !== 'function' || sequelize.define.toString().includes('Mock sequelize.define');

// Mock user prototype
const UserPrototype = {
  getPublicProfile: function() {
    return {
      id: this.id,
      displayName: this.display_name,
      username: this.username,
      email: this.email,
      profilePicture: this.profile_picture,
      chips: this.chips,
      isAdmin: this.is_admin
    };
  },

  addChips: async function(amount) {
    if (amount <= 0) {
      throw new Error('Amount must be positive');
    }
    this.chips += amount;
    return this.chips;
  },

  deductChips: async function(amount) {
    if (amount <= 0) {
      throw new Error('Amount must be positive');
    }
    if (this.chips < amount) {
      throw new Error('Insufficient chips');
    }
    this.chips -= amount;
    return this.chips;
  }
};

// Create and export User model
if (isMockMode) {
  console.log('🔧 Using mock User model');
  module.exports = {
    findByPk: async (id) => {
      console.log('Mock User.findByPk:', id);
      const user = Object.create(UserPrototype);
      user.id = id;
      user.facebook_id = `fb_${id}`;
      user.display_name = `Test User ${id}`;
      user.email = `user${id}@test.com`;
      user.chips = 400;
      user.is_admin = false;
      return user;
    },

    findOrCreate: async (options) => {
      console.log('Mock User.findOrCreate:', options);
      const user = Object.create(UserPrototype);
      user.id = Math.floor(Math.random() * 1000) + 1;
      user.facebook_id = options.where.facebook_id;
      user.display_name = options.defaults.display_name;
      user.email = options.defaults.email;
      user.profile_picture = options.defaults.profile_picture;
      user.facebook_access_token = options.defaults.facebook_access_token;
      user.chips = options.defaults.chips || 400;
      user.is_admin = false;
      user.created_at = new Date();
      return [user, true];
    },

    findOrCreateByFacebook: async (facebookId, profileData) => {
      return this.findOrCreate({
        where: { facebook_id: facebookId },
        defaults: {
          display_name: profileData.displayName,
          email: profileData.email,
          profile_picture: profileData.photo,
          facebook_access_token: profileData.accessToken,
          chips: 400
        }
      });
    },

    findAll: async () => [],
    create: async (data) => ({})
  };
} else {
  console.log('🔧 Using real Sequelize User model');
  const User = sequelize.define('User', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    facebook_id: {
      type: DataTypes.STRING(255),
      unique: true,
      allowNull: false
    },
    username: {
      type: DataTypes.STRING(255),
      unique: true
    },
    display_name: {
      type: DataTypes.STRING(255),
      allowNull: false
    },
    email: {
      type: DataTypes.STRING(255)
    },
    profile_picture: {
      type: DataTypes.STRING(512)
    },
    chips: {
      type: DataTypes.BIGINT,
      defaultValue: 400
    },
    facebook_access_token: {
      type: DataTypes.TEXT
    },
    is_admin: {
      type: DataTypes.BOOLEAN,
      defaultValue: false
    },
    created_at: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW
    },
    last_login: {
      type: DataTypes.DATE
    }
  }, {
    tableName: 'users',
    timestamps: false
  });

  // Add custom methods
  User.findOrCreateByFacebook = async function(facebookId, profileData) {
    const [user, created] = await this.findOrCreate({
      where: { facebook_id: facebookId },
      defaults: {
        display_name: profileData.displayName,
        email: profileData.email,
        profile_picture: profileData.photo,
        facebook_access_token: profileData.accessToken,
        chips: 400
      }
    });

    if (!created) {
      await user.update({
        display_name: profileData.displayName,
        email: profileData.email,
        profile_picture: profileData.photo,
        facebook_access_token: profileData.accessToken,
        last_login: new Date()
      });
    }

    return user;
  };

  module.exports = User;
}