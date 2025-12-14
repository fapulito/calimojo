# Mojo Poker - Vercel Deployment

This is a Vercel-compatible version of the Mojo Poker application, adapted from the original Perl Mojolicious version to run on Node.js.

## Features

- **Facebook Authentication**: Login with Facebook credentials using Passport.js
- **Poker Game Listing**: View available poker games
- **Responsive UI**: Modern, mobile-friendly interface
- **Vercel Optimized**: Configured for easy deployment to Vercel

## Setup Instructions

### 1. Install Dependencies

```bash
cd vercel
npm install
```

### 2. Configuration

Create a `.env` file by copying `.env.example`:

```bash
cp .env.example .env
```

Edit the `.env` file with your Facebook App credentials:

```env
FACEBOOK_APP_ID=your_facebook_app_id
FACEBOOK_APP_SECRET=your_facebook_app_secret
FACEBOOK_CALLBACK_URL=https://your-vercel-app.vercel.app/auth/facebook/callback
SESSION_SECRET=your_secure_session_secret
```

### 3. Facebook App Setup

1. Go to [Facebook Developers](https://developers.facebook.com/) and create a new app
2. Set up Facebook Login product
3. Add `https://your-vercel-app.vercel.app/auth/facebook/callback` as a valid OAuth redirect URI
4. Copy the App ID and App Secret to your `.env` file

### 4. Local Development

```bash
npm run dev
```

The app will be available at `http://localhost:3000`

### 5. Deployment to Vercel

1. Push this code to your GitHub repository
2. Go to [Vercel](https://vercel.com/) and import your project
3. Add the environment variables from your `.env` file in the Vercel project settings
4. Deploy!

## Project Structure

```
vercel/
├── api/                # API routes (for future expansion)
├── lib/                # Server-side code
│   └── server.js       # Main Express server
├── public/             # Static assets
│   ├── css/            # Stylesheets
│   ├── img/            # Images
│   └── index.html      # Main HTML file
├── .env.example        # Environment variable template
├── package.json        # Node.js dependencies
├── vercel.json         # Vercel configuration
└── README.md           # This file
```

## API Endpoints

- `GET /auth/facebook` - Initiate Facebook login
- `GET /auth/facebook/callback` - Facebook callback URL
- `GET /logout` - Logout current user
- `GET /api/auth/status` - Check authentication status
- `GET /api/poker/games` - Get available poker games

## Authentication Flow

1. User clicks "Login with Facebook"
2. Redirect to Facebook for authentication
3. Facebook redirects back to `/auth/facebook/callback`
4. User is authenticated and session is created
5. User can now access protected routes and see their profile

## Notes

- This is a basic implementation that demonstrates Facebook authentication
- The original Perl poker game logic would need to be ported to Node.js for full functionality
- Session management uses express-session with cookie-based sessions
- For production, consider using a database for user storage and session persistence

## License

This project is licensed under the same terms as the original Mojo Poker project.