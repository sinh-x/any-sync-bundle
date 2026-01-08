# Personal Any-Sync Server Setup - Design Document

## Overview

This document defines the technical design for deploying a personal any-sync server with Wasabi S3 storage. Two deployment modes are supported:

1. **Local Testing**: Single AIO container for development/validation
2. **Production**: Full stack on AWS EC2 with Traefik, SSL, and separate services

Both environments share the same Wasabi S3 bucket and can run simultaneously.

## Local Testing Environment

### Architecture (Local)

```
┌──────────────────────────────────────────────────────────┐
│                    LOCAL MACHINE                          │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐ │
│  │            ANY-SYNC-BUNDLE (AIO)                     │ │
│  │                                                      │ │
│  │   ┌──────────────┐  ┌────────────┐  ┌────────────┐ │ │
│  │   │  Coordinator │  │  Filenode  │  │    Sync    │ │ │
│  │   │  Consensus   │  │            │  │            │ │ │
│  │   └──────────────┘  └────────────┘  └────────────┘ │ │
│  │                                                      │ │
│  │   ┌──────────────┐  ┌────────────┐                 │ │
│  │   │   MongoDB    │  │   Redis    │  (embedded)     │ │
│  │   │   (embedded) │  │ (embedded) │                 │ │
│  │   └──────────────┘  └────────────┘                 │ │
│  │                                                      │ │
│  │   Ports: 33010 (TCP), 33020 (UDP)                  │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                           │
│  Data: ./data/                                            │
│    ├── bundle-config.yml                                  │
│    ├── client-config.yml  ◄── Copy to Anytype client     │
│    └── storage/                                           │
└──────────────────────────────────────────────────────────┘
                          │
                          │ HTTPS (S3 API)
                          ▼
                  [Wasabi S3 Bucket]
```

### Local Docker Compose

```yaml
# compose.wasabi.yml
services:
  any-sync-bundle:
    image: ghcr.io/grishy/any-sync-bundle:1.2.1-2025-12-10
    container_name: any-sync-bundle-wasabi
    restart: unless-stopped
    ports:
      - "33010:33010"
      - "33020:33020/udp"
    volumes:
      - ./data:/data
    env_file:
      - .env.wasabi
    environment:
      ANY_SYNC_BUNDLE_INIT_EXTERNAL_ADDRS: "${EXTERNAL_ADDR}"
      ANY_SYNC_BUNDLE_INIT_S3_BUCKET: "${S3_BUCKET}"
      ANY_SYNC_BUNDLE_INIT_S3_ENDPOINT: "${S3_ENDPOINT}"
      ANY_SYNC_BUNDLE_INIT_S3_REGION: "${S3_REGION}"
      AWS_ACCESS_KEY_ID: "${AWS_ACCESS_KEY_ID}"
      AWS_SECRET_ACCESS_KEY: "${AWS_SECRET_ACCESS_KEY}"
```

### Local Environment Variables

```bash
# .env.wasabi.example

# Your machine's local IP (run: ip addr | grep "inet " | grep -v 127.0.0.1)
EXTERNAL_ADDR=192.168.1.100

# Wasabi S3 Configuration
S3_BUCKET=your-anysync-bucket
S3_ENDPOINT=https://s3.us-east-1.wasabisys.com
S3_REGION=us-east-1
AWS_ACCESS_KEY_ID=your-wasabi-access-key
AWS_SECRET_ACCESS_KEY=your-wasabi-secret-key
```

### Local Testing Steps

```bash
# 1. Copy and configure environment
cp .env.wasabi.example .env.wasabi
# Edit .env.wasabi with your values

# 2. Start the container
docker compose -f compose.wasabi.yml up -d

# 3. Check logs
docker compose -f compose.wasabi.yml logs -f

# 4. Once started, copy client config to Anytype
# File: ./data/client-config.yml
```

### How Anytype Client Connects (Local)

1. Container starts and generates `client-config.yml` with `EXTERNAL_ADDR` (your local IP)
2. Copy `./data/client-config.yml` to Anytype client
3. Client connects to `192.168.x.x:33010` (your local IP)
4. Files sync to Wasabi S3 bucket

---

## Production Environment

### Architecture (Production)

```
                                    INTERNET
                                        │
                                        ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                              AWS EC2 INSTANCE                             │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │                         DOCKER NETWORK                               │ │
│  │                                                                      │ │
│  │   ┌─────────────┐      ┌──────────────────────────────────────┐    │ │
│  │   │   TRAEFIK   │      │         ANY-SYNC-BUNDLE              │    │ │
│  │   │             │      │                                       │    │ │
│  │   │  :80 ───────┼──────┼─► ACME HTTP Challenge                │    │ │
│  │   │  :443 ──────┼──────┼─► HTTPS → HTTP proxy to :33010       │    │ │
│  │   │             │      │                                       │    │ │
│  │   └─────────────┘      │  Services:                           │    │ │
│  │                        │   - Coordinator  (/CoordinatorService)│    │ │
│  │   HOST PORTS:          │   - Consensus    (/ConsensusService)  │    │ │
│  │   :33010 TCP ◄─────────┼─► - Filenode     (/FileService)       │    │ │
│  │   :33020 UDP ◄─────────┼─► - Sync         (/SpaceSyncService)  │    │ │
│  │                        │                                       │    │ │
│  │                        └───────────────┬───────────────────────┘    │ │
│  │                                        │                            │ │
│  │                         ┌──────────────┴──────────────┐             │ │
│  │                         │                             │             │ │
│  │                         ▼                             ▼             │ │
│  │                  ┌────────────┐              ┌────────────┐         │ │
│  │                  │  MONGODB   │              │   REDIS    │         │ │
│  │                  │   :27017   │              │   :6379    │         │ │
│  │                  │            │              │            │         │ │
│  │                  │ coordinator│              │  filenode  │         │ │
│  │                  │ consensus  │              │   cache    │         │ │
│  │                  │   data     │              │            │         │ │
│  │                  └────────────┘              └────────────┘         │ │
│  │                                                                      │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
│                                                                           │
│  VOLUMES:                                                                 │
│   ./traefik/          - Traefik config + Let's Encrypt certs             │
│   ./data/mongodb/     - MongoDB data                                      │
│   ./data/redis/       - Redis persistence                                 │
│   ./data/bundle/      - any-sync-bundle config + sync storage            │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
                                        │
                                        │ HTTPS (S3 API)
                                        ▼
                              ┌───────────────────┐
                              │    WASABI S3      │
                              │                   │
                              │  Bucket: anysync  │
                              │  Region: us-east-1│
                              └───────────────────┘
```

### Extensibility (Future Services)

Traefik supports multiple services routed by domain:

```
sync.domain.com  ──► any-sync-bundle
www.domain.com   ──► website (nginx/etc)
api.domain.com   ──► your-api
```

Add new services with Traefik labels and Route53 A records pointing to the same EC2 IP.

### Technology Stack

**Infrastructure**
- AWS EC2: t3.small or t3.medium (2 vCPU, 2-4GB RAM)
- Ubuntu 22.04 or 24.04 LTS
- Docker Engine 24.x+ with Docker Compose v2

**Containers**
- `traefik:v3.0` - Reverse proxy with automatic SSL
- `ghcr.io/anyproto/any-sync-bundle:latest` - Anytype sync services
- `mongo:7.0` - Database for coordinator/consensus
- `redis:7-alpine` - Cache for filenode

**External Services**
- AWS Route53 - DNS (A record only)
- Wasabi S3 - File storage
- Let's Encrypt - SSL certificates (automatic via HTTP challenge)

## File Structure

```
/opt/anysync/                           # Deployment root
├── docker-compose.yml                  # Main compose file
├── .env                                # Environment variables (secrets)
├── .env.example                        # Template for .env
├── traefik/
│   ├── traefik.yml                     # Traefik static configuration
│   └── acme.json                       # Let's Encrypt certs (auto-generated)
├── scripts/
│   ├── setup.sh                        # Initial setup script
│   ├── backup.sh                       # Backup MongoDB + configs
│   ├── restore.sh                      # Restore from backup
│   ├── update.sh                       # Update containers
│   └── health-check.sh                 # Check service health
├── data/
│   ├── mongodb/                        # MongoDB data volume
│   ├── redis/                          # Redis data volume
│   └── bundle/                         # any-sync-bundle data
│       ├── bundle-config.yml           # Generated bundle config
│       ├── client-config.yml           # Generated client config
│       └── storage/                    # Local storage (sync node)
└── docs/
    ├── README.md                       # Quick start guide
    ├── CONFIGURATION.md                # Configuration reference
    ├── TROUBLESHOOTING.md              # Common issues
    └── BACKUP.md                       # Backup procedures
```

## Components and Configuration

### 1. Docker Compose

```yaml
# docker-compose.yml
services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik/traefik.yml:/etc/traefik/traefik.yml:ro
      - ./traefik/acme.json:/acme.json
    networks:
      - anysync

  any-sync-bundle:
    image: ghcr.io/anyproto/any-sync-bundle:latest
    container_name: any-sync-bundle
    restart: unless-stopped
    depends_on:
      mongodb:
        condition: service_healthy
      redis:
        condition: service_healthy
    ports:
      - "33010:33010"       # TCP - direct, not through Traefik
      - "33020:33020/udp"   # QUIC/UDP - direct
    environment:
      - ANY_SYNC_MONGO_URI=mongodb://mongodb:27017
      - ANY_SYNC_REDIS_URL=redis://redis:6379
      - ANY_SYNC_S3_ENDPOINT=${S3_ENDPOINT}
      - ANY_SYNC_S3_REGION=${S3_REGION}
      - ANY_SYNC_S3_BUCKET=${S3_BUCKET}
      - ANY_SYNC_S3_ACCESS_KEY=${S3_ACCESS_KEY}
      - ANY_SYNC_S3_SECRET_KEY=${S3_SECRET_KEY}
      - ANY_SYNC_NETWORK_EXTERNAL_ADDR=${DOMAIN}:33010
    volumes:
      - ./data/bundle:/data
    networks:
      - anysync
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.anysync.rule=Host(`${DOMAIN}`)"
      - "traefik.http.routers.anysync.entrypoints=websecure"
      - "traefik.http.routers.anysync.tls.certresolver=letsencrypt"
      - "traefik.http.services.anysync.loadbalancer.server.port=33010"

  mongodb:
    image: mongo:7.0
    container_name: mongodb
    restart: unless-stopped
    command: ["--replSet", "rs0", "--bind_ip_all"]
    volumes:
      - ./data/mongodb:/data/db
    networks:
      - anysync
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  redis:
    image: redis:7-alpine
    container_name: redis
    restart: unless-stopped
    command: ["redis-server", "--appendonly", "yes"]
    volumes:
      - ./data/redis:/data
    networks:
      - anysync
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

networks:
  anysync:
    driver: bridge
```

### 2. Traefik Configuration

```yaml
# traefik/traefik.yml
api:
  dashboard: false  # Disabled for security

log:
  level: INFO

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: anysync

certificatesResolvers:
  letsencrypt:
    acme:
      email: "${ACME_EMAIL}"
      storage: /acme.json
      httpChallenge:
        entryPoint: web
```

### 3. Environment Variables

```bash
# .env.example

# Domain Configuration
DOMAIN=sync.yourdomain.com

# Let's Encrypt
ACME_EMAIL=your-email@example.com

# Wasabi S3 Configuration
S3_ENDPOINT=https://s3.wasabisys.com
S3_REGION=us-east-1
S3_BUCKET=your-anysync-bucket
S3_ACCESS_KEY=your-wasabi-access-key
S3_SECRET_KEY=your-wasabi-secret-key
```

## Scripts

### setup.sh (Initial Deployment)

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Any-Sync Personal Server Setup ==="

# 1. Check prerequisites
echo "[1/6] Checking prerequisites..."
command -v docker &>/dev/null || { echo "ERROR: Docker not installed"; exit 1; }
docker compose version &>/dev/null || { echo "ERROR: Docker Compose v2 not installed"; exit 1; }
echo "  ✓ Docker and Docker Compose found"

# 2. Check .env
echo "[2/6] Checking configuration..."
[[ -f "$ROOT_DIR/.env" ]] || { echo "ERROR: .env not found. Copy .env.example to .env"; exit 1; }
source "$ROOT_DIR/.env"
for var in DOMAIN ACME_EMAIL S3_ENDPOINT S3_REGION S3_BUCKET S3_ACCESS_KEY S3_SECRET_KEY; do
    [[ -n "${!var:-}" ]] || { echo "ERROR: $var not set in .env"; exit 1; }
done
echo "  ✓ Configuration valid"

# 3. Create directories
echo "[3/6] Creating directories..."
mkdir -p "$ROOT_DIR/data"/{mongodb,redis,bundle}
mkdir -p "$ROOT_DIR/traefik"
touch "$ROOT_DIR/traefik/acme.json" && chmod 600 "$ROOT_DIR/traefik/acme.json"
echo "  ✓ Directories created"

# 4. Start containers
echo "[4/6] Starting containers..."
cd "$ROOT_DIR" && docker compose up -d
echo "  ✓ Containers started"

# 5. Initialize MongoDB replica set
echo "[5/6] Initializing MongoDB..."
sleep 10
docker exec mongodb mongosh --eval "rs.initiate({_id:'rs0',members:[{_id:0,host:'mongodb:27017'}]})" 2>/dev/null || true
echo "  ✓ MongoDB initialized"

# 6. Verify
echo "[6/6] Verifying deployment..."
sleep 15
docker compose ps

echo ""
echo "=== Setup Complete ==="
echo "Next: Wait 1-2 min for SSL, then copy data/bundle/client-config.yml to Anytype"
```

### health-check.sh

```bash
#!/bin/bash
set -euo pipefail

echo "=== Any-Sync Health Check ==="

echo -e "\n[Containers]"
docker compose ps --format "table {{.Name}}\t{{.Status}}"

echo -e "\n[MongoDB]"
docker exec mongodb mongosh --quiet --eval "db.adminCommand('ping')" && echo "  ✓ OK" || echo "  ✗ FAIL"

echo -e "\n[Redis]"
docker exec redis redis-cli ping | grep -q PONG && echo "  ✓ OK" || echo "  ✗ FAIL"

echo -e "\n[Ports]"
nc -z localhost 33010 2>/dev/null && echo "  ✓ 33010/TCP open" || echo "  ✗ 33010/TCP closed"

echo -e "\n[SSL]"
source .env
curl -sI "https://${DOMAIN}" 2>/dev/null | head -1 || echo "  ⏳ Cert may still be provisioning"
```

### backup.sh

```bash
#!/bin/bash
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

echo "=== Backup Starting ==="

# MongoDB
echo "[1/2] MongoDB..."
docker exec mongodb mongodump --archive --gzip > "$BACKUP_DIR/mongodb_${TIMESTAMP}.gz"

# Configs
echo "[2/2] Configs..."
tar -czf "$BACKUP_DIR/configs_${TIMESTAMP}.tar.gz" .env traefik/ data/bundle/*.yml 2>/dev/null || true

echo "=== Backup Complete: $BACKUP_DIR ==="
ls -lh "$BACKUP_DIR"/*_${TIMESTAMP}*
```

### update.sh

```bash
#!/bin/bash
set -euo pipefail

echo "=== Updating Any-Sync ==="

./scripts/backup.sh
docker compose pull
docker compose up -d
sleep 10
./scripts/health-check.sh

echo "=== Update Complete ==="
```

## Error Handling

| Error | Cause | Solution |
|-------|-------|----------|
| MongoDB unhealthy | Replica set not initialized | `docker exec mongodb mongosh --eval "rs.initiate()"` |
| SSL cert not issued | Port 80 blocked or DNS not propagated | Check security group, verify `dig sync.domain.com` |
| S3 connection failed | Invalid credentials/endpoint | Verify S3_* variables in .env |
| Client can't connect | Ports 33010/33020 blocked | Check EC2 security group |

## Troubleshooting (Lessons from Implementation)

### Local Testing Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Env variables not loaded | Docker Compose variable substitution vs env_file | Use container's expected variable names (ANY_SYNC_BUNDLE_INIT_*) directly in env_file |
| External address empty in client-config | Config persisted from previous run | Delete `data/` directory and restart container |
| `SkipVerifyNotAllowed` error | Client using identity from different network | Log out, clear Anytype data, create NEW identity on self-hosted network |
| `disk I/O error` in Anytype | Corrupted client SQLite database | Clear Anytype data directory |

### Anytype Client Setup

**Standard installation:**
```bash
rm -rf ~/.config/anytype/
rm -rf ~/.local/share/anytype/
```

**Flatpak installation:**
```bash
rm -rf ~/.var/app/io.anytype.anytype/
```

**Steps to connect:**
1. Log out of current identity
2. On login screen, click gear icon → Self-hosted
3. Upload `client-config.yml`
4. **Create NEW identity** (not login with existing key)

### Config Regeneration

When changing `ANY_SYNC_BUNDLE_INIT_EXTERNAL_ADDRS`:
```bash
docker compose -f compose.wasabi.yml down
sudo rm -rf data/
docker compose -f compose.wasabi.yml up -d
```

## Security

### EC2 Security Group

| Type | Port | Source | Purpose |
|------|------|--------|---------|
| HTTP | 80 | 0.0.0.0/0 | Let's Encrypt |
| HTTPS | 443 | 0.0.0.0/0 | Web traffic |
| TCP | 33010 | 0.0.0.0/0 | Any-sync TCP |
| UDP | 33020 | 0.0.0.0/0 | Any-sync QUIC |
| SSH | 22 | Your IP | Management |

### File Permissions
- `.env`: `chmod 600` (secrets)
- `traefik/acme.json`: `chmod 600` (SSL keys)

## Testing Checklist

### Pre-Deployment
- [ ] EC2 running Ubuntu 22.04/24.04
- [ ] Docker + Docker Compose installed
- [ ] Security group ports open
- [ ] Route53 A record created
- [ ] Wasabi bucket + credentials ready

### Post-Deployment
- [ ] `docker compose ps` shows all healthy
- [ ] `curl -I https://sync.yourdomain.com` returns 200
- [ ] `nc -zv sync.yourdomain.com 33010` connects
- [ ] `data/bundle/client-config.yml` exists
- [ ] Anytype client connects and syncs

---

**Requirements Traceability**: This design addresses all requirements from `requirements.md`

**Review Status**: Phase 1 Validated

**Last Updated**: 2026-01-09

**Implementation Status**: Local testing (Phase 1) completed and validated
