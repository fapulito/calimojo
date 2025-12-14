const express = require('express');
const router = express.Router();
const Session = require('../lib/models/Session');
const { jwtAuth } = require('../lib/middleware/jwt');
const authenticate = require('../lib/middleware/authenticate');

// Get user's active sessions
router.get('/active', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const activeSessions = await Session.getActiveSessions(userId);

    res.json({
      success: true,
      activeSessions: activeSessions.map(session => ({
        id: session.id,
        ipAddress: session.ipAddress,
        deviceType: session.deviceType,
        loginTime: session.loginTime,
        lastActivity: session.lastActivity
      }))
    });
  } catch (error) {
    console.error('Error fetching active sessions:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to fetch active sessions'
    });
  }
});

// Get session history
router.get('/history', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const limitRaw = Number.parseInt(req.query.limit, 10);
    const limit = Number.isFinite(limitRaw) ? Math.min(Math.max(limitRaw, 1), 100) : 10;

    const sessionHistory = await Session.getSessionHistory(userId, limit);

    res.json({
      success: true,
      sessionHistory: sessionHistory.map(session => ({
        id: session.id,
        ipAddress: session.ipAddress,
        deviceType: session.deviceType,
        loginTime: session.loginTime,
        logoutTime: session.logoutTime,
        duration: session.logoutTime ? new Date(session.logoutTime) - new Date(session.loginTime) : null
      }))
    });
  } catch (error) {
    console.error('Error fetching session history:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to fetch session history'
    });
  }
});

// Admin: Get all active sessions (JWT protected)
router.get('/admin/active', jwtAuth, async (req, res) => {
  try {
    // Check if user is admin
    if (!req.user.role || req.user.role !== 'admin') {
      return res.status(403).json({
        error: 'Forbidden',
        message: 'Admin access required'
      });
    }

    const allSessions = await Session.getAllActiveSessions();

    res.json({
      success: true,
      totalActiveSessions: allSessions.length,
      sessions: allSessions.map(session => ({
        id: session.id,
        userId: session.userId,
        ipAddress: session.ipAddress,
        deviceType: session.deviceType,
        loginTime: session.loginTime,
        lastActivity: session.lastActivity
      }))
    });
  } catch (error) {
    console.error('Error fetching all active sessions:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to fetch active sessions'
    });
  }
});

// Terminate specific session
router.post('/terminate', authenticate, async (req, res) => {
  try {
    const { sessionId } = req.body;
    const userId = req.user.id;

    // Get the session to verify it belongs to the user
    const activeSessions = await Session.getActiveSessions(userId);
    const sessionToTerminate = activeSessions.find(s => s.id === sessionId);

    if (!sessionToTerminate) {
      return res.status(404).json({
        error: 'Not Found',
        message: 'Session not found or already terminated'
      });
    }

    // Terminate the session
    await Session.trackLogout(sessionId);

    res.json({
      success: true,
      message: 'Session terminated successfully'
    });
  } catch (error) {
    console.error('Error terminating session:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to terminate session'
    });
  }
});

// Terminate all other sessions (keep current one)
router.post('/terminate-others', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const currentSessionId = req.session.id; // This would need to be properly tracked

    // Get all active sessions for the user
    const activeSessions = await Session.getActiveSessions(userId);

    // Terminate all sessions except the current one
    for (const session of activeSessions) {
      if (session.id !== currentSessionId) {
        await Session.trackLogout(session.id);
      }
    }

    res.json({
      success: true,
      message: 'All other sessions terminated successfully'
    });
  } catch (error) {
    console.error('Error terminating other sessions:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to terminate other sessions'
    });
  }
});

module.exports = router;