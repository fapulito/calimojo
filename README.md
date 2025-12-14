![Mojo Poker Logo](/mojopoker-1.1.1/public/img/logo.png)

[![Build Status](https://api.travis-ci.com/nathanielgraham/Mojo-Poker.svg?branch=master)]

# Mojopoker - Refactored and Enhanced

Mojo Poker is a web-based poker system that allows anyone to run their own private poker site. This repository has been significantly refactored and enhanced using Cline AI to improve functionality, security, and compliance.

## 🚀 Recent Refactoring & Improvements

This project has undergone major enhancements through Cline AI assistance:

### ✅ Database System Overhaul
- **Fixed database connection issues** - Resolved SQLite database path and permission problems
- **Added PostgreSQL support** - New Vercel version with full PostgreSQL integration
- **House player system** - Added test users for automated gameplay testing
- **Data migration** - Proper database initialization and schema management

### ✅ Facebook Integration & Compliance
- **Facebook Login** - Fully functional Facebook authentication system
- **Comprehensive Privacy Policy** - Facebook-compliant privacy policy for app review
- **Facebook SDK integration** - Proper OAuth flow and data handling
- **App Review Ready** - All requirements met for Facebook app approval

### ✅ Vercel/Node.js Version
- **Modern backend** - Express.js server with Passport authentication
- **JWT authentication** - Secure token-based authentication system
- **Session management** - Database-backed session storage
- **RESTful API** - Comprehensive API endpoints for game management

### ✅ Security Enhancements
- **Fixed middleware ordering** - Resolved authentication middleware issues
- **Data protection** - Proper encryption and security measures
- **User rights management** - GDPR and CCPA compliance features
- **Children's privacy** - COPPA compliance and age verification

### ✅ Gameplay Improvements
- **Virtual currency system** - Robust chip management and transactions
- **Anti-cheating measures** - Enhanced fraud detection and prevention
- **Game balance** - Improved hand evaluation and game logic
- **Multi-table support** - Better tournament and ring game management

## Features
Includes all the classics plus a large selection of offbeat games:
Hold'em, Hold'em Jokers Wild, Pineapple, Crazy Pineapple, Omaha, Omaha Hi-Lo, 5 Card Omaha, 5 Card Omaha Hi-Lo, Courcheval, Courcheval Hi-Lo, 5 Card Draw, 5 Card Draw Deuces Wild, 5 Card Draw Jokers Wild, 2-7 Single Draw, 2-7 Triple Draw, A-5 Single Draw, A-5 Triple Draw, 7 Card Stud, 7 Card Stud Jokers Wild, 7 Card Stud Hi-Lo, Razz, High Chicago, Follow the Queen, The Bitch, Badugi, Badacey, Badeucy, Dealer's Choice.

![SCREENSHOT](https://github.com/mojopoker/Mojo-Poker/blob/master/SCREENSHOT.png)

## Install
Tested on Ubuntu 16.04. Other distros might require tweaking.
Begin with a newly installed, "clean" install of Ubuntu 16.04.
Issue the following commands in your terminal session:

    cd /tmp
    git clone https://github.com/nathanielgraham/Mojo-Poker.git
    cd Mojo-Poker
    sudo ./install

## Starting the server
Issue the following command in your terminal session:

    sudo systemctl start mojopoker.service

Now point your browser at http://localhost:3000

## Creating new tables
To create a new six handed No-Limit Hold'em table for example, issue the following command:

    /opt/mojopoker/script/mpadmin.pl create_ring -game_class holdem -limit NL -chair_count 6

See mpadmin.pl --help for a complete list of options. 

## Admin tool
mpadmin.pl is a command-line ultility for creating and deleting ring games, editing player info, crediting chips, and other admin tasks.  For a complete list of options, type:

    sudo /opt/mojopoker/script/mpadmin.pl --help 

## Advanced websocket shell
wsshell.pl is a command-line utility for sending JSON encoded WebSocket messages directly to the server. Useful for automating certain tasks. To bulk load many games at once for example, issue the following command in your terminal session:

    sudo /opt/mojopoker/script/wsshell.pl < /opt/mojopoker/db/example_games

## Running in production
Additional steps to run a secure site:
- [ ] Facebook login feature won't work without a registered domain
- [ ] Setup nginx as reverse proxy to provide SSL/TLS certificate
- [ ] Change admin password
- [ ] Add firewall for DDOS protection
- [ ] Configure proper CORS settings for API access

See [Mojolicious::Guides::Cookbook](https://metacpan.org/pod/distribution/Mojolicious/lib/Mojolicious/Guides/Cookbook.pod). You can also contact me directly if you need additional support.

## 📱 Vercel/Node.js Version Setup

### Installation
```bash
cd vercel
npm install
cp .env.example .env
# Edit .env with your Facebook app credentials and database connection
```

### Running the Vercel Server
```bash
cd vercel
npm run dev  # Development mode
# or
npm start    # Production mode
```

### Environment Variables
Create a `.env` file in the `vercel` directory with the following variables:

```env
# Facebook Auth
FACEBOOK_APP_ID=your_facebook_app_id
FACEBOOK_APP_SECRET=your_facebook_app_secret

# Database
DATABASE_URL=postgresql://user:password@host:port/database

# Session
SESSION_SECRET=your_secure_secret_here

# Server
PORT=3000
NODE_ENV=development
```

## 🔒 Privacy & Compliance

### Facebook App Review
The project now includes a comprehensive privacy policy that satisfies Facebook's requirements for app review. Key compliance features:

- **Facebook Login Integration**: Proper OAuth flow with correct data usage
- **Privacy Policy**: Located at `/privacy` (Perl) and `/privacy.html` (Vercel)
- **Data Deletion**: Users can request deletion of their Facebook data
- **User Control**: Clear explanation of data usage and user rights

### Privacy Policy Access
- **Perl Version**: `http://localhost:3000/privacy`
- **Vercel Version**: `http://localhost:3000/privacy.html`

## 🎮 New Features

### Facebook Authentication
```javascript
// Login via Facebook
window.location.href = '/auth/facebook';

// Check authentication status
fetch('/api/auth/status')
  .then(response => response.json())
  .then(data => console.log(data.authenticated));
```

### JWT Authentication (Vercel)
```javascript
// Login with JWT
const response = await fetch('/api/auth/jwt/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ username, password })
});

// Use JWT token
const token = response.token;
fetch('/api/protected-route', {
  headers: { 'Authorization': `Bearer ${token}` }
});
```

### Game Management API
```javascript
// Get available games
fetch('/api/poker/games')
  .then(response => response.json())
  .then(games => console.log(games));

// Create a new game (admin only)
fetch('/api/poker/games', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${adminToken}`
  },
  body: JSON.stringify({
    name: 'Texas Holdem',
    game_type: 'holdem',
    min_players: 2,
    max_players: 10
  })
});
```

## 🛠️ Development

### Running Tests
```bash
# Perl version tests
cd mojopoker-1.1.1
prove t/

# Vercel version tests
cd vercel
npm test
```

### Database Management
```bash
# Initialize database (Vercel)
cd vercel
node lib/db.js initialize

# Run migrations
cd vercel
npx sequelize-cli db:migrate
```

## 📚 Documentation

### Privacy Policy
- Comprehensive Facebook-compliant privacy policy
- Covers GDPR, CCPA, and COPPA requirements
- Explains data collection, usage, and user rights

### API Documentation
- RESTful API endpoints for game management
- Authentication flows (Facebook + JWT)
- WebSocket integration for real-time gameplay

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes: `git commit -m 'Add some feature'`
4. Push to the branch: `git push origin feature/your-feature`
5. Open a pull request

## 📋 Changelog

### Recent Updates
- **v2.0.0** - Major refactoring with Cline AI
  - Added Vercel/Node.js version with PostgreSQL support
  - Facebook authentication integration
  - Comprehensive privacy policy
  - Middleware fixes and security enhancements
  - Virtual currency system improvements

- **v1.1.1** - Original Perl version
  - Basic poker game functionality
  - SQLite database support
  - WebSocket-based real-time gameplay

## 📞 Support

For questions and bug reports:
- **Original Author**: ngraham@cpan.org
- **Cline Refactoring**: fapulito@gmail.com
- **Issues**: https://github.com/fapulito/calimojo/issues

## 📜 License

Copyright (C) 2019-2025, Nathaniel J. Graham & Contributors

This program is free software, you can redistribute it and/or modify it under the terms of the Artistic License version 2.0.
https://dev.perl.org/licenses/artistic.html

## Contact
Questions and bug reports to fapulito@gmail.com

## TODO 
- [ ] Add support for tournaments
- [ ] Change hand evaluator to [Poker::Eval](https://metacpan.org/pod/Poker::Eval)

## COPYRIGHT AND LICENSE
Copyright (C) 2019, Nathaniel J. Graham

This program is free software, you can redistribute it and/or modify it
nder the terms of the Artistic License version 2.0.
https://dev.perl.org/licenses/artistic.html