const { DataTypes } = require('sequelize');
const { sequelize } = require('../db');
const { isMockMode } = require('../models/User');

// Check if we're in mock mode
const isSessionMockMode = typeof sequelize.define !== 'function' || sequelize.define.toString().includes('Mock sequelize.define');

// Session model for tracking user sessions
if (isSessionMockMode) {
  console.log('🔧 Using mock Session model');

  // Mock session storage
  const mockSessions = new Map();

  module.exports = {
    // Track user login
    trackLogin: async (userId, sessionData) => {
      console.log('Mock Session.trackLogin:', userId, sessionData);
      const sessionId = `session_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;

      const session = {
        id: sessionId,
        userId,
        ipAddress: sessionData.ipAddress,
        userAgent: sessionData.userAgent,
        deviceType: sessionData.deviceType,
        loginTime: new Date(),
        lastActivity: new Date(),
        isActive: true
      };

      mockSessions.set(sessionId, session);
      return session;
    },

    // Update session activity
    updateActivity: async (sessionId) => {
      console.log('Mock Session.updateActivity:', sessionId);
      const session = mockSessions.get(sessionId);
      if (session) {
        session.lastActivity = new Date();
        return true;
      }
      return false;
    },

    // Track logout
    trackLogout: async (sessionId) => {
      console.log('Mock Session.trackLogout:', sessionId);
      const session = mockSessions.get(sessionId);
      if (session) {
        session.isActive = false;
        session.logoutTime = new Date();
        return true;
      }
      return false;
    },

    // Get active sessions for user
    getActiveSessions: async (userId) => {
      console.log('Mock Session.getActiveSessions:', userId);
      return Array.from(mockSessions.values())
        .filter(s => s.userId === userId && s.isActive);
    },

    // Get session history
    getSessionHistory: async (userId, limit = 10) => {
      console.log('Mock Session.getSessionHistory:', userId, limit);
      return Array.from(mockSessions.values())
        .filter(s => s.userId === userId)
        .slice(0, limit);
    },

    // Get all active sessions (admin)
    getAllActiveSessions: async () => {
      console.log('Mock Session.getAllActiveSessions');
      return Array.from(mockSessions.values()).filter(s => s.isActive);
    }
  };
} else {
  console.log('🔧 Using real Sequelize Session model');

  const Session = sequelize.define('Session', {
    id: {
      type: DataTypes.STRING(255),
      primaryKey: true
    },
    userId: {
      type: DataTypes.INTEGER,
      allowNull: false
    },
    ipAddress: {
      type: DataTypes.STRING(45)
    },
    userAgent: {
      type: DataTypes.TEXT
    },
    deviceType: {
      type: DataTypes.STRING(50)
    },
    loginTime: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW
    },
    lastActivity: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW
    },
    logoutTime: {
      type: DataTypes.DATE
    },
    isActive: {
      type: DataTypes.BOOLEAN,
      defaultValue: true
    }
  }, {
    tableName: 'sessions',
    timestamps: false
  });

  // Add custom methods
  Session.trackLogin = async function(userId, sessionData) {
    const sessionId = `session_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;

    return await this.create({
      id: sessionId,
      userId,
      ipAddress: sessionData.ipAddress,
      userAgent: sessionData.userAgent,
      deviceType: sessionData.deviceType
    });
  };

  Session.updateActivity = async function(sessionId) {
    const result = await this.update(
      { lastActivity: new Date() },
      { where: { id: sessionId, isActive: true } }
    );
    return result[0] > 0;
  };

  Session.trackLogout = async function(sessionId) {
    const result = await this.update(
      { isActive: false, logoutTime: new Date() },
      { where: { id: sessionId } }
    );
    return result[0] > 0;
  };

  Session.getActiveSessions = async function(userId) {
    return await this.findAll({
      where: { userId, isActive: true },
      order: [['lastActivity', 'DESC']]
    });
  };

  Session.getSessionHistory = async function(userId, limit = 10) {
    return await this.findAll({
      where: { userId },
      order: [['loginTime', 'DESC']],
      limit: limit
    });
  };

  Session.getAllActiveSessions = async function() {
    return await this.findAll({
      where: { isActive: true },
      order: [['lastActivity', 'DESC']]
    });
  };

  module.exports = Session;
}