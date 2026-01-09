# Production Deployment Guide

Complete guide for deploying and managing a personal Any-Sync server with Wasabi S3 storage on AWS EC2.

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Initial Setup](#3-initial-setup)
4. [Configuration Reference](#4-configuration-reference)
5. [Service Management](#5-service-management)
6. [Client Setup](#6-client-setup)
7. [Backup and Restore](#7-backup-and-restore)
8. [Updates and Maintenance](#8-updates-and-maintenance)
9. [Troubleshooting](#9-troubleshooting)
10. [Security Hardening](#10-security-hardening)

---

## 1. Overview

### What This Deploys

| Service | Purpose | Port |
|---------|---------|------|
| Traefik | Reverse proxy, SSL termination | 80, 443 |
| Any-Sync-Bundle | Core sync services | 33010 (TCP), 33020 (UDP) |
| MongoDB | Metadata storage | 27017 (internal) |
| Redis | Cache layer | 6379 (internal) |

### Architecture

```
Internet → Traefik → Any-Sync-Bundle → MongoDB/Redis
                           ↓
                      Wasabi S3 (file storage)
```

### Data Flow

1. Anytype clients connect to `your-domain:33010` (TCP) or `:33020` (UDP/QUIC)
2. Traefik routes traffic to any-sync-bundle
3. Metadata stored in MongoDB, cached in Redis
4. Files stored in Wasabi S3

---

## 2. Prerequisites

### Server Requirements

- **EC2 Instance**: t3.small minimum (2 vCPU, 2GB RAM recommended)
- **OS**: Ubuntu 22.04 or 24.04 LTS
- **Storage**: 20GB EBS minimum
- **Network**: Public IP with open ports

### Required Ports (Security Group)

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 22 | TCP | Your IP | SSH |
| 80 | TCP | 0.0.0.0/0 | Let's Encrypt |
| 443 | TCP | 0.0.0.0/0 | HTTPS |
| 33010 | TCP | 0.0.0.0/0 | Any-Sync DRPC |
| 33020 | UDP | 0.0.0.0/0 | Any-Sync QUIC |

### External Services

1. **Domain**: A record pointing to EC2 public IP
2. **Wasabi**: Account + bucket + access keys

---

## 3. Initial Setup

### Step 1: Prepare Server

```bash
# SSH to server
ssh ubuntu@your-server-ip

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Reconnect for group changes
exit && ssh ubuntu@your-server-ip

# Create deployment directory
sudo mkdir -p /opt/anysync
sudo chown $USER:$USER /opt/anysync
```

### Step 2: Deploy Files

Copy the `deploy/` directory contents to `/opt/anysync/`:

```bash
cd /opt/anysync
# Copy: docker-compose.yml, .env.example, traefik/, scripts/
```

Structure should be:
```
/opt/anysync/
├── docker-compose.yml
├── .env.example
├── traefik/
│   └── traefik.yml
└── scripts/
    ├── setup.sh
    ├── health-check.sh
    ├── backup.sh
    └── update.sh
```

### Step 3: Configure Environment

```bash
cp .env.example .env
chmod 600 .env
nano .env
```

Fill in your values:
```bash
DOMAIN=sync.yourdomain.com
ACME_EMAIL=you@example.com
S3_BUCKET=your-bucket-name
S3_ENDPOINT=https://s3.us-east-1.wasabisys.com
S3_REGION=us-east-1
S3_ACCESS_KEY=your-access-key
S3_SECRET_KEY=your-secret-key
```

### Step 4: Configure DNS

Add A record: `sync.yourdomain.com → EC2-PUBLIC-IP`

Verify propagation:
```bash
dig sync.yourdomain.com +short
```

### Step 5: Run Setup

```bash
chmod +x scripts/*.sh
./scripts/setup.sh
```

### Step 6: Verify

```bash
# All containers should be "Up" and healthy
docker compose ps

# Test connectivity
nc -zv sync.yourdomain.com 33010

# Get client config
cat data/bundle/client-config.yml
```

---

## 4. Configuration Reference

### Environment Variables (.env)

| Variable | Description | Example |
|----------|-------------|---------|
| `DOMAIN` | Your server's domain | `sync.example.com` |
| `ACME_EMAIL` | Email for Let's Encrypt | `admin@example.com` |
| `S3_BUCKET` | Wasabi bucket name | `my-anysync-bucket` |
| `S3_ENDPOINT` | Wasabi region endpoint | `https://s3.us-east-1.wasabisys.com` |
| `S3_REGION` | Wasabi region | `us-east-1` |
| `S3_ACCESS_KEY` | Wasabi access key | (from Wasabi console) |
| `S3_SECRET_KEY` | Wasabi secret key | (from Wasabi console) |

### Wasabi Region Endpoints

| Region | Endpoint |
|--------|----------|
| US East 1 | `https://s3.us-east-1.wasabisys.com` |
| US East 2 | `https://s3.us-east-2.wasabisys.com` |
| US West 1 | `https://s3.us-west-1.wasabisys.com` |
| EU Central 1 | `https://s3.eu-central-1.wasabisys.com` |
| EU Central 2 | `https://s3.eu-central-2.wasabisys.com` |
| AP Northeast 1 | `https://s3.ap-northeast-1.wasabisys.com` |

### File Locations

| File | Purpose |
|------|---------|
| `.env` | Secrets and configuration |
| `traefik/acme.json` | SSL certificates |
| `data/bundle/bundle-config.yml` | Server identity |
| `data/bundle/client-config.yml` | Share with Anytype clients |
| `data/mongodb/` | MongoDB data |
| `data/redis/` | Redis persistence |

---

## 5. Service Management

### View Status

```bash
# Container status
docker compose ps

# Resource usage
docker stats --no-stream

# Disk usage
du -sh data/*
```

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f any-sync-bundle
docker compose logs -f mongo
docker compose logs -f redis
docker compose logs -f traefik

# Last 100 lines
docker compose logs --tail=100

# Since specific time
docker compose logs --since 1h
```

### Start/Stop/Restart

```bash
# Stop all
docker compose down

# Start all
docker compose up -d

# Restart all
docker compose restart

# Restart specific service
docker compose restart any-sync-bundle
```

### Health Check

```bash
./scripts/health-check.sh
```

Or manually:
```bash
# MongoDB
docker exec mongo mongosh --eval "rs.status().ok"

# Redis
docker exec redis redis-cli ping

# Ports
nc -zv localhost 33010
```

---

## 6. Client Setup

### Desktop

1. Open Anytype
2. Settings → Network → Self-hosted
3. Upload `client-config.yml`
4. Create **NEW identity** (cannot migrate existing accounts)

### Mobile

Transfer `client-config.yml` to device:

```bash
# Option 1: Local HTTP server
cd /opt/anysync/data/bundle
python3 -m http.server 8080
# Access: http://YOUR-SERVER-IP:8080/client-config.yml
```

Other transfer options: email, ADB push, KDE Connect, LocalSend

**Avoid cloud sync** (Google Drive, Dropbox) - sync delays cause stale config issues.

### Multi-Device Sync

1. Create identity on first device
2. Save recovery phrase
3. On other devices: import `client-config.yml`, then recover using phrase

### Switching Back to Official Network

1. Clear Anytype data completely
2. Reopen Anytype (will use default network)
3. Create new identity or recover existing

---

## 7. Backup and Restore

### What Gets Backed Up

| Component | Backup Method | Criticality |
|-----------|---------------|-------------|
| MongoDB | `mongodump` | Critical (metadata) |
| .env, configs | tar archive | Critical (secrets) |
| SSL certs | Included in configs | Medium (auto-regenerate) |
| S3 data | N/A (in cloud) | Handled by Wasabi |

### Create Backup

```bash
# Manual backup
./scripts/backup.sh

# Custom location
BACKUP_DIR=/mnt/backup ./scripts/backup.sh

# Automated daily backup (cron)
crontab -e
# Add: 0 2 * * * /opt/anysync/scripts/backup.sh >> /var/log/anysync-backup.log 2>&1
```

### Backup Output

```
backups/
├── mongodb_20260109_143000.gz      # MongoDB dump
└── configs_20260109_143000.tar.gz  # .env, traefik/, bundle configs
```

### Restore MongoDB

```bash
# Stop bundle to avoid conflicts
docker compose stop any-sync-bundle

# Restore
docker exec -i mongo mongorestore --archive --gzip --drop < backups/mongodb_TIMESTAMP.gz

# Restart
docker compose start any-sync-bundle
```

### Restore Configuration

```bash
# Extract
tar -xzf backups/configs_TIMESTAMP.tar.gz -C /opt/anysync/

# Fix permissions
chmod 600 .env traefik/acme.json

# Restart
docker compose down && docker compose up -d
```

### Full Disaster Recovery

1. Provision new server
2. Install Docker, create `/opt/anysync`
3. Copy deployment files
4. Restore configs: `tar -xzf configs_*.tar.gz`
5. Update DNS to new IP
6. Start: `docker compose up -d`
7. Restore MongoDB: `docker exec -i mongo mongorestore ...`
8. Verify: `./scripts/health-check.sh`

---

## 8. Updates and Maintenance

### Update Containers

```bash
./scripts/update.sh
```

This will:
1. Create backup
2. Pull latest images
3. Restart containers
4. Run health check

Skip backup (not recommended):
```bash
SKIP_BACKUP=1 ./scripts/update.sh
```

### Check for Updates

```bash
docker compose pull --dry-run
```

### Clean Up

```bash
# Remove old images
docker image prune -a

# Remove old containers
docker container prune

# Remove unused volumes (careful!)
docker volume prune
```

### SSL Certificate

Certificates auto-renew via Let's Encrypt. Check status:
```bash
# View certificate info
openssl s_client -connect $DOMAIN:443 -servername $DOMAIN 2>/dev/null | openssl x509 -noout -dates
```

---

## 9. Troubleshooting

### Container Won't Start

```bash
# Check logs
docker compose logs any-sync-bundle

# Common causes:
# - MongoDB not ready: wait or restart
# - Invalid S3 credentials: check .env
# - Port conflict: check `ss -tlnp`
```

### Client Can't Connect

| Error | Cause | Solution |
|-------|-------|----------|
| Connection refused | Service not running | `docker compose up -d` |
| Connection timeout | Firewall blocking | Check security group ports |
| `SkipVerifyNotAllowed` | Wrong network identity | Clear client data, create new identity |
| `space is missing` | Server was reset | Clear client data, create new identity (don't use old recovery phrase) |

### MongoDB Issues

```bash
# Check replica set status
docker exec mongo mongosh --eval "rs.status()"

# Reinitialize if needed
docker exec mongo mongosh --eval "rs.initiate()"
```

### SSL Issues

```bash
# Check certificate
curl -vI https://$DOMAIN 2>&1 | grep -A5 "Server certificate"

# Force certificate renewal
rm traefik/acme.json
touch traefik/acme.json && chmod 600 traefik/acme.json
docker compose restart traefik
```

### S3 Connection Failed

```bash
# Test with AWS CLI
aws s3 ls s3://$S3_BUCKET --endpoint-url $S3_ENDPOINT

# Check credentials
cat .env | grep S3_
```

### Full Reset (Last Resort)

```bash
# Stop everything
docker compose down -v

# Remove all data (DESTRUCTIVE)
rm -rf data/*

# Reconfigure
nano .env

# Start fresh
docker compose up -d
```

**Warning**: This loses all metadata. S3 files remain but may be orphaned.

---

## 10. Security Hardening

### File Permissions

```bash
chmod 600 .env
chmod 600 traefik/acme.json
chmod 700 scripts/
chmod +x scripts/*.sh
```

### SSH Security

```bash
# /etc/ssh/sshd_config
PermitRootLogin no
PasswordAuthentication no
AllowUsers ubuntu
```

### Firewall (UFW)

```bash
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 33010/tcp # Any-Sync
sudo ufw allow 33020/udp # Any-Sync QUIC
sudo ufw enable
```

### Automatic Updates

```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades
```

### Monitor Logs

```bash
# Check for errors
docker compose logs --since 24h | grep -iE "(error|fail|warn)"

# Set up log rotation
cat > /etc/logrotate.d/docker-compose << 'EOF'
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    missingok
    delaycompress
    copytruncate
}
EOF
```

### Backup Encryption

```bash
# Encrypt before off-site storage
gpg --symmetric --cipher-algo AES256 backups/mongodb_*.gz

# Decrypt
gpg --decrypt mongodb_backup.gz.gpg > mongodb_backup.gz
```

---

## Quick Reference

### Daily Commands

```bash
# Status
docker compose ps
./scripts/health-check.sh

# Logs
docker compose logs -f --tail=100

# Backup
./scripts/backup.sh
```

### Restart After Config Change

```bash
docker compose down
docker compose up -d
```

### Get Client Config

```bash
cat /opt/anysync/data/bundle/client-config.yml
```

### Emergency Stop

```bash
docker compose down
```

---

## Related Documentation

- [LOCAL_TESTING.md](LOCAL_TESTING.md) - Local development/testing setup
- [Kiro Spec](.kiro/specs/personal-server-setup/) - Implementation requirements and design
