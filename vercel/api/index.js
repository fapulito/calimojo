require('dotenv').config();
const express = require('express');
const session = require('express-session');
const passport = require('passport');
const FacebookStrategy = require('passport-facebook').Strategy;
const cookieParser = require('cookie-parser');
const cors = require('cors');
const path = require('path');

const app = express();

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

// Session configuration
app.use(session({
  secret: process.env.SESSION_SECRET || 'default_session_secret',
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: process.env.NODE_ENV === 'production',
    maxAge: parseInt(process.env.SESSION_MAX_AGE) || 86400000
  }
}));

// Passport initialization
app.use(passport.initialize());
app.use(passport.session());

// Facebook Strategy - only configure if credentials are provided
const facebookAuthEnabled = process.env.FACEBOOK_APP_ID && process.env.FACEBOOK_APP_SECRET;

if (facebookAuthEnabled) {
  passport.use(new FacebookStrategy({
      clientID: process.env.FACEBOOK_APP_ID,
      clientSecret: process.env.FACEBOOK_APP_SECRET,
      callbackURL: process.env.FACEBOOK_CALLBACK_URL || '/auth/facebook/callback',
      profileFields: ['id', 'displayName', 'emails', 'photos']
    },
    function(accessToken, refreshToken, profile, done) {
      const user = {
        id: profile.id,
        displayName: profile.displayName,
        email: profile.emails ? profile.emails[0].value : null,
        photo: profile.photos ? profile.photos[0].value : null,
        accessToken: accessToken
      };
      return done(null, user);
    }
  ));
}


// Serialize and deserialize user
passport.serializeUser((user, done) => {
  done(null, JSON.stringify(user));
});

passport.deserializeUser((data, done) => {
  try {
    const user = JSON.parse(data);
    done(null, user);
  } catch (e) {
    done(null, { id: data, displayName: 'User' });
  }
});

// Facebook Auth Routes
if (facebookAuthEnabled) {
  app.get('/auth/facebook',
    passport.authenticate('facebook', { scope: ['email'] })
  );

  app.get('/auth/facebook/callback',
    passport.authenticate('facebook', { failureRedirect: '/?error=auth_failed' }),
    function(req, res) {
      res.redirect('/');
    }
  );
} else {
  // Dev mode: auto-login as guest
  app.get('/auth/facebook', (req, res) => {
    const guestUser = {
      id: 'dev_guest_' + Date.now(),
      displayName: 'Dev Guest',
      email: 'guest@localhost',
      photo: null,
      isGuest: true
    };
    
    req.login(guestUser, (err) => {
      if (err) {
        return res.redirect('/?error=guest_login_failed');
      }
      res.redirect('/');
    });
  });
}

// Logout route
app.get('/logout', (req, res) => {
  req.logout(() => {
    if (req.session) {
      req.session.destroy();
    }
    res.redirect('/');
  });
});

// API route to check authentication status
app.get('/api/auth/status', (req, res) => {
  if (req.isAuthenticated && req.isAuthenticated()) {
    res.json({
      authenticated: true,
      user: req.user
    });
  } else {
    res.json({
      authenticated: false
    });
  }
});

// API route for poker games
app.get('/api/poker/games', (req, res) => {
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
  if (!req.isAuthenticated || !req.isAuthenticated()) {
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
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Export for Vercel serverless
module.exports = app;
