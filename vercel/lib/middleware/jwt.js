const jwt = require('jsonwebtoken');
const { pool } = require('../db');
const User = require('../models/User');

// JWT Configuration
const JWT_SECRET = process.env.JWT_SECRET || 'default_jwt_secret_change_in_production';
const ACCESS_TOKEN_EXPIRE = process.env.JWT_ACCESS_EXPIRE || '15m';
const REFRESH_TOKEN_EXPIRE = process.env.JWT_REFRESH_EXPIRE || '7d';

// Generate JWT tokens
const generateTokens = async (userId) => {
  try {
    const user = await User.findByPk(userId);
    if (!user) {
      throw new Error('User not found');
    }

    // Access token (short-lived)
    const accessToken = jwt.sign(
      {
        userId: user.id,
        username: user.username,
        email: user.email,
        role: user.is_admin ? 'admin' : 'user'
      },
      JWT_SECRET,
      { expiresIn: ACCESS_TOKEN_EXPIRE }
    );

    // Refresh token (long-lived)
    const refreshToken = jwt.sign(
      { userId: user.id },
      JWT_SECRET,
      { expiresIn: REFRESH_TOKEN_EXPIRE }
    );

    return { accessToken, refreshToken };
  } catch (error) {
    console.error('Token generation error:', error);
    throw new Error('Failed to generate tokens');
  }
};

// Verify JWT token
const verifyToken = (token) => {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (error) {
    console.error('Token verification error:', error);
    throw new Error('Invalid or expired token');
  }
};

// JWT Authentication Middleware
const jwtAuth = (req, res, next) => {
  try {
    // Check for token in headers, query, or cookies
    const token = req.headers.authorization?.split(' ')[1]
      || req.cookies.token;

    if (!token) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'No token provided'
      });
    }

    // Verify token
    const decoded = verifyToken(token);
    req.user = decoded;
    req.token = token;

    next();
  } catch (error) {
    return res.status(401).json({
      error: 'Unauthorized',
      message: error.message
    });
  }
};

// Refresh Token Middleware
const refreshToken = async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Refresh token required'
      });
    }

    // Verify refresh token
    const decoded = verifyToken(refreshToken);

    // Generate new tokens
    const tokens = await generateTokens(decoded.userId);

    res.json({
      success: true,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken
    });
  } catch (error) {
    res.status(401).json({
      error: 'Unauthorized',
      message: error.message
    });
  }
};

// Add JWT token to user model
User.prototype.generateAuthTokens = async function() {
  return generateTokens(this.id);
};

module.exports = {
  generateTokens,
  verifyToken,
  jwtAuth,
  refreshToken,
  JWT_SECRET,
  ACCESS_TOKEN_EXPIRE,
  REFRESH_TOKEN_EXPIRE
};