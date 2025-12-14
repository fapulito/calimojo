const Session = require('../models/Session');
const { isMockMode } = require('../models/User');

// Device detection from user agent
const detectDeviceType = (userAgent) => {
  if (!userAgent) return 'unknown';

  const userAgentLower = userAgent.toLowerCase();

  if (userAgentLower.includes('mobile') || userAgentLower.includes('android') || userAgentLower.includes('iphone')) {
    return 'mobile';
  } else if (userAgentLower.includes('tablet') || userAgentLower.includes('ipad')) {
    return 'tablet';
  } else {
    return 'desktop';
  }
};

// Session tracking middleware
const trackSession = async (req, res, next) => {
  try {
    // Only track for authenticated users
    if (!req.isAuthenticated()) {
      return next();
    }

    const userId = req.user.id;
    const ipAddress = req.ip || req.connection.remoteAddress;
    const userAgent = req.headers['user-agent'] || 'unknown';
    const deviceType = detectDeviceType(userAgent);

    // Track login if this is a new session
    if (req.session.isNew) {
      const sessionData = {
        ipAddress,
        userAgent,
        deviceType
      };

      await Session.trackLogin(userId, sessionData);
    } else {
      // Update last activity for existing session
      // In a real app, you would track the session ID
      await Session.updateActivity(`session_${userId}_current`);
    }

    next();
  } catch (error) {
    console.error('Session tracking error:', error);
    next(); // Don't fail the request if tracking fails
  }
};

// Multi-device session management
const checkMultiDeviceSessions = async (req, res, next) => {
  try {
    if (!req.isAuthenticated()) {
      return next();
    }

    const userId = req.user.id;
    const currentIp = req.ip || req.connection.remoteAddress;

    // Get all active sessions for this user
    const activeSessions = await Session.getActiveSessions(userId);

    // Check for suspicious activity (different IPs)
    const differentIps = activeSessions.filter(s => s.ipAddress !== currentIp);

    if (differentIps.length > 0) {
      console.warn(`🔍 Multiple devices detected for user ${userId}:`, differentIps);
      // In a real app, you might want to notify the user or require re-authentication
    }

    next();
  } catch (error) {
    console.error('Multi-device check error:', error);
    next();
  }
};

module.exports = {
  trackSession,
  checkMultiDeviceSessions,
  detectDeviceType
};