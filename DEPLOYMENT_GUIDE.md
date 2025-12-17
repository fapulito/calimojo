# Mojo Poker Deployment Guide

This guide covers deploying Mojo Poker with:
- **Backend**: Perl server on DigitalOcean VPS
- **Frontend**: Vercel (Node.js)
- **Database**: NeonDB (PostgreSQL)

## Architecture Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│     Vercel      │     │  DigitalOcean   │     │     NeonDB      │
│   (Frontend)    │────▶│  (Perl Server)  │────▶│  (PostgreSQL)   │
│   Node.js/React │     │   WebSockets    │     │   Database      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

---

## Part 1: NeonDB Setup

### 1.1 Create NeonDB Account & Database

1. Go to [neon.tech](https://neon.tech) and sign up
2. Create a new project (e.g., "mojopoker")
3. Note your connection string - it looks like:
   ```
   postgresql://username:password@ep-xxx-xxx-123456.us-east-2.aws.neon.tech/neondb?sslmode=require
   ```

### 1.2 Initialize Database Schema

1. In NeonDB console, open the SQL Editor
2. Copy and paste the contents of `mojopoker-1.1.1/db/postgres.schema`
3. Execute the schema to create all tables

### 1.3 Connection String Components

Save these values - you'll need them for both servers:
```
DB_HOST=ep-xxx-xxx-123456.us-east-2.aws.neon.tech
DB_PORT=5432
DB_NAME=neondb
DB_USER=your_username
DB_PASSWORD=your_password
DB_SSLMODE=require
```

---

## Part 2: DigitalOcean VPS Setup (Perl Backend)

### 2.1 Create Droplet

1. Log into [DigitalOcean](https://digitalocean.com)
2. Create a new Droplet:
   - **Image**: Ubuntu 22.04 LTS
   - **Plan**: Basic, $6/month (1 vCPU, 1GB RAM) - good for ~200 concurrent players
   - **Region**: Choose closest to your users
   - **Authentication**: SSH keys (recommended) or password

### 2.2 Initial Server Setup

SSH into your droplet:
```bash
ssh root@your_droplet_ip
```

Update system and install dependencies:
```bash
# Update system
apt update && apt upgrade -y

# Install Perl and required system packages
apt install -y perl cpanminus libdbi-perl libdbd-pg-perl \
    libmojolicious-perl libio-socket-ssl-perl \
    libsql-abstract-perl libdigest-sha-perl \
    build-essential libssl-dev nginx certbot python3-certbot-nginx

# Install additional Perl modules
cpanm Moo
cpanm DBD::Pg
cpanm Mojolicious
cpanm SQL::Abstract
```

### 2.3 Deploy Application Code

```bash
# Create app directory
mkdir -p /var/www/mojopoker
cd /var/www/mojopoker

# Clone or upload your code (replace with your repo)
git clone https://github.com/yourusername/mojopoker.git .
# OR use scp to upload:
# scp -r mojopoker-1.1.1/* root@your_droplet_ip:/var/www/mojopoker/
```

### 2.4 Configure Database Connection

Create/edit the database configuration to use NeonDB. Modify `lib/FB/Db.pm`:

```perl
sub _build_dbh {
    my $host = $ENV{DB_HOST} || 'localhost';
    my $port = $ENV{DB_PORT} || 5432;
    my $name = $ENV{DB_NAME} || 'mojopoker';
    my $user = $ENV{DB_USER} || 'postgres';
    my $pass = $ENV{DB_PASSWORD} || '';
    
    return DBI->connect(
        "dbi:Pg:dbname=$name;host=$host;port=$port;sslmode=require",
        $user,
        $pass,
        { RaiseError => 1, AutoCommit => 1 }
    );
}
```

### 2.5 Create Environment File

```bash
cat > /var/www/mojopoker/.env << 'EOF'
# NeonDB Connection
DB_HOST=ep-xxx-xxx-123456.us-east-2.aws.neon.tech
DB_PORT=5432
DB_NAME=neondb
DB_USER=your_neon_username
DB_PASSWORD=your_neon_password

# Server Config
MOJO_MODE=production
MOJO_LISTEN=http://*:8080

# Facebook Auth (get from Facebook Developer Console)
FACEBOOK_APP_ID=your_facebook_app_id
FACEBOOK_APP_SECRET=your_facebook_app_secret
EOF

chmod 600 /var/www/mojopoker/.env
```

### 2.6 Create Systemd Service

```bash
cat > /etc/systemd/system/mojopoker.service << 'EOF'
[Unit]
Description=Mojo Poker Server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/mojopoker/mojopoker-1.1.1
EnvironmentFile=/var/www/mojopoker/.env
ExecStart=/usr/bin/perl script/mojopoker daemon -l http://*:8080
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
chown -R www-data:www-data /var/www/mojopoker

# Enable and start service
systemctl daemon-reload
systemctl enable mojopoker
systemctl start mojopoker
```

### 2.7 Configure Nginx Reverse Proxy

```bash
cat > /etc/nginx/sites-available/mojopoker << 'EOF'
upstream mojopoker {
    server 127.0.0.1:8080;
}

server {
    listen 80;
    server_name your-domain.com;  # Replace with your domain

    location / {
        proxy_pass http://mojopoker;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;  # WebSocket timeout
    }
}
EOF

ln -s /etc/nginx/sites-available/mojopoker /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```

### 2.8 Setup SSL with Let's Encrypt

```bash
certbot --nginx -d your-domain.com
```

### 2.9 Verify Backend is Running

```bash
# Check service status
systemctl status mojopoker

# Check logs
journalctl -u mojopoker -f

# Test endpoint
curl http://localhost:8080
```

---

## Part 3: Vercel Frontend Deployment

### 3.1 Configure Environment Variables

In your `vercel/.env.local` (for local dev) and Vercel dashboard (for production):

```bash
# Backend API URL (your DigitalOcean server)
NEXT_PUBLIC_API_URL=https://your-domain.com
NEXT_PUBLIC_WS_URL=wss://your-domain.com

# NeonDB Connection (for any server-side API routes)
DATABASE_URL=postgresql://username:password@ep-xxx.neon.tech/neondb?sslmode=require

# Facebook Auth
FACEBOOK_APP_ID=your_facebook_app_id
FACEBOOK_APP_SECRET=your_facebook_app_secret
FACEBOOK_CALLBACK_URL=https://your-vercel-app.vercel.app/auth/facebook/callback

# Session
SESSION_SECRET=generate_a_random_32_char_string
NODE_ENV=production
```

### 3.2 Update Frontend to Connect to Backend

Update `vercel/lib/server.js` to proxy WebSocket connections to the Perl backend:

```javascript
// Add WebSocket proxy for game connections
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8080';
const BACKEND_WS = process.env.BACKEND_WS || 'ws://localhost:8080';
```

### 3.3 Deploy to Vercel

```bash
cd vercel

# Install Vercel CLI if needed
npm i -g vercel

# Deploy
vercel

# For production
vercel --prod
```

### 3.4 Configure Vercel Environment Variables

In Vercel Dashboard → Your Project → Settings → Environment Variables:

| Variable | Value |
|----------|-------|
| `NEXT_PUBLIC_API_URL` | `https://your-domain.com` |
| `NEXT_PUBLIC_WS_URL` | `wss://your-domain.com` |
| `DATABASE_URL` | Your NeonDB connection string |
| `FACEBOOK_APP_ID` | Your Facebook App ID |
| `FACEBOOK_APP_SECRET` | Your Facebook App Secret |
| `JWT_SECRET` | Random 32+ character string (for stateless auth) |

> **Note**: The Vercel frontend uses JWT (JSON Web Tokens) stored in HTTP-only cookies for authentication. This is stateless and works perfectly with Vercel's serverless architecture - no Redis or session store needed.

---

## Part 4: Facebook App Configuration

### 4.1 Facebook Developer Console Setup

1. Go to [developers.facebook.com](https://developers.facebook.com)
2. Create or select your app
3. Add Facebook Login product
4. Configure OAuth settings:

**Valid OAuth Redirect URIs:**
```
https://your-vercel-app.vercel.app/auth/facebook/callback
https://your-domain.com/auth/facebook/callback
```

**App Domains:**
```
your-vercel-app.vercel.app
your-domain.com
```

### 4.2 Privacy Policy & Terms

Facebook requires these for public apps:
- Privacy Policy URL: `https://your-vercel-app.vercel.app/privacy`
- Terms of Service URL: `https://your-vercel-app.vercel.app/terms`

---

## Part 5: Testing & Verification

### 5.1 Test Database Connection

```bash
# On DigitalOcean server
cd /var/www/mojopoker
perl -e 'use DBI; my $dbh = DBI->connect("dbi:Pg:dbname=neondb;host=ep-xxx.neon.tech;sslmode=require", "user", "pass"); print "Connected!\n" if $dbh;'
```

### 5.2 Test WebSocket Connection

Open browser console on your Vercel frontend:
```javascript
const ws = new WebSocket('wss://your-domain.com/ws');
ws.onopen = () => console.log('Connected!');
ws.onmessage = (e) => console.log('Message:', e.data);
```

### 5.3 Test Full Flow

1. Visit your Vercel URL
2. Click "Login with Facebook"
3. Authorize the app
4. You should be redirected back and see the game lobby

---

## Troubleshooting

### Backend won't start
```bash
journalctl -u mojopoker -n 50  # Check logs
perl -c script/mojopoker       # Check syntax
```

### Database connection fails
- Verify NeonDB is not in sleep mode (free tier sleeps after inactivity)
- Check SSL mode is set to `require`
- Verify IP allowlist in NeonDB (should allow all: 0.0.0.0/0)

### WebSocket connection fails
- Ensure Nginx has WebSocket upgrade headers
- Check firewall allows port 443
- Verify SSL certificate is valid

### Facebook login fails
- Check redirect URIs match exactly
- Ensure app is in "Live" mode (not development)
- Verify app ID and secret are correct

---

## Scaling Notes

**When to upgrade:**
- CPU consistently >70%: Upgrade droplet
- Memory >80%: Upgrade droplet
- Database connections >80: Consider connection pooling
- >500 concurrent users: Consider PostgreSQL connection pooler (PgBouncer)

**Upgrade path:**
1. $6/mo → $12/mo: ~500 concurrent players
2. $12/mo → $24/mo: ~1000 concurrent players
3. Beyond: Consider horizontal scaling with load balancer

---

## Cost Estimate

| Service | Monthly Cost |
|---------|-------------|
| DigitalOcean (Basic) | $6-12 |
| NeonDB (Free tier) | $0 |
| Vercel (Hobby) | $0 |
| Domain (optional) | ~$1 |
| **Total** | **$6-13/month** |
