require('dotenv').config();
const express = require('express');
const session = require('express-session');
const passport = require('passport');
const FacebookStrategy = require('passport-facebook').Strategy;
const cookieParser = require('cookie-parser');
const cors = require('cors');
const path = require('path');
const { WebSocketServer } = require('ws');

const app = express();

// WebSocket server setup
let wss;
/**
 * Initialize a WebSocketServer attached to the given HTTP server and register handlers for connections, messages, closes, and errors.
 *
 * Message handling:
 * - Expects incoming messages as JSON.
 * - If `type` is `"join_game"`, responds with a `"game_ready"` message containing `gameId` and `userId`.
 * - For other messages, responds with an `"acknowledgment"` including the original message.
 * - On parse or processing errors, responds with an `"error"` message indicating an invalid message format.
 *
 * @param {import('http').Server} server - The HTTP server to bind the WebSocketServer to.
 */
function setupWebSocketServer(server) {
  wss = new WebSocketServer({ server });

  wss.on('connection', (ws, req) => {
    console.log('New WebSocket connection established');

    ws.on('message', (message) => {
      console.log('Received WebSocket message:', message.toString());
      try {
        const data = JSON.parse(message.toString());

        // Handle different message types
        if (data.type === 'join_game') {
          console.log(`User ${data.userId} joining game ${data.gameId}`);
          ws.send(JSON.stringify({
            type: 'game_ready',
            message: 'Game 3 is ready! In a full implementation, you would now be connected to the poker table via WebSocket.',
            gameId: data.gameId,
            userId: data.userId
          }));
        } else {
          ws.send(JSON.stringify({
            type: 'acknowledgment',
            message: 'Message received',
            originalMessage: data
          }));
        }
      } catch (error) {
        console.error('Error processing WebSocket message:', error);
        ws.send(JSON.stringify({
          type: 'error',
          message: 'Invalid message format'
        }));
      }
    });

    ws.on('close', () => {
      console.log('WebSocket connection closed');
    });

    ws.on('error', (error) => {
      console.error('WebSocket error:', error);
    });
  });

  console.log('WebSocket server initialized');
}

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

passport.deserializeUser((id, done) => {
  // Here you would typically look up the user by id in your database
  const user = {
    id: id,
    displayName: 'Facebook User',
    // In a real app, you would fetch this from your database
  };
  done(null, user);
});

// Routes
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, '../../public/index.html'));
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

  // Determine WebSocket URL based on environment
  const websocketUrl = process.env.NODE_ENV === 'production'
    ? `wss://${req.headers.host}/api/websocket`
    : `ws://${req.headers.host}/api/websocket`;

  // Return success response with proper WebSocket connection info
  res.json({
    success: true,
    message: 'Game join request processed',
    gameId: gameId,
    websocketUrl: websocketUrl,
    user: {
      id: req.user.id,
      displayName: req.user.displayName
    }
  });
});

// Serve static files from public directory
app.use(express.static(path.join(__dirname, '../../public')));

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).send('Something broke!');
});

// Export the app for Vercel
module.exports = app;