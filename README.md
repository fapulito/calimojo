# Mojo Poker

![Mojo Poker Logo](/mojopoker-1.1.1/public/img/logo.png)

[![CI Tests](https://github.com/fapulito/calimojo/actions/workflows/test.yaml/badge.svg)](https://github.com/fapulito/calimojo/actions/workflows/test.yaml)

Mojo Poker is a web-based poker system that allows anyone to run their own private poker site. This fork adds modern deployment options including Vercel frontend hosting, NeonDB PostgreSQL support, and Facebook OAuth authentication.

![SCREENSHOT](SCREENSHOT.png)

## Features

Includes all the classics plus a large selection of offbeat games:

Hold'em, Hold'em Jokers Wild, Pineapple, Crazy Pineapple, Omaha, Omaha Hi-Lo, 5 Card Omaha, 5 Card Omaha Hi-Lo, Courcheval, Courcheval Hi-Lo, 5 Card Draw, 5 Card Draw Deuces Wild, 5 Card Draw Jokers Wild, 2-7 Single Draw, 2-7 Triple Draw, A-5 Single Draw, A-5 Triple Draw, 7 Card Stud, 7 Card Stud Jokers Wild, 7 Card Stud Hi-Lo, Razz, High Chicago, Follow the Queen, The Bitch, Badugi, Badacey, Badeucy, Dealer's Choice.

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│     Vercel      │     │  DigitalOcean   │     │     NeonDB      │
│   (Frontend)    │────▶│  (Perl Server)  │────▶│  (PostgreSQL)   │
│   Node.js/JWT   │     │   WebSockets    │     │   Database      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

- **Frontend**: Vercel-hosted Node.js with JWT authentication
- **Backend**: Perl/Mojolicious WebSocket server for real-time gameplay
- **Database**: NeonDB (PostgreSQL) or SQLite for local development
- **Auth**: Facebook OAuth with stateless JWT tokens

## Quick Start

### Local Development (SQLite)

```bash
# Clone the repository
git clone https://github.com/fapulito/calimojo.git
cd calimojo

# Install Perl dependencies
cd mojopoker-1.1.1
cpanm --installdeps .

# Initialize SQLite databases
cd db
sqlite3 fb.db < fb.schema
sqlite3 poker.db < poker.schema
cd ..

# Start the Perl server (listens on port 3000 by default)
perl script/mojopoker.pl
```

> **Note:** The server is hardcoded to listen on `http://*:3000`

### Vercel Frontend (Local)

```bash
cd vercel
npm install
npm run dev
```

Visit http://localhost:3000

## Production Deployment

See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for complete instructions covering:

1. **NeonDB Setup** - PostgreSQL database in the cloud
2. **DigitalOcean VPS** - Perl backend server
3. **Vercel Deployment** - Frontend with Facebook OAuth
4. **SSL/Nginx** - Secure WebSocket connections

### Environment Variables

**Vercel Frontend:**
```
FACEBOOK_APP_ID=your_app_id
FACEBOOK_APP_SECRET=your_secret
FACEBOOK_CALLBACK_URL=https://your-app.vercel.app/auth/facebook/callback
JWT_SECRET=random_32_char_string
```

**Perl Backend:**
```
DB_HOST=your-neondb-host.neon.tech
DB_PORT=5432
DB_NAME=neondb
DB_USER=your_username
DB_PASSWORD=your_password
```


## Windows Development

```batch
cd mojopoker-1.1.1
install_win.bat
perl script/mojopoker_win.pl daemon -l http://*:8080
```

## Creating Tables

Create a new six-handed No-Limit Hold'em table:

```bash
perl script/mpadmin.pl create_ring -game_class holdem -limit NL -chair_count 6
```

See `mpadmin.pl --help` for all options.

## Admin Tools

- **mpadmin.pl** - Create/delete games, edit players, credit chips
- **wsshell.pl** - Send JSON WebSocket messages directly to server

```bash
# Bulk load games
perl script/wsshell.pl < db/example_games

# Admin help
perl script/mpadmin.pl --help
```

## Code Quality with CodeRabbit

This project uses [CodeRabbit](https://coderabbit.ai) for automated code review on pull requests.

### How It Works

1. **Open a Pull Request** - CodeRabbit automatically reviews your changes
2. **Review Comments** - AI-powered suggestions appear as PR comments
3. **Iterate** - Address feedback and push updates
4. **Merge** - Once approved, merge with confidence

### What CodeRabbit Checks

- Code style and best practices
- Security vulnerabilities
- Performance issues
- Test coverage gaps
- Documentation completeness
- Dependency updates

### Configuration

CodeRabbit is configured via `.coderabbit.yaml` (if present) or uses sensible defaults. Reviews are triggered automatically on:
- New pull requests
- Push to existing PRs
- Manual review requests

### Interacting with CodeRabbit

Comment on your PR to interact:
- `@coderabbitai review` - Request a new review
- `@coderabbitai summary` - Get a PR summary
- `@coderabbitai resolve` - Mark suggestions as resolved

## Testing

```bash
cd mojopoker-1.1.1

# Run all tests
prove -v t/

# Run specific test
prove -v t/migrate.t
```

CI runs automatically on push via GitHub Actions.

## Project Structure

```
calimojo/
├── mojopoker-1.1.1/          # Perl backend
│   ├── lib/                  # Perl modules (FB.pm, FB::Poker, etc.)
│   ├── script/               # CLI tools (mojopoker, mpadmin.pl)
│   ├── db/                   # Database schemas and migrations
│   ├── public/               # Static assets
│   ├── templates/            # HTML templates
│   └── t/                    # Perl tests
├── vercel/                   # Node.js frontend
│   ├── api/                  # Serverless API routes
│   ├── lib/                  # Express server
│   └── public/               # Static frontend files
├── DEPLOYMENT_GUIDE.md       # Production deployment instructions
├── LEGAL_DATA_REQUEST_POLICY.md  # Data request compliance policy
└── CODE_REVIEW.md            # Code review notes
```

## Recent Improvements

- **JWT Authentication** - Stateless auth for Vercel serverless (no Redis needed)
- **NeonDB Support** - PostgreSQL cloud database integration
- **Bcrypt Passwords** - Secure password hashing with cost factor 12
- **Timer Compatibility** - Fixed EV::timer semantics for recurring timers
- **Windows Support** - Improved install_win.bat with error handling
- **CI/CD** - GitHub Actions with PostgreSQL integration tests

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Open a pull request (CodeRabbit will review automatically)
5. Address feedback and merge

## License

Copyright (C) 2019, Nathaniel J. Graham  
Copyright (C) 2024, California Vision

This program is free software under the Artistic License version 2.0.  
https://dev.perl.org/licenses/artistic.html

## Contact

- Original author: ngraham@cpan.org
- This fork: legal@california.vision
