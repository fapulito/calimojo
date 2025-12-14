require('dotenv').config();
const express = require('express');
const session = require('express-session');
const passport = require('passport');
const FacebookStrategy = require('passport-facebook').Strategy;
const cookieParser = require('cookie-parser');
const cors = require('cors');
const path = require('path');
const { sessionStore, testDatabaseConnection, initializeDatabase } = require('./db');
const databaseRouter = require('../api/database');
const jwtRouter = require('../api/auth/jwt');
const sessionsRouter = require('../api/sessions');
const { trackSession, checkMultiDeviceSessions } = require('../lib/middleware/sessionTracker');

const app = express();

// Middleware setup
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cookieParser());
app.use(cors({
  origin: process.env.NODE_ENV === 'production' ? 'https://your-vercel-app.vercel.app' : 'http://localhost:3000',
  credentials: true
}));

// Session configuration with database store
app.use(session({
  secret: process.env.SESSION_SECRET || 'default_session_secret',
  resave: false,
  saveUninitialized: false,
  store: sessionStore,
  cookie: {
    secure: process.env.NODE_ENV === 'production',
    maxAge: parseInt(process.env.SESSION_MAX_AGE) || 86400000
  }
}));

// Passport initialization
app.use(passport.initialize());
app.use(passport.session());

// Session tracking middleware (after passport setup)
app.use(trackSession);
app.use(checkMultiDeviceSessions);

// Facebook Strategy
passport.use(new FacebookStrategy({
    clientID: process.env.FACEBOOK_APP_ID,
    clientSecret: process.env.FACEBOOK_APP_SECRET,
    callbackURL: process.env.FACEBOOK_CALLBACK_URL || '/auth/facebook/callback',
    profileFields: ['id', 'displayName', 'emails', 'photos']
  },
  async function(accessToken, refreshToken, profile, done) {
    try {
      // Find or create user in database
      const { pool } = require('./db');
      const result = await pool.query(
        'SELECT * FROM users WHERE facebook_id = $1',
        [profile.id]
      );

      let user;
      if (result.rows.length > 0) {
        // User exists, update their info
        user = result.rows[0];
        await pool.query(
          'UPDATE users SET display_name = $1, email = $2, profile_picture = $3, facebook_access_token = $4, last_login = NOW() WHERE id = $5',
          [
            profile.displayName,
            profile.emails ? profile.emails[0].value : null,
            profile.photos ? profile.photos[0].value : null,
            accessToken,
            user.id
          ]
        );
      } else {
        // Create new user
        const newUserResult = await pool.query(
          'INSERT INTO users (facebook_id, display_name, email, profile_picture, facebook_access_token, chips) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
          [
            profile.id,
            profile.displayName,
            profile.emails ? profile.emails[0].value : null,
            profile.photos ? profile.photos[0].value : null,
            accessToken,
            400 // Starting chips
          ]
        );
        user = newUserResult.rows[0];
      }

      return done(null, user);
    } catch (error) {
      console.error('Facebook auth error:', error);
      return done(error, null);
    }
  }
));

// Serialize and deserialize user
passport.serializeUser((user, done) => {
  done(null, user.id);
});

passport.deserializeUser(async (id, done) => {
  try {
    const { pool } = require('./db');
    const result = await pool.query('SELECT * FROM users WHERE id = $1', [id]);

    if (result.rows.length > 0) {
      const user = result.rows[0];
      done(null, {
        id: user.id,
        facebook_id: user.facebook_id,
        displayName: user.display_name,
        email: user.email,
        photo: user.profile_picture,
        chips: user.chips,
        isAdmin: user.is_admin
      });
    } else {
      done(null, null);
    }
  } catch (error) {
    console.error('User deserialization error:', error);
    done(error, null);
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

// Database API routes
app.use('/api/database', databaseRouter);

// JWT Auth API routes
app.use('/api/auth/jwt', jwtRouter);

// Session management API routes
app.use('/api/sessions', sessionsRouter);

// API route for poker functionality (placeholder)
app.get('/api/poker/games', (req, res) => {
  // In a real implementation, this would return available poker games
  res.json({
    games: [
      { id: 1, name: 'Texas Holdem', players: '2-10', type: 'ring' },
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
app.listen(PORT, async () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV}`);
  console.log(`Facebook Auth: ${process.env.FACEBOOK_APP_ID ? 'Configured' : 'Not configured'}`);

  // Test database connection and initialize tables
  await testDatabaseConnection();
  await initializeDatabase();
});

module.exports = app;