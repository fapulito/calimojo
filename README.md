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

### Authentication (canonical login)

The canonical player login is the Perl WebSocket flow served from
`mojopoker-1.1.1` (`Ships` + `FB.pm`): page load, auto `guest_login`,
Facebook `authorize`, and bookmark `login_book` over `/websocket`.
The `vercel/` Node/Express auth code is an unused prototype — it is not
wired into the game, so do not build on it.

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

# Use a different port to avoid conflict with Perl backend
PORT=3001 npm run dev
```

Visit http://localhost:3001

> **Port Conflict Note:** Both the Perl backend and Node frontend default to port 3000. For local development, run them on different ports. In production, they run on separate servers (DigitalOcean for Perl, Vercel for Node).

## Database Setup

Mojo Poker supports both SQLite (for local development) and PostgreSQL (for production). The system automatically detects which database to use based on the `DATABASE_TYPE` environment variable.

### SQLite Setup (Default)

SQLite is the default database and requires no additional configuration. It's perfect for local development and testing.

**1. Set environment variables (optional):**

```bash
# .env file
DATABASE_TYPE=sqlite          # or leave unset (defaults to sqlite)
SQLITE_PATH=./db              # Path to database files (default: ./db)
```

**2. Initialize the databases:**

```bash
cd mojopoker-1.1.1/db
sqlite3 fb.db < fb.schema
sqlite3 poker.db < poker.schema
```

**3. Verify the setup:**

```bash
# Check that databases were created
ls -lh fb.db poker.db

# Test a query
sqlite3 fb.db "SELECT COUNT(*) FROM user;"
```

**SQLite Features:**
- ✅ Zero configuration required
- ✅ File-based (no server needed)
- ✅ Perfect for development and testing
- ✅ Automatic WAL mode for better concurrency
- ✅ Foreign key constraints enabled

### PostgreSQL Setup (Production)

PostgreSQL is recommended for production deployments. It supports concurrent users, connection pooling, and scales better than SQLite.

**1. Choose a PostgreSQL provider:**

- **NeonDB** (recommended) - Serverless PostgreSQL with generous free tier
- **Heroku Postgres** - Easy setup with Heroku deployments
- **AWS RDS** - Enterprise-grade managed PostgreSQL
- **DigitalOcean Managed Database** - Simple and affordable
- **Local PostgreSQL** - For development/testing

**2. Set environment variables:**

**Option A: Using DATABASE_URL (recommended)**

```bash
# .env file
DATABASE_TYPE=postgres
DATABASE_URL=postgresql://username:password@host:port/database?sslmode=require

# Example for NeonDB:
DATABASE_URL=postgresql://user:pass@ep-example-123.us-east-2.aws.neon.tech:5432/neondb?sslmode=require
```

**Option B: Using individual variables**

```bash
# .env file
DATABASE_TYPE=postgres
DB_HOST=ep-example-123.us-east-2.aws.neon.tech
DB_USER=your_username
DB_PASSWORD=your_password
DB_PORT=5432
DB_NAME=neondb
DB_SSLMODE=require
```

**3. Initialize the database schema:**

```bash
cd mojopoker-1.1.1/db

# Using psql command-line tool
psql $DATABASE_URL -f postgres.schema

# Or using individual connection parameters
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f postgres.schema
```

**4. Verify the setup:**

```bash
# Test connection
psql $DATABASE_URL -c "SELECT version();"

# Check tables
psql $DATABASE_URL -c "\dt"
```

**PostgreSQL Features:**
- ✅ Production-ready with high concurrency
- ✅ Connection pooling support
- ✅ Advanced indexing and query optimization
- ✅ ACID compliance with transactions
- ✅ SSL/TLS encryption

### Database Migration

See [DATABASE_MIGRATION.md](DATABASE_MIGRATION.md) for detailed instructions on migrating between SQLite and PostgreSQL.

**Quick migration from SQLite to PostgreSQL:**

```bash
# Export SQLite data
cd mojopoker-1.1.1/db
sqlite3 fb.db .dump > fb_dump.sql

# Import to PostgreSQL (requires manual schema adjustments)
# See DATABASE_MIGRATION.md for complete instructions
```

### Troubleshooting

**SQLite Issues:**

```bash
# Problem: "unable to open database file"
# Solution: Check file permissions and path
ls -la db/fb.db
chmod 644 db/fb.db

# Problem: "database is locked"
# Solution: Close other connections or enable WAL mode
sqlite3 fb.db "PRAGMA journal_mode=WAL;"

# Problem: "no such table: user"
# Solution: Initialize the schema
sqlite3 fb.db < db/fb.schema
```

**PostgreSQL Issues:**

```bash
# Problem: "connection refused"
# Solution: Check host, port, and firewall settings
ping $DB_HOST
telnet $DB_HOST $DB_PORT

# Problem: "password authentication failed"
# Solution: Verify credentials in .env file
echo $DATABASE_URL

# Problem: "SSL connection required"
# Solution: Add sslmode=require to connection string
DATABASE_URL=postgresql://user:pass@host:5432/db?sslmode=require

# Problem: "relation 'users' does not exist"
# Solution: Run the PostgreSQL schema
psql $DATABASE_URL -f db/postgres.schema
```

**Environment Variable Issues:**

```bash
# Problem: "Unsupported DATABASE_TYPE"
# Solution: Use 'sqlite', 'postgres', or 'postgresql'
DATABASE_TYPE=postgres  # not 'pg' or 'psql'

# Problem: Variables not loading
# Solution: Check .env file location and syntax
cat .env | grep DATABASE_TYPE

# Problem: Missing required PostgreSQL variables
# Solution: Set either DATABASE_URL or all DB_* variables
# See .env.example for complete list
```

**Testing Database Connection:**

```bash
# Test with Perl script
cd mojopoker-1.1.1
perl -Ilib -MFB::Db -e 'my $db = FB::Db->new; print "Connected to: " . $db->db_type . "\n";'

# Run database tests
prove -v t/sqlite_connection.t
prove -v t/postgres_connection.t
```

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

## Demo Games Configuration

Demo games are pre-configured poker tables created automatically when the server starts. These provide players with immediate access to popular game variants.

### Default Demo Games

The server creates three demo tables on startup:
- **Texas Hold'em** - 6 seats, No-Limit
- **Omaha** - 6 seats, Pot-Limit
- **7-Card Stud** - 8 seats, Pot-Limit

### Modifying Demo Games

To customize which demo games are created at startup, edit the `_create_test_tables` method in `mojopoker-1.1.1/lib/FB.pm`.

**Example: Adding a Razz table**

```perl
# In _create_test_tables method, add:
$table_opts = {
    table_id => $self->table_count + 1,
    chair_count => 8,           # Stud games support up to 8 players
    game_class => 'razz',       # Razz (7-Card Stud Low)
    limit => 'FL',              # Fixed-Limit betting
    ante => 1,                  # Ante amount
    bring => 2,                 # Bring-in bet
    small_bet => 2,             # Small bet for fixed-limit
    fix_limit => 4,             # Big bet for fixed-limit
    auto_start => 1,
    db => $self->db,
    fb => $self,
};

$table = $self->table_maker->ring_table($table_opts);
if ($table) {
    $self->table_list->{ $table->table_id } = $table;
    $self->table_count($self->table_count + 1);
    $self->_add_house_players($table);
    $self->_notify_lobby(
        [ 'notify_create_ring', $self->_fetch_table_opts($table) ]
    );
}
```

### Table Configuration Options

| Option | Description | Values |
|--------|-------------|--------|
| `chair_count` | Number of seats | 2, 6, 8, or 10 |
| `game_class` | Poker variant | See game classes below |
| `limit` | Betting structure | `NL` (No-Limit), `PL` (Pot-Limit), `FL` (Fixed-Limit) |
| `small_blind` | Small blind amount | Integer (for Hold'em/Omaha) |
| `big_blind` | Big blind amount | Integer (for Hold'em/Omaha) |
| `ante` | Ante amount | Integer (for Stud games) |
| `bring` | Bring-in bet | Integer (for Stud games) |
| `small_bet` | Small bet (FL only) | Integer |
| `fix_limit` | Big bet (FL only) | Integer |
| `auto_start` | Auto-start when ready | 1 (enabled) or 0 (disabled) |
| `table_min` | Minimum buy-in | Integer |
| `turn_clock` | Seconds per turn | Integer (default: 30) |
| `time_bank` | Extra time bank | Integer (default: 60) |

### Available Game Classes

**Hold'em Variants:**
- `holdem` - Texas Hold'em
- `holdemjokers` - Hold'em Jokers Wild
- `pineapple` - Pineapple
- `crazypine` - Crazy Pineapple

**Omaha Variants:**
- `omaha` - Omaha
- `omahahilo` - Omaha Hi-Lo
- `omahafive` - 5-Card Omaha
- `omahafivehilo` - 5-Card Omaha Hi-Lo
- `courcheval` - Courcheval
- `courchevalhilo` - Courcheval Hi-Lo

**Stud Variants:**
- `sevenstud` - 7-Card Stud
- `sevenstudhilo` - 7-Card Stud Hi-Lo
- `sevenstudjokers` - 7-Card Stud Jokers Wild
- `razz` - Razz (7-Card Stud Low)
- `highchicago` - High Chicago
- `ftq` - Follow the Queen
- `bitch` - The Bitch

**Draw Variants:**
- `fivedraw` - 5-Card Draw
- `drawdeuces` - 5-Card Draw Deuces Wild
- `drawjokers` - 5-Card Draw Jokers Wild
- `singledraw27` - 2-7 Single Draw
- `tripledraw27` - 2-7 Triple Draw
- `singledrawa5` - A-5 Single Draw
- `tripledrawa5` - A-5 Triple Draw

**Other Variants:**
- `badugi` - Badugi
- `badacey` - Badacey
- `badeucy` - Badeucy
- `dealers` - Dealer's Choice

### Using mpadmin.pl

The `mpadmin.pl` script allows runtime table creation without server restart.

**Create a table:**
```bash
# 7-Card Stud Hi-Lo with 8 seats
perl script/mpadmin.pl create_ring -game_class sevenstudhilo -limit PL -chair_count 8 -ante 1

# Heads-up No-Limit Hold'em
perl script/mpadmin.pl create_ring -game_class holdem -limit NL -chair_count 2 -small_blind 1 -big_blind 2

# Fixed-Limit Razz
perl script/mpadmin.pl create_ring -game_class razz -limit FL -chair_count 8 -ante 1 -small_bet 2 -fix_limit 4
```

**Delete a table:**
```bash
perl script/mpadmin.pl destroy_ring -table_id 5
```

**Other admin commands:**
```bash
# Credit chips to a user
perl script/mpadmin.pl credit_chips -login_id 123

# Logout a specific user
perl script/mpadmin.pl logout_user -login_id 123

# Logout all users
perl script/mpadmin.pl logout_all

# View all options
perl script/mpadmin.pl --help
```

### Bulk Loading Games

Load multiple game configurations from a file:

```bash
perl script/wsshell.pl < db/example_games
```

The `example_games` file contains JSON WebSocket commands for creating tables.

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
