# Mojo Poker Ansible Deployment

Automated server setup for Mojo Poker backend on DigitalOcean.

## Prerequisites

1. **Install Ansible** (on your local machine):
   ```bash
   # Windows (via pip)
   pip install ansible
   
   # macOS
   brew install ansible
   
   # Ubuntu/Debian
   sudo apt install ansible
   ```

2. **Create a DigitalOcean droplet** with Ubuntu 22.04 LTS

3. **Add your SSH key** to the droplet

## Quick Start

1. **Configure inventory**:
   ```bash
   cd ansible
   # Edit inventory.ini - replace YOUR_DROPLET_IP with actual IP
   ```

2. **Configure variables**:
   ```bash
   # Edit group_vars/mojopoker.yml with your settings:
   # - domain_name
   # - NeonDB credentials
   # - Facebook app credentials (optional)
   ```

3. **Run the playbook**:
   ```bash
   ansible-playbook -i inventory.ini playbook.yml
   ```

## What It Does

1. Updates system packages
2. Installs Perl, cpanm, and required modules
3. Installs Nginx and Certbot
4. Clones the repository
5. Creates environment configuration
6. Sets up systemd service
7. Configures Nginx reverse proxy with WebSocket support
8. Configures UFW firewall
9. Obtains SSL certificate (if domain is configured)

## Files

```
ansible/
├── inventory.ini           # Server inventory
├── playbook.yml            # Main playbook
├── group_vars/
│   └── mojopoker.yml       # Configuration variables
├── templates/
│   ├── env.j2              # Environment file template
│   ├── mojopoker.service.j2 # Systemd service template
│   └── nginx.conf.j2       # Nginx config template
└── README.md               # This file
```

## Post-Deployment

1. **Point your domain** to the droplet IP

2. **Get SSL certificate** (if not auto-configured):
   ```bash
   ssh root@YOUR_IP
   certbot --nginx -d your-domain.com
   ```

3. **Check service status**:
   ```bash
   ssh root@YOUR_IP
   systemctl status mojopoker
   journalctl -u mojopoker -f
   ```

4. **Update Vercel environment**:
   - Set `BACKEND_WS_URL=wss://your-domain.com`

## Updating the Server

To deploy updates:
```bash
ansible-playbook -i inventory.ini playbook.yml --tags deploy
```

## Troubleshooting

**Service won't start:**
```bash
ssh root@YOUR_IP
journalctl -u mojopoker -n 50
perl -c /var/www/mojopoker/mojopoker-1.1.1/script/mojopoker.pl
```

**Nginx errors:**
```bash
nginx -t
tail -f /var/log/nginx/error.log
```

**Database connection issues:**
- Verify NeonDB credentials in `.env`
- Check NeonDB is not in sleep mode
- Ensure IP allowlist includes 0.0.0.0/0
