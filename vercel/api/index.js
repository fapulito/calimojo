require('dotenv').config();
const express = require('express');
const passport = require('passport');
const FacebookStrategy = require('passport-facebook').Strategy;
const cookieParser = require('cookie-parser');
const cors = require('cors');
const jwt = require('jsonwebtoken');

const app = express();

// JWT Configuration
const JWT_SECRET = process.env.JWT_SECRET || process.env.SESSION_SECRET || 'default_jwt_secret_change_me';
const JWT_EXPIRES_IN = '7d';
const COOKIE_MAX_AGE = 7 * 24 * 60 * 60 * 1000; // 7 days in ms

// Helper: Create JWT token
function createToken(user) {
  return jwt.sign(
    { 
      id: user.id, 
      displayName: user.displayName,
      email: user.email,
      photo: user.photo,
      isGuest: user.isGuest || false
    }, 
    JWT_SECRET, 
    { expiresIn: JWT_EXPIRES_IN }
  );
}

// Helper: Verify JWT token
function verifyToken(token) {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (err) {
    return null;
  }
}

// Helper: Set JWT cookie
function setAuthCookie(res, token) {
  res.cookie('auth_token', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: COOKIE_MAX_AGE
  });
}

// Helper: Clear JWT cookie
function clearAuthCookie(res) {
  res.clearCookie('auth_token', {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax'
  });
}

// Middleware setup
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cookieParser());
app.use(cors({
  origin: process.env.NODE_ENV === 'production' 
    ? process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : process.env.APP_URL 
    : 'http://localhost:3000',
  credentials: true
}));


// JWT Authentication Middleware (replaces session-based auth)
function authenticateJWT(req, res, next) {
  const token = req.cookies.auth_token;
  
  if (token) {
    const user = verifyToken(token);
    if (user) {
      req.user = user;
      req.isAuthenticated = () => true;
    } else {
      req.isAuthenticated = () => false;
    }
  } else {
    req.isAuthenticated = () => false;
  }
  next();
}

// Apply JWT middleware to all routes
app.use(authenticateJWT);

// Passport initialization (for Facebook OAuth flow only)
app.use(passport.initialize());

// Facebook Strategy - only configure if credentials are provided and valid
const facebookAuthEnabled = !!(process.env.FACEBOOK_APP_ID && process.env.FACEBOOK_APP_SECRET);

if (facebookAuthEnabled) {
  if (!process.env.FACEBOOK_APP_ID.trim() || !process.env.FACEBOOK_APP_SECRET.trim()) {
    console.error('ERROR: FACEBOOK_APP_ID or FACEBOOK_APP_SECRET is empty');
  } else {
    const callbackURL = process.env.FACEBOOK_CALLBACK_URL || '/auth/facebook/callback';
    console.log(`Facebook Auth: Enabled (callback: ${callbackURL})`);
    
    passport.use(new FacebookStrategy({
        clientID: process.env.FACEBOOK_APP_ID,
        clientSecret: process.env.FACEBOOK_APP_SECRET,
        callbackURL: callbackURL,
        profileFields: ['id', 'displayName', 'emails', 'photos']
      },
      function(accessToken, _refreshToken, profile, done) {
        const user = {
          id: profile.id,
          displayName: profile.displayName,
          email: profile.emails ? profile.emails[0].value : null,
          photo: profile.photos ? profile.photos[0].value : null
        };
        return done(null, user);
      }
    ));
  }
} else {
  console.log('Facebook Auth: Disabled (FACEBOOK_APP_ID or FACEBOOK_APP_SECRET not set)');
}

// Passport serialization (minimal - we use JWT for actual auth)
passport.serializeUser((user, done) => done(null, user));
passport.deserializeUser((user, done) => done(null, user));


// Facebook Auth Routes
if (facebookAuthEnabled) {
  app.get('/auth/facebook',
    passport.authenticate('facebook', { scope: ['email'], session: false })
  );

  app.get('/auth/facebook/callback',
    passport.authenticate('facebook', { failureRedirect: '/?error=auth_failed', session: false }),
    function(req, res) {
      // Create JWT token and set as HTTP-only cookie
      const token = createToken(req.user);
      setAuthCookie(res, token);
      res.redirect('/');
    }
  );
} else if (process.env.NODE_ENV === 'development') {
  // Dev mode ONLY: auto-login as guest when Facebook auth is not configured
  console.log('Dev mode: Guest login enabled (NODE_ENV=development)');
  app.get('/auth/facebook', (req, res) => {
    const guestUser = {
      id: 'dev_guest_' + Date.now(),
      displayName: 'Dev Guest',
      email: 'guest@localhost',
      photo: null,
      isGuest: true
    };
    
    const token = createToken(guestUser);
    setAuthCookie(res, token);
    console.log('Dev mode: Guest user logged in via JWT');
    res.redirect('/');
  });
} else {
  // Production without Facebook auth configured - reject with 403
  console.warn('WARNING: Facebook auth not configured in production. /auth/facebook will return 403.');
  app.get('/auth/facebook', (_req, res) => {
    console.warn('Blocked guest login attempt in non-development environment');
    res.status(403).json({
      error: 'Authentication not available',
      message: 'Facebook authentication is not configured and guest login is disabled in production.'
    });
  });
}

// Logout route - clear JWT cookie
app.get('/logout', (_req, res) => {
  clearAuthCookie(res);
  res.redirect('/');
});

// API route to check authentication status
app.get('/api/auth/status', (req, res) => {
  if (req.isAuthenticated()) {
    res.json({
      authenticated: true,
      user: {
        id: req.user.id,
        displayName: req.user.displayName,
        email: req.user.email,
        photo: req.user.photo,
        isGuest: req.user.isGuest
      }
    });
  } else {
    res.json({
      authenticated: false
    });
  }
});


// API route for poker games
app.get('/api/poker/games', (_req, res) => {
  res.json({
    games: [
      { id: 1, name: "Texas Hold'em", players: '2-10', type: 'ring' },
      { id: 2, name: 'Omaha Hi-Lo', players: '2-9', type: 'ring' },
      { id: 3, name: '7 Card Stud', players: '2-8', type: 'ring' }
    ]
  });
});

// API route to join a poker game
app.post('/api/poker/join', (req, res) => {
  if (!req.isAuthenticated()) {
    return res.status(401).json({
      success: false,
      message: 'You must be logged in to join a game'
    });
  }

  const { gameId } = req.body;
  if (!gameId) {
    return res.status(400).json({
      success: false,
      message: 'Game ID is required'
    });
  }

  // In production, this would connect to the Perl backend
  const backendUrl = process.env.BACKEND_WS_URL || 'ws://localhost:8080';
  
  res.json({
    success: true,
    message: 'Game join request processed',
    gameId: gameId,
    websocketUrl: backendUrl,
    user: {
      id: req.user.id,
      displayName: req.user.displayName
    }
  });
});

// Health check
app.get('/api/health', (_req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    authMethod: 'JWT'
  });
});

// Export for Vercel serverless
module.exports = app;
