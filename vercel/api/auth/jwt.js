const express = require('express');
const router = express.Router();
const { jwtAuth, refreshToken, generateTokens } = require('../../lib/middleware/jwt');
const User = require('../../lib/models/User');
const authenticate = require('../../lib/middleware/authenticate');

// Login with JWT
router.post('/login', authenticate, async (req, res) => {
  try {
    // User is already authenticated via session
    const user = req.user;

    // Generate JWT tokens
    const tokens = await generateTokens(user.id);

    res.json({
      success: true,
      message: 'Login successful',
      user: {
        id: user.id,
        displayName: user.displayName,
        email: user.email,
        chips: user.chips,
        isAdmin: user.isAdmin
      },
      tokens: {
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken
      }
    });
  } catch (error) {
    console.error('JWT login error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to generate tokens'
    });
  }
});

// Token refresh endpoint
router.post('/refresh', refreshToken);

// Protected endpoint example
router.get('/protected', jwtAuth, (req, res) => {
  res.json({
    success: true,
    message: 'Access granted to protected resource',
    user: req.user
  });
});

// JWT validation endpoint
router.get('/validate', jwtAuth, (req, res) => {
  res.json({
    success: true,
    valid: true,
    user: req.user
  });
});

// Logout endpoint (invalidate tokens)
router.post('/logout', jwtAuth, async (req, res) => {
  try {
    // In a real implementation, you would add the token to a blacklist
    // For now, we just return success
    res.json({
      success: true,
      message: 'Logout successful'
    });
  } catch (error) {
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to process logout'
    });
  }
});

module.exports = router;