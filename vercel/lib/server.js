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
      // Here you would typically find or create a user in your database
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
} else {
  console.log('Facebook Auth: Disabled (FACEBOOK_APP_ID or FACEBOOK_APP_SECRET not set)');
}

// Serialize and deserialize user
passport.serializeUser((user, done) => {
  done(null, user.id);
});

passport.deserializeUser((id, done) => {
  // Here you would typically look up the user by id in your database
  const isGuest = id.toString().startsWith('dev_guest_');
  const user = {
    id: id,
    displayName: isGuest ? 'Dev Guest' : 'Facebook User',
    isGuest: isGuest
    // In a real app, you would fetch this from your database
  };
  done(null, user);
});

// Routes
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, '../public/index.html'));
});

// Facebook Auth Routes - only register if Facebook auth is enabled
if (facebookAuthEnabled) {
  app.get('/auth/facebook',
    passport.authenticate('facebook', { scope: ['email'] })
  );

  app.get('/auth/facebook/callback',
    passport.authenticate('facebook', { failureRedirect: '/login' }),
    function(req, res) {
      // Successful authentication, redirect home.
      res.redirect('/');
    }
  );
} else if (process.env.NODE_ENV === 'development') {
  // Dev mode ONLY: auto-login as guest when Facebook auth is not configured
  console.log('Dev mode: Guest login enabled (NODE_ENV=development)');
  app.get('/auth/facebook', (req, res) => {
    // Create a mock guest user for development
    const guestUser = {
      id: 'dev_guest_' + Date.now(),
      displayName: 'Dev Guest',
      email: 'guest@localhost',
      photo: null,
      isGuest: true
    };
    
    req.login(guestUser, (err) => {
      if (err) {
        return res.status(500).json({ error: 'Failed to create guest session' });
      }
      console.log('Dev mode: Guest user logged in');
      res.redirect('/');
    });
  });
} else {
  // Production without Facebook auth configured - reject with 403
  console.warn('WARNING: Facebook auth not configured in production. /auth/facebook will return 403.');
  app.get('/auth/facebook', (req, res) => {
    console.warn('Blocked guest login attempt in non-development environment');
    res.status(403).json({
      error: 'Authentication not available',
      message: 'Facebook authentication is not configured and guest login is disabled in production.'
    });
  });
}

// Logout route
app.get('/logout', (req, res) => {
  req.logout(() => {
    req.session.destroy();
    res.redirect('/');
  });
});

// API route to check authentication status
app.get('/api/auth/status', (req, res) => {
  if (req.isAuthenticated()) {
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

// API route for poker functionality (placeholder)
app.get('/api/poker/games', (req, res) => {
  // In a real implementation, this would return available poker games
  res.json({
    games: [
      { id: 1, name: "Texas Hold'em", players: '2-10', type: 'ring' },
      { id: 2, name: 'Omaha Hi-Lo', players: '2-9', type: 'ring' },
      { id: 3, name: '7 Card Stud', players: '2-8', type: 'ring' }
    ]
  });
});

// Serve static files from public directory
app.use(express.static(path.join(__dirname, '../public')));

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).send('Something broke!');
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV}`);
  console.log(`Facebook Auth: ${process.env.FACEBOOK_APP_ID ? 'Configured' : 'Not configured'}`);
});

module.exports = app;