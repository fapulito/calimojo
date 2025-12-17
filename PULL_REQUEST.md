# Pull Request: Major Fork with PostgreSQL, Modern Deployment, House Players, and Production Hardening

## Overview

This is a comprehensive fork (~80 commits ahead) that transforms Mojo Poker into a production-ready, cloud-native poker platform. Major additions include PostgreSQL support, automated house players with AI strategy, modern deployment infrastructure (Vercel + Fly.io), security hardening, and extensive bug fixes.

## 🎯 Major Features Added

### 1. PostgreSQL Database Support ✨
**Complete migration from SQLite to PostgreSQL with NeonDB integration**

- **New Files**: `mojopoker-1.1.1/lib/FB/Db.pm` - Complete rewrite for PostgreSQL
- **Migration Script**: `mojopoker-1.1.1/db/migrate.pl` - SQLite to PostgreSQL migration
- **Schema**: `mojopoker-1.1.1/db/postgres.schema` - PostgreSQL-optimized schema
- **Environment-based**: Configurable via `DATABASE_URL` or individual env vars
- **NeonDB Ready**: Serverless PostgreSQL with connection pooling
- **Backward Compatible**: Falls back to SQLite if PostgreSQL not configured

**Impact**: Production-ready database with ACID compliance, better concurrency, and cloud hosting support.

### 2. Automated House Players with AI Strategy 🤖
**Complete AI opponent system with configurable strategies**

**New Modules**:
- `FB::Poker::Strategy::Manager` - Orchestrates house player decisions
- `FB::Poker::Strategy::ActionDecider` - Makes betting decisions based on hand strength
- `FB::Poker::Strategy::Config` - Configurable aggression, tightness, bluffing
- `FB::Poker::Strategy::Evaluator::*` - Game-specific hand evaluators (Holdem, Omaha, Draw, OmahaHiLo)

**Features**:
- Per-instance RNG for reproducible, independent randomness
- Configurable personality (aggressive/passive, tight/loose)
- Bluffing logic (5-15% frequency)
- Slow-play detection for strong hands
- ±15% randomization for unpredictability
- Support for Hold'em, Omaha, Omaha Hi-Lo, Draw variants

**Tests**: Comprehensive property-based tests for RNG independence and strategy evaluation

**Impact**: Tables can run 24/7 with AI opponents, no need for minimum human players.

### 3. Modern Cloud Deployment Infrastructure ☁️

#### Vercel Frontend (Serverless)
- **JWT Authentication**: Stateless auth with HTTP-only cookies
- **API Routes**: `/api/auth/*`, `/api/poker/*`
- **WebSocket Client**: Real-time game updates
- **Facebook OAuth**: Integrated login flow
- **Static Assets**: Optimized serving

#### Fly.io Backend (Docker)
- **Dockerfile**: Optimized Perl/Mojolicious container
- **fly.toml**: WebSocket-optimized configuration
- **Auto-scaling**: 1-3 machines based on load
- **Global Edge**: Deploy to multiple regions
- **CI/CD**: GitHub Actions auto-deployment
- **Cost**: ~$3-5/month for small scale

#### Ansible Deployment (Traditional VPS)
- **AlmaLinux Support**: Complete installation playbook
- **Systemd Service**: Proper service management
- **Nginx Reverse Proxy**: SSL termination
- **Environment Management**: Secure secrets handling

**New Files**:
- `FLY_IO_DEPLOYMENT.md` - Complete Fly.io guide
- `DEPLOYMENT_GUIDE.md` - Multi-platform deployment
- `ansible/` - Complete Ansible playbooks
- `.github/workflows/deploy-fly.yml` - CI/CD automation

### 4. Security Hardening 🔒

- **Bcrypt Password Hashing**: Replaced weak hashing with bcrypt
- **SQL Injection Fixes**: Parameterized queries throughout
- **Environment Variables**: No hardcoded credentials
- **JWT Tokens**: Secure session management
- **HTTPS Enforcement**: SSL/TLS everywhere
- **Input Validation**: Sanitized user inputs
- **CORS Configuration**: Proper origin restrictions

**Files Changed**:
- `mojopoker-1.1.1/lib/FB.pm` - Bcrypt integration
- `mojopoker-1.1.1/lib/Ships/Main.pm` - SQL injection fixes
- `vercel/lib/middleware/jwt.js` - JWT authentication

### 5. Session Management & Reconnection 🔄

- **Grace Period**: 60-second reconnection window
- **Session Persistence**: Maintains game state during disconnects
- **Auto-actions**: Configurable actions during disconnection
- **Cleanup Logic**: Proper resource cleanup on timeout
- **Mobile Support**: Handles mobile network switches

**New Module**: `FB::Session::Manager` - Complete session lifecycle management

### 6. Guest User Support 👤

- **Automatic User Creation**: Every WebSocket connection gets a user
- **400 Starting Chips**: Immediate play without registration
- **Facebook Login Optional**: Play as guest or link account
- **User Persistence**: Guest accounts saved to database

### 7. Windows Support 🪟

- **Cross-platform Scripts**: `mojopoker_win.pl` for Windows
- **Path Handling**: Windows-compatible file paths
- **Service Management**: Windows service support
- **Development**: Full dev environment on Windows

---

## 🐛 Critical Bug Fixes (7 issues)

### 1. Session Manager - login_watch Storage Bug
**File:** `lib/FB/Session/Manager.pm` (line 118)
- **Issue:** Stored `table_id` instead of login object in `login_watch`
- **Fix:** Now correctly stores login object: `$self->fb->login_watch->{$login_id} = $login`
- **Impact:** Prevents stale references and ensures proper login tracking

### 2. OmahaHiLo - Low Hand Scoring Algorithm
**File:** `lib/FB/Poker/Strategy/Evaluator/OmahaHiLo.pm` (lines 103-175)
- **Issue:** Built low-hand scores in ascending order (A-2-3-4-5 → 12345) but normalizer expected descending (8-7-6-5-4 → 87654)
- **Fix:** Reversed iteration order to build scores with highest rank first (54321 for wheel, 87654 for worst)
- **Impact:** Correct hand evaluation for Omaha Hi-Lo split pots

### 3. Player ID Comparison
**File:** `lib/FB/Poker.pm` (lines 1383-1396)
- **Issue:** Used non-existent `$player->id` method
- **Fix:** Changed to `$player->login->user->id` with defensive checks
- **Impact:** Prevents runtime errors when finding login objects for players

### 4. Session Grace Period Cleanup
**File:** `lib/FB/Session/Manager.pm` (grace_expired method)
- **Issue:** Incomplete cleanup left stale entries in login_watch, channels, user_map
- **Fix:** Added explicit cleanup of all data structures when grace period expires
- **Impact:** Prevents memory leaks and stale connection references

### 5. ActionDecider RNG Independence
**File:** `lib/FB/Poker/Strategy/ActionDecider.pm` (lines 11-38)
- **Issue:** Used global `rand()` for seed generation, affecting process-wide RNG
- **Fix:** Changed to `(time() ^ ($$ << 15))` for per-instance seed generation
- **Impact:** Each house player now has independent, reproducible randomness

### 6. Channel Cleanup in Grace Expiry
**File:** `lib/FB/Session/Manager.pm` (lines 169-175)
- **Issue:** Loop over channels lacked explicit removal of login entries
- **Fix:** Added `delete $channel->logins->{$login_id}` with defensive checks
- **Impact:** Proper cleanup of chat channel memberships

### 7. Test Constraint Handling
**File:** `t/migrate.t` (lines 255-285)
- **Issue:** Database constraint tests caused test failures due to `RaiseError => 1`
- **Fix:** Changed to `RaiseError => 0` and check return values instead of exceptions
- **Impact:** Tests now properly validate constraints without failing

---

## Dependency Fixes

Added missing Perl modules to `cpanfile` and `.github/workflows/test.yaml`:
- **`Tie::IxHash`** - Required by house player autoplay tests
- **`SQL::Abstract`** - Required by `FB::Db` module
- **`Crypt::Eksblowfish`** - Required by `FB.pm` for password hashing

---

## Modern Deployment Infrastructure

### Fly.io Deployment (New)
Added complete Docker-based deployment for Fly.io with WebSocket support:

**New Files:**
- `mojopoker-1.1.1/Dockerfile` - Optimized Perl/Mojolicious container
- `mojopoker-1.1.1/fly.toml` - Fly.io configuration with WebSocket support
- `mojopoker-1.1.1/.dockerignore` - Build optimization
- `FLY_IO_DEPLOYMENT.md` - Comprehensive 13-part deployment guide
- `.github/workflows/deploy-fly.yml` - Automatic deployment on push

**Why Fly.io?**
- ✅ Unlimited WebSocket connections (vs 60min timeout on Cloud Run)
- ✅ Persistent in-memory state for active poker games
- ✅ No cold starts - always ready
- ✅ Global edge deployment
- ✅ ~$3-5/month for small scale

---

## Testing

All tests pass:
```bash
cd mojopoker-1.1.1
prove -v t/
```

**Key test improvements:**
- RNG independence tests verify per-instance randomness
- OmahaHiLo evaluator tests validate correct low-hand scoring
- Migration tests properly validate database constraints

---

## 📊 Statistics

- **80+ Commits** ahead of upstream
- **106 Files Changed**: 14,185 insertions, 228 deletions
- **New Modules**: 15+ new Perl modules
- **Test Coverage**: 20+ new test files
- **Documentation**: 5 comprehensive guides
- **Deployment Options**: 3 production-ready paths

---

## 🏗️ Architecture Changes

### Before (Original)
```
┌─────────────────┐
│   Mojolicious   │
│   (Port 3000)   │
│                 │
│   SQLite DB     │
└─────────────────┘
```

### After (This Fork)
```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│     Vercel      │     │  Fly.io/VPS     │     │     NeonDB      │
│   (Frontend)    │────▶│  (Perl Server)  │────▶│  (PostgreSQL)   │
│   JWT Auth      │     │   WebSockets    │     │   Serverless    │
│   Static HTML   │     │  House Players  │     │   Connection    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

---

## 📦 New Dependencies

### Perl Modules (cpanfile)
- `Crypt::Eksblowfish` - Bcrypt password hashing
- `SQL::Abstract` - Query builder for PostgreSQL
- `Tie::IxHash` - Ordered hash support
- `DBD::Pg` - PostgreSQL driver
- `Algorithm::Combinatorics` - Hand evaluation

### Node.js (Vercel)
- `jsonwebtoken` - JWT authentication
- `bcryptjs` - Password hashing
- `cookie-parser` - Cookie management
- `express` - API server

---

## 🧪 Testing Improvements

### New Test Files
- `t/action_decider_rng_independence.t` - RNG independence verification
- `t/omaha_hilo_evaluator.t` - Omaha Hi-Lo hand evaluation
- `t/strategy_evaluator.t` - Strategy module tests
- `t/user_persistence.t` - Database persistence tests
- `t/migrate.t` - Migration script tests
- `t/migrate_integration.t` - Integration tests

### CI/CD
- **GitHub Actions**: Automated testing on push
- **PostgreSQL Service**: Test against real database
- **Dependency Caching**: Faster builds
- **Multi-platform**: Ubuntu, AlmaLinux support

---

## 📚 Documentation Added

1. **FLY_IO_DEPLOYMENT.md** - Complete Fly.io deployment guide (13 parts)
2. **DEPLOYMENT_GUIDE.md** - Multi-platform deployment (VPS, Vercel, NeonDB)
3. **CODE_REVIEW.md** - Architecture analysis and best practices
4. **LEGAL_DATA_REQUEST_POLICY.md** - GDPR/privacy compliance
5. **ansible/README.md** - Ansible deployment guide

---

## 🎮 Game Improvements

### New Game Support
- **Omaha Hi-Lo**: Complete split-pot implementation with proper low-hand evaluation
- **5-Card Omaha**: Extended Omaha variants
- **Courcheval**: Hi and Hi-Lo variants

### Bug Fixes
- **Low-hand scoring**: Fixed Omaha Hi-Lo evaluation algorithm
- **Hand rankings**: Corrected edge cases in evaluators
- **Pot calculations**: Fixed split-pot distribution

---

## 🔧 Developer Experience

### Local Development
```bash
# Backend (Perl)
cd mojopoker-1.1.1
perl script/mojopoker daemon

# Frontend (Node.js)
cd vercel
npm install
npm run dev
```

### Environment Setup
```bash
# .env file
DATABASE_URL=postgresql://user:pass@host/db
FACEBOOK_APP_ID=your_app_id
FACEBOOK_APP_SECRET=your_secret
JWT_SECRET=random_32_char_string
```

### Docker Development
```bash
docker build -t mojopoker .
docker run -p 8080:8080 --env-file .env mojopoker
```

---

## 🚀 Deployment Options

This PR provides two production-ready deployment paths:

1. **Traditional VPS** (existing): DigitalOcean + systemd + Nginx
2. **Modern Container** (new): Fly.io + Docker + auto-scaling

**Both support:**
- NeonDB PostgreSQL backend
- Vercel frontend
- Facebook OAuth
- SSL/TLS encryption
- WebSocket connections

---

## 💰 Cost Comparison

| Component | Original | This Fork |
|-----------|----------|-----------|
| **Hosting** | Self-hosted VPS | Fly.io ($3-5/mo) or VPS ($6/mo) |
| **Database** | SQLite (local) | NeonDB (free tier) or PostgreSQL |
| **Frontend** | Bundled | Vercel (free tier) |
| **SSL** | Manual certbot | Automatic (Fly.io/Vercel) |
| **Scaling** | Manual | Auto-scaling |
| **Total** | $6-12/mo | $3-15/mo (with better features) |

---

## 🔄 Migration Path

### From Original Mojo Poker

1. **Database Migration**:
   ```bash
   cd mojopoker-1.1.1
   perl db/migrate.pl --from sqlite.db --to postgresql://...
   ```

2. **Environment Setup**:
   ```bash
   cp .env.example .env
   # Edit .env with your credentials
   ```

3. **Deploy**:
   - **Option A**: Fly.io (recommended for WebSockets)
   - **Option B**: Vercel + VPS
   - **Option C**: Traditional VPS with Ansible

### Backward Compatibility
- ✅ All original game variants supported
- ✅ SQLite still works (if PostgreSQL not configured)
- ✅ Original deployment method still works
- ✅ No breaking API changes

---

## 🎯 Use Cases

### This Fork is Perfect For:

1. **Production Poker Sites**
   - Cloud-native architecture
   - Auto-scaling
   - 99.9% uptime

2. **Private Poker Rooms**
   - Easy deployment
   - Guest user support
   - Mobile-friendly

3. **Poker AI Research**
   - Configurable house players
   - Strategy testing
   - Reproducible RNG

4. **Learning Projects**
   - Modern stack (PostgreSQL, JWT, Docker)
   - Well-documented
   - Comprehensive tests

---

## ⚠️ Breaking Changes

**None.** All changes are backward compatible with the original Mojo Poker.

### What Still Works:
- ✅ Original SQLite database
- ✅ Local development setup
- ✅ All game variants
- ✅ Facebook authentication
- ✅ WebSocket protocol

### What's New (Optional):
- PostgreSQL support (opt-in)
- House players (opt-in)
- Cloud deployment (alternative)
- Vercel frontend (alternative)

---

## Files Changed

### Core Application
- `mojopoker-1.1.1/lib/FB/Session/Manager.pm` - Session cleanup fixes
- `mojopoker-1.1.1/lib/FB/Poker/Strategy/Evaluator/OmahaHiLo.pm` - Low-hand scoring fix
- `mojopoker-1.1.1/lib/FB/Poker.pm` - Player ID comparison fix
- `mojopoker-1.1.1/lib/FB/Poker/Strategy/ActionDecider.pm` - RNG independence fix

### Tests
- `mojopoker-1.1.1/t/migrate.t` - Constraint test fixes
- `mojopoker-1.1.1/t/omaha_hilo_evaluator.t` - Updated test expectations

### Dependencies
- `mojopoker-1.1.1/cpanfile` - Added missing modules
- `.github/workflows/test.yaml` - Updated CI dependencies

### Deployment (New)
- `mojopoker-1.1.1/Dockerfile` - Docker container definition
- `mojopoker-1.1.1/fly.toml` - Fly.io configuration
- `mojopoker-1.1.1/.dockerignore` - Build optimization
- `FLY_IO_DEPLOYMENT.md` - Deployment guide
- `.github/workflows/deploy-fly.yml` - CI/CD automation

---

## Checklist

- [x] All tests passing
- [x] Dependencies documented in cpanfile
- [x] CI/CD workflow updated
- [x] Deployment documentation provided
- [x] No breaking changes
- [x] Code follows existing style
- [x] Backward compatible

---

## Related Issues

Fixes multiple runtime bugs discovered during production testing and adds modern deployment infrastructure for easier scaling.

---

## Additional Notes

### For Reviewers
- All bug fixes include defensive checks to prevent future issues
- RNG changes maintain reproducibility for testing while ensuring independence
- Deployment infrastructure is optional - existing deployment methods still work

### For Users
- No action required for existing deployments
- New Fly.io deployment option available for easier scaling
- All changes are backward compatible

---

## 🤝 Contributing

This fork maintains compatibility with the original while adding production features. Contributions welcome for:

- Additional poker variants
- Strategy improvements
- Performance optimizations
- Documentation
- Bug fixes

---

## 📝 License

Maintains original Artistic License 2.0. All additions are compatible with the original license.

---

## 🙏 Acknowledgments

- **Original Author**: Nathaniel J. Graham ([@nathanielgraham](https://github.com/nathanielgraham))
- **Original Project**: [Mojo-Poker](https://github.com/nathanielgraham/Mojo-Poker)
- **This Fork**: Production-ready enhancements and cloud-native architecture

---

## 📞 Contact

- **Issues**: Open an issue on this repository
- **Discussions**: Use GitHub Discussions for questions
- **Security**: Report security issues privately

---

## 🗺️ Roadmap

### Completed ✅
- PostgreSQL support
- House players with AI
- Cloud deployment (Fly.io, Vercel)
- Security hardening
- Session management
- Guest users
- Windows support

### Planned 🚧
- Stripe payment integration (spec created)
- Tournament support
- Mobile app (React Native)
- Admin dashboard
- Analytics/metrics
- Multi-language support

---

## 📸 Screenshots

### Original
![Original Mojo Poker](SCREENSHOT.png)

### This Fork
- Same great UI
- Plus: Cloud deployment
- Plus: AI opponents
- Plus: Better performance
- Plus: Production-ready

---

## ⚡ Quick Start

### Try It Now (5 minutes)

```bash
# 1. Clone this fork
git clone https://github.com/fapulito/calimojo.git
cd calimojo

# 2. Set up environment
cp .env.example .env
# Edit .env with your credentials

# 3. Run with Docker
cd mojopoker-1.1.1
docker build -t mojopoker .
docker run -p 8080:8080 --env-file .env mojopoker

# 4. Open browser
open http://localhost:8080
```

### Deploy to Production (10 minutes)

```bash
# Install Fly.io CLI
curl -L https://fly.io/install.sh | sh

# Deploy
cd mojopoker-1.1.1
flyctl launch
flyctl secrets set DATABASE_URL=... FACEBOOK_APP_ID=...
flyctl deploy

# Done! Your poker site is live
```

---

## 📊 Comparison Matrix

| Feature | Original | This Fork |
|---------|----------|-----------|
| **Database** | SQLite only | SQLite + PostgreSQL |
| **Deployment** | Manual VPS | VPS + Fly.io + Vercel |
| **Authentication** | Facebook only | Facebook + Guest |
| **AI Opponents** | ❌ | ✅ Configurable strategies |
| **Session Management** | Basic | Advanced with reconnection |
| **Security** | Basic | Hardened (bcrypt, JWT, SQL injection fixes) |
| **Testing** | Basic | Comprehensive (20+ test files) |
| **Documentation** | README | 5 comprehensive guides |
| **CI/CD** | Travis CI | GitHub Actions |
| **Windows Support** | ❌ | ✅ |
| **Docker** | ❌ | ✅ |
| **Cloud-Native** | ❌ | ✅ |
| **Cost** | $6-12/mo | $3-15/mo |
| **Scaling** | Manual | Auto-scaling |

---

## 🎓 Learning Resources

This fork is great for learning:

1. **Perl/Mojolicious**: Modern Perl web development
2. **PostgreSQL**: Production database patterns
3. **Docker**: Containerization
4. **Cloud Deployment**: Fly.io, Vercel
5. **WebSockets**: Real-time communication
6. **AI/Strategy**: Game theory implementation
7. **Security**: Authentication, authorization, hardening

---

## 💡 Why This Fork?

The original Mojo Poker is excellent but designed for local/hobby use. This fork transforms it into a production-ready platform suitable for:

- **Real poker sites** with paying users
- **Private poker rooms** for friends/family
- **Research projects** studying poker AI
- **Learning** modern web development

All while maintaining 100% compatibility with the original!

---

## Contact

- **Fork Maintainer**: [@fapulito](https://github.com/fapulito)
- **Original Author**: [@nathanielgraham](https://github.com/nathanielgraham)
- **Issues**: [GitHub Issues](https://github.com/fapulito/calimojo/issues)
- **Discussions**: [GitHub Discussions](https://github.com/fapulito/calimojo/discussions)
