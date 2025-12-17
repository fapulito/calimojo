# Fly.io Deployment Guide for Mojo Poker

## Fly.io vs Google Cloud Run: Key Differences

Both platforms run Docker containers, but they have fundamental architectural differences:

### **Fly.io** (Recommended for Poker App)
- **Architecture**: Microvm-based, runs actual VMs with your container
- **WebSockets**: ✅ **Full support** - persistent connections work perfectly
- **Scaling**: Horizontal (multiple machines) with built-in load balancing
- **State**: Can maintain in-memory state across requests
- **Networking**: Global Anycast network, machines in multiple regions
- **Pricing**: Pay for running machines (CPU + RAM), even when idle
- **Best for**: Real-time apps, WebSockets, stateful services, games

### **Google Cloud Run** (Not Ideal for Poker)
- **Architecture**: Serverless, containers scale to zero
- **WebSockets**: ⚠️ **60-minute timeout** - connections drop after 1 hour
- **Scaling**: Automatic scale-to-zero, cold starts
- **State**: Stateless by design, no persistent connections
- **Networking**: Regional, behind Google's load balancer
- **Pricing**: Pay per request + CPU time, scales to zero when idle
- **Best for**: Stateless APIs, HTTP services, batch jobs

### Why Fly.io for Poker?

Your poker app needs:
1. **Persistent WebSocket connections** - players stay connected for hours
2. **In-memory game state** - active poker hands, player positions
3. **Low latency** - real-time card dealing and betting
4. **No cold starts** - players expect instant response

**Verdict**: Fly.io is the clear winner for this use case.

---

## Prerequisites

1. **Fly.io Account**: Sign up at [fly.io](https://fly.io)
2. **flyctl CLI**: Install the Fly.io command-line tool
3. **Docker**: Installed locally (for testing)
4. **NeonDB**: PostgreSQL database (already set up)

---

## Part 1: Install Fly.io CLI

### macOS/Linux:
```bash
curl -L https://fly.io/install.sh | sh
```

### Windows (PowerShell):
```powershell
pwsh -Command "iwr https://fly.io/install.ps1 -useb | iex"
```

### Verify installation:
```bash
flyctl version
```

---

## Part 2: Authenticate with Fly.io

```bash
# Login to Fly.io
flyctl auth login

# This opens a browser for authentication
# After login, you'll see: "successfully logged in as your@email.com"
```

---

## Part 3: Prepare Your Application

### 3.1 Review Dockerfile

The `Dockerfile` is already created in `mojopoker-1.1.1/`. It:
- Uses Perl 5.38 base image
- Installs system dependencies (PostgreSQL client, SSL)
- Installs Perl modules from `cpanfile`
- Copies application code
- Exposes port 8080
- Runs the Mojolicious daemon

### 3.2 Test Docker Build Locally (Optional)

```bash
cd mojopoker-1.1.1

# Build the image
docker build -t mojopoker:test .

# Run locally
docker run -p 8080:8080 \
  -e DB_HOST=your-neon-host \
  -e DB_NAME=neondb \
  -e DB_USER=your-user \
  -e DB_PASSWORD=your-password \
  mojopoker:test

# Test in browser: http://localhost:8080
```

---

## Part 4: Deploy to Fly.io

### 4.1 Initialize Fly.io App

```bash
cd mojopoker-1.1.1

# Launch the app (interactive setup)
flyctl launch

# You'll be prompted:
# - App name: mojopoker (or your choice)
# - Region: Choose closest to your users (e.g., iad for US East)
# - PostgreSQL: No (we're using NeonDB)
# - Redis: No (not needed)
# - Deploy now: No (we need to set secrets first)
```

This creates `fly.toml` (already provided) and registers your app.

### 4.2 Set Environment Secrets

Fly.io uses secrets for sensitive data (not in `fly.toml`):

```bash
# Database credentials (from NeonDB)
flyctl secrets set \
  DB_HOST=ep-xxx-xxx-123456.us-east-2.aws.neon.tech \
  DB_PORT=5432 \
  DB_NAME=neondb \
  DB_USER=your_neon_username \
  DB_PASSWORD=your_neon_password

# Facebook OAuth (from Facebook Developer Console)
flyctl secrets set \
  FACEBOOK_APP_ID=your_facebook_app_id \
  FACEBOOK_APP_SECRET=your_facebook_app_secret

# Session secret (generate random string)
flyctl secrets set \
  SESSION_SECRET=$(openssl rand -hex 32)
```

### 4.3 Deploy the Application

```bash
# Deploy to Fly.io
flyctl deploy

# This will:
# 1. Build your Docker image
# 2. Push to Fly.io registry
# 3. Create machines in your selected region
# 4. Start the application
# 5. Assign a public URL: https://mojopoker.fly.dev
```

### 4.4 Verify Deployment

```bash
# Check app status
flyctl status

# View logs
flyctl logs

# Open in browser
flyctl open
```

---

## Part 5: Configure Custom Domain (Optional)

### 5.1 Add Your Domain

```bash
# Add domain to Fly.io
flyctl certs add poker.yourdomain.com

# Fly.io will provide DNS records to add:
# - CNAME: poker.yourdomain.com -> mojopoker.fly.dev
# - Or A/AAAA records for apex domain
```

### 5.2 Update DNS

Add the provided records to your DNS provider (Cloudflare, Namecheap, etc.):

```
Type: CNAME
Name: poker
Value: mojopoker.fly.dev
TTL: Auto
```

### 5.3 Verify SSL Certificate

```bash
# Check certificate status
flyctl certs show poker.yourdomain.com

# Wait for "The certificate has been issued"
```

---

## Part 6: Scaling & Performance

### 6.1 Scale Machines

```bash
# Scale to 2 machines for redundancy
flyctl scale count 2

# Scale to specific regions
flyctl scale count 2 --region iad,lax

# Scale VM resources (if needed)
flyctl scale vm shared-cpu-2x --memory 1024
```

### 6.2 Monitor Performance

```bash
# View metrics
flyctl dashboard

# Real-time logs
flyctl logs -f

# SSH into machine (for debugging)
flyctl ssh console
```

### 6.3 Auto-Scaling Configuration

Edit `fly.toml`:

```toml
[scaling]
  min_count = 1  # Minimum machines always running
  max_count = 5  # Maximum machines under load
```

Then redeploy:
```bash
flyctl deploy
```

---

## Part 7: Database Connection

### 7.1 Verify NeonDB Connection

Your app connects to NeonDB using environment variables:

```perl
# In lib/FB/Db.pm
my $host = $ENV{DB_HOST};  # From Fly.io secrets
my $port = $ENV{DB_PORT};
my $name = $ENV{DB_NAME};
my $user = $ENV{DB_USER};
my $pass = $ENV{DB_PASSWORD};

my $dbh = DBI->connect(
    "dbi:Pg:dbname=$name;host=$host;port=$port;sslmode=require",
    $user, $pass,
    { RaiseError => 1, AutoCommit => 1 }
);
```

### 7.2 Test Database Connection

```bash
# SSH into Fly.io machine
flyctl ssh console

# Test connection
perl -e 'use DBI; my $dbh = DBI->connect("dbi:Pg:dbname=$ENV{DB_NAME};host=$ENV{DB_HOST};sslmode=require", $ENV{DB_USER}, $ENV{DB_PASSWORD}); print "Connected!\n" if $dbh;'
```

---

## Part 8: WebSocket Configuration

### 8.1 Verify WebSocket Support

Fly.io automatically handles WebSocket upgrades. No special configuration needed!

Test WebSocket connection:

```javascript
// In browser console
const ws = new WebSocket('wss://mojopoker.fly.dev/ws');
ws.onopen = () => console.log('Connected!');
ws.onmessage = (e) => console.log('Message:', e.data);
ws.onerror = (e) => console.error('Error:', e);
```

### 8.2 Connection Limits

In `fly.toml`, we set:

```toml
[services.concurrency]
  type = "connections"
  hard_limit = 1000  # Max 1000 concurrent WebSocket connections per machine
  soft_limit = 500   # Start scaling at 500 connections
```

For 100 concurrent players, 1 machine is sufficient.
For 500+ players, Fly.io will auto-scale to 2-3 machines.

---

## Part 9: Update Vercel Frontend

Update your Vercel frontend to point to Fly.io:

### 9.1 Set Vercel Environment Variables

In Vercel Dashboard → Settings → Environment Variables:

| Variable | Value |
|----------|-------|
| `NEXT_PUBLIC_API_URL` | `https://mojopoker.fly.dev` |
| `NEXT_PUBLIC_WS_URL` | `wss://mojopoker.fly.dev` |

### 9.2 Redeploy Vercel

```bash
cd vercel
vercel --prod
```

---

## Part 10: Continuous Deployment

### 10.1 GitHub Actions (Recommended)

Create `.github/workflows/deploy-fly.yml`:

```yaml
name: Deploy to Fly.io

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: superfly/flyctl-actions/setup-flyctl@master
      
      - name: Deploy to Fly.io
        run: flyctl deploy --remote-only
        working-directory: mojopoker-1.1.1
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

### 10.2 Get Fly.io API Token

```bash
# Generate token
flyctl auth token

# Add to GitHub:
# Settings → Secrets → Actions → New repository secret
# Name: FLY_API_TOKEN
# Value: <paste token>
```

Now every push to `main` automatically deploys to Fly.io!

---

## Part 11: Troubleshooting

### App won't start

```bash
# Check logs
flyctl logs

# Common issues:
# - Missing environment variables: flyctl secrets list
# - Database connection: Check NeonDB credentials
# - Port binding: Ensure app listens on 0.0.0.0:8080
```

### WebSocket connections fail

```bash
# Verify WebSocket upgrade headers
flyctl logs | grep -i upgrade

# Check if machines are running
flyctl status

# Ensure auto_stop_machines = false in fly.toml
```

### High latency

```bash
# Check machine region
flyctl status

# Add machines in more regions
flyctl scale count 2 --region iad,lax

# Use Fly.io's global Anycast network
```

### Database connection errors

```bash
# Verify secrets are set
flyctl secrets list

# Test connection from machine
flyctl ssh console
perl -e 'use DBI; ...'

# Check NeonDB is not sleeping (free tier)
```

---

## Part 12: Cost Estimation

### Fly.io Pricing (as of 2024)

**Free Tier Includes:**
- 3 shared-cpu-1x machines (256MB RAM each)
- 160GB outbound data transfer
- Perfect for development/testing

**Production Pricing:**
- **Machines**: $0.0000008/sec (~$2/month per machine)
- **RAM**: $0.0000002/MB/sec (~$0.15/GB/month)
- **Bandwidth**: $0.02/GB after free tier

**Example Costs:**

| Setup | Machines | RAM | Monthly Cost |
|-------|----------|-----|--------------|
| **Small** (100 players) | 1x shared-cpu-1x | 512MB | ~$3-5 |
| **Medium** (500 players) | 2x shared-cpu-2x | 1GB each | ~$15-20 |
| **Large** (1000+ players) | 3x shared-cpu-4x | 2GB each | ~$40-50 |

**Total Stack Cost:**
- Fly.io: $3-50/month (depending on scale)
- NeonDB: $0 (free tier) or $19/month (pro)
- Vercel: $0 (hobby) or $20/month (pro)
- **Total**: $3-90/month

---

## Part 13: Comparison Summary

| Feature | Fly.io | Google Cloud Run | DigitalOcean VPS |
|---------|--------|------------------|------------------|
| **WebSockets** | ✅ Unlimited | ⚠️ 60min timeout | ✅ Unlimited |
| **Scaling** | Auto (1-10 machines) | Auto (0-1000 instances) | Manual |
| **Cold Starts** | None (always running) | Yes (~1-3 seconds) | None |
| **State** | In-memory OK | Stateless only | In-memory OK |
| **Regions** | Global (30+ regions) | Regional | Single location |
| **SSL** | Auto (Let's Encrypt) | Auto | Manual (certbot) |
| **Deployment** | `flyctl deploy` | `gcloud run deploy` | SSH + systemd |
| **Cost (small)** | ~$5/month | ~$5/month | $6/month |
| **Best for** | Real-time apps | Stateless APIs | Full control |

**For your poker app**: Fly.io is the best choice due to WebSocket requirements.

---

## Quick Start Commands

```bash
# 1. Install flyctl
curl -L https://fly.io/install.sh | sh

# 2. Login
flyctl auth login

# 3. Deploy
cd mojopoker-1.1.1
flyctl launch
flyctl secrets set DB_HOST=... DB_PASSWORD=... FACEBOOK_APP_ID=...
flyctl deploy

# 4. Open app
flyctl open

# 5. Monitor
flyctl logs -f
```

---

## Support & Resources

- **Fly.io Docs**: https://fly.io/docs
- **Community Forum**: https://community.fly.io
- **Status Page**: https://status.fly.io
- **Pricing**: https://fly.io/docs/about/pricing

---

## Next Steps

1. ✅ Deploy to Fly.io
2. ✅ Configure custom domain
3. ✅ Set up GitHub Actions for CI/CD
4. ✅ Update Vercel frontend to use Fly.io backend
5. ✅ Monitor performance and scale as needed

Your poker app is now running on a modern, scalable platform with full WebSocket support!
