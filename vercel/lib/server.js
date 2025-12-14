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
  origin: process.env.NODE_ENV === 'production' ? 'https://your-vercel-app.vercel.app' : 'http://localhost:3000',
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

// Facebook Strategy
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

// Serialize and deserialize user
passport.serializeUser((user, done) => {
  done(null, user.id);
});

// In-memory user store for session management
const userStore = new Map();

// Store user in memory when they authenticate
passport.serializeUser((user, done) => {
  // Store the full user object in memory for session restoration
  userStore.set(user.id, user);
  done(null, user.id);
});

passport.deserializeUser((id, done) => {
  try {
    // First try to get user from in-memory store (for session restoration)
    if (userStore.has(id)) {
      const user = userStore.get(id);
      console.log(`[AUTH] User ${id} found in session store, restoring session`);
      return done(null, user);
    }

    // If not in memory store, this might be a new session or server restart
    // In a production app, you would query your database here
    // For now, we'll return false to indicate user not found
    console.log(`[AUTH] User with id ${id} not found in session store (likely server restart or new session)`);
    return done(null, false);
  } catch (error) {
    // Handle any lookup errors
    console.error('[AUTH] Error deserializing user:', error);
    done(error);
  }
});

// Routes
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, '../public/index.html'));
});

// Facebook Auth Routes
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

// API route to join a poker game - integrates with Perl backend
app.post('/api/poker/join', (req, res) => {
  // This endpoint will proxy requests to the Perl backend
  // For now, we'll implement a basic version that simulates the Perl backend response
  // In a production environment, this would forward the request to the Perl WebSocket server

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

  // Simulate joining a game - in reality this would connect to the Perl WebSocket server
  // and send a join_ring command

  // For now, we'll return a success response and provide WebSocket connection info
  res.json({
    success: true,
    message: 'Game join request processed',
    gameId: gameId,
    websocketUrl: `ws://localhost:3000/websocket`,
    user: {
      id: req.user.id,
      displayName: req.user.displayName
    }
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