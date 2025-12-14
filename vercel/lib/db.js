require('dotenv').config();
const { Pool } = require('pg');
const session = require('express-session');
const pgSession = require('connect-pg-simple')(session);
const { Sequelize } = require('sequelize');

// PostgreSQL connection pool for direct queries
const connectionString = process.env.NEONDB_CONNECTION_STRING || process.env.DATABASE_URL;

let pool;
let sequelize;

if (connectionString) {
  pool = new Pool({
    connectionString: connectionString,
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
    max: 20, // Connection pool size for Vercel
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
  });

  // Sequelize instance for ORM
  sequelize = new Sequelize(connectionString, {
    dialect: 'postgres',
    protocol: 'postgres',
    dialectOptions: {
      ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
    },
    pool: {
      max: 20,
      min: 0,
      acquire: 30000,
      idle: 10000
    },
    logging: process.env.NODE_ENV === 'development' ? console.log : false
  });
} else {
  console.log('⚠️  No database connection string provided. Using mock database for testing.');
  // Mock pool for testing without database
  pool = {
    query: async (sql, params) => {
      console.log('Mock query:', sql, params);
      return { rows: [] };
    }
  };
  // Mock sequelize for testing
  sequelize = {
    // In mock mode, don't override custom model implementations
    // Just return a simple object that won't interfere
    define: (modelName, attributes, options) => {
      console.log(`Mock sequelize.define called for ${modelName}`);
      // Return an empty object that won't override our custom models
      return {};
    },
    authenticate: async () => {
      console.log('Mock database authentication');
      return Promise.resolve();
    }
  };
}

// Session store configuration
const sessionStore = new pgSession({
  pool: pool,
  tableName: 'sessions',
  createTableIfMissing: true,
  // Optional: You can specify custom schema if needed
  // schemaName: 'public'
});

// Test database connection
async function testDatabaseConnection() {
  try {
    await pool.query('SELECT NOW()');
    console.log('✅ PostgreSQL database connection established successfully');
    return true;
  } catch (error) {
    console.error('❌ Database connection error:', error.message);
    return false;
  }
}

// Initialize database tables if they don't exist
async function initializeDatabase() {
  try {
    // Create sessions table if it doesn't exist
    await pool.query(`
      CREATE TABLE IF NOT EXISTS sessions (
        sid VARCHAR(255) PRIMARY KEY,
        sess JSON NOT NULL,
        expire TIMESTAMP NOT NULL
      );
    `);

    // Create users table if it doesn't exist
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        facebook_id VARCHAR(255) UNIQUE,
        username VARCHAR(255) UNIQUE,
        display_name VARCHAR(255),
        email VARCHAR(255),
        profile_picture VARCHAR(512),
        chips BIGINT DEFAULT 400,
        created_at TIMESTAMP DEFAULT NOW(),
        last_login TIMESTAMP,
        facebook_access_token TEXT,
        is_admin BOOLEAN DEFAULT FALSE
      );
    `);

    // Create games table if it doesn't exist
    await pool.query(`
      CREATE TABLE IF NOT EXISTS games (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255),
        game_type VARCHAR(50),
        min_players INTEGER DEFAULT 2,
        max_players INTEGER DEFAULT 10,
        small_blind INTEGER DEFAULT 0,
        big_blind INTEGER DEFAULT 0,
        ante INTEGER DEFAULT 0,
        is_active BOOLEAN DEFAULT FALSE,
        is_tournament BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );
    `);

    // Create player_games table if it doesn't exist
    await pool.query(`
      CREATE TABLE IF NOT EXISTS player_games (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id),
        game_id INTEGER REFERENCES games(id),
        seat_position INTEGER,
        chips INTEGER,
        is_active BOOLEAN DEFAULT TRUE,
        joined_at TIMESTAMP DEFAULT NOW(),
        left_at TIMESTAMP,
        UNIQUE(user_id, game_id)
      );
    `);

    console.log('✅ Database tables initialized successfully');
    return true;
  } catch (error) {
    console.error('❌ Database initialization error:', error.message);
    return false;
  }
}

module.exports = {
  pool,
  sequelize,
  sessionStore,
  testDatabaseConnection,
  initializeDatabase
};