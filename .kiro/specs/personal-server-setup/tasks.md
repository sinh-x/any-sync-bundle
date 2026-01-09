# Personal Any-Sync Server Setup - Implementation Tasks

## Task Overview

This document breaks down the implementation into actionable tasks. The implementation follows two phases: local testing with Wasabi S3, then production deployment to AWS EC2.

**Total Tasks**: 13 tasks organized into 4 phases

**Requirements Reference**: `requirements.md`

**Design Reference**: `design.md`

---

## Phase 1: Local Testing Environment ✅ COMPLETE

- [x] **1.1** Create local Wasabi compose file
  - **Description**: Create `compose.wasabi.yml` using the AIO image with Wasabi S3 configuration
  - **Deliverables**:
    - `compose.wasabi.yml`
  - **Requirements**: Local Testing Requirements
  - **Dependencies**: None
  - **Completed**: 2026-01-08

- [x] **1.2** Create Wasabi environment template
  - **Description**: Create `.env.wasabi.example` with all required Wasabi S3 variables
  - **Deliverables**:
    - `.env.wasabi.example`
  - **Requirements**: Local Testing Requirements
  - **Dependencies**: 1.1
  - **Completed**: 2026-01-08
  - **Note**: Uses container's expected variable names (ANY_SYNC_BUNDLE_INIT_*)

- [x] **1.3** Configure Wasabi credentials
  - **Description**: Create `.env.wasabi` with actual Wasabi bucket and credentials (user action)
  - **Deliverables**:
    - `.env.wasabi` (user creates, not committed)
    - Wasabi bucket created in Wasabi console
  - **Requirements**: Wasabi S3 Storage Requirements
  - **Dependencies**: 1.2
  - **Completed**: 2026-01-08

- [x] **1.4** Test local deployment
  - **Description**: Run `docker compose -f compose.wasabi.yml up -d`, verify container starts, check logs for S3 connectivity
  - **Deliverables**:
    - Running container
    - Generated `data/client-config.yml`
  - **Requirements**: Local Testing Requirements
  - **Dependencies**: 1.3
  - **Completed**: 2026-01-08
  - **Note**: Must delete data/ directory when changing EXTERNAL_ADDR to regenerate config

- [x] **1.5** Test Anytype client sync
  - **Description**: Configure Anytype client with local client-config.yml, verify sync works
  - **Deliverables**:
    - Successful client connection
    - Files appear in Wasabi bucket
  - **Requirements**: Client Configuration user stories
  - **Dependencies**: 1.4
  - **Completed**: 2026-01-08
  - **Note**: Flatpak users must clear ~/.var/app/io.anytype.anytype/ for fresh start

---

## Phase 2: Production Deployment Files ✅ COMPLETE

- [x] **2.1** Create production directory structure
  - **Description**: Create `deploy/` directory with subdirectories for traefik, scripts
  - **Deliverables**:
    - `deploy/` directory structure
  - **Requirements**: Production Deployment Requirements
  - **Dependencies**: Phase 1 complete
  - **Completed**: 2026-01-09

- [x] **2.2** Create production Docker Compose
  - **Description**: Create `deploy/docker-compose.yml` with Traefik, any-sync-bundle (non-AIO), MongoDB, Redis
  - **Deliverables**:
    - `deploy/docker-compose.yml`
    - `deploy/.env.example`
  - **Requirements**: Production Deployment Requirements, Network/SSL Requirements
  - **Dependencies**: 2.1
  - **Completed**: 2026-01-09

- [x] **2.3** Create Traefik configuration
  - **Description**: Create Traefik static config with Let's Encrypt HTTP challenge
  - **Deliverables**:
    - `deploy/traefik/traefik.yml`
  - **Requirements**: Network/SSL Requirements
  - **Dependencies**: 2.1
  - **Completed**: 2026-01-09

- [x] **2.4** Create setup script
  - **Description**: Create setup.sh for initial deployment (prereq check, dirs, containers, MongoDB init)
  - **Deliverables**:
    - `deploy/scripts/setup.sh`
  - **Requirements**: Production Deployment Requirements
  - **Dependencies**: 2.2, 2.3
  - **Completed**: 2026-01-09

- [x] **2.5** Create operational scripts
  - **Description**: Create health-check.sh, backup.sh, update.sh
  - **Deliverables**:
    - `deploy/scripts/health-check.sh`
    - `deploy/scripts/backup.sh`
    - `deploy/scripts/update.sh`
  - **Requirements**: Maintenance user stories
  - **Dependencies**: 2.2
  - **Completed**: 2026-01-09

---

## Phase 3: Documentation ✅ COMPLETE

- [x] **3.1** Create local testing guide
  - **Description**: Comprehensive guide for local testing with Wasabi S3
  - **Deliverables**:
    - `docs/LOCAL_TESTING.md`
  - **Requirements**: Documentation Requirements
  - **Dependencies**: Phase 1 complete
  - **Completed**: 2026-01-09

- [x] **3.2** Create production guide
  - **Description**: Consolidated guide covering setup, configuration, management, backup, and troubleshooting
  - **Deliverables**:
    - `docs/PRODUCTION_GUIDE.md`
  - **Requirements**: Documentation Requirements
  - **Dependencies**: Phase 2 complete
  - **Completed**: 2026-01-09
  - **Note**: Consolidated approach - single comprehensive document instead of multiple separate files

---

## Phase 4: Production Deployment ✅ COMPLETE

- [x] **4.1** Deploy to DigitalOcean Droplet
  - **Description**: Launch Droplet, configure UFW firewall, Route53 A record, run setup.sh, verify SSL
  - **Deliverables**:
    - Running production server at `anytype.sinhn.com`
    - Valid SSL certificate (Let's Encrypt via Traefik)
    - Production client-config.yml
  - **Requirements**: All production requirements
  - **Dependencies**: Phase 2, Phase 3
  - **Completed**: 2026-01-09
  - **Server**: DigitalOcean Droplet (1-Click Docker image)
  - **IP**: 137.184.235.83

---

## File Structure After Implementation

```
any-sync-bundle/
├── compose.wasabi.yml              # Phase 1: Local testing
├── .env.wasabi.example             # Phase 1: Credentials template
├── .env.wasabi                     # Phase 1: User's credentials (gitignored)
├── data/                           # Phase 1: Local data (gitignored)
│   └── client-config.yml           # Local client config
│
├── deploy/                         # Phase 2: Production deployment files
│   ├── docker-compose.yml          # Production compose (Traefik + MongoDB + Redis + Bundle)
│   ├── .env.example                # Production environment template
│   ├── traefik/
│   │   └── traefik.yml             # Traefik config with Let's Encrypt
│   └── scripts/
│       ├── setup.sh                # Initial deployment script
│       ├── health-check.sh         # Service health verification
│       ├── backup.sh               # Backup MongoDB and configs
│       └── update.sh               # Update containers
│
├── docs/                           # Phase 3: Documentation
│   ├── LOCAL_TESTING.md            # Local testing guide
│   └── PRODUCTION_GUIDE.md         # Comprehensive production guide
│
└── .kiro/specs/personal-server-setup/
    ├── requirements.md
    ├── design.md
    └── tasks.md
```

---

## Task Completion Criteria

Each task is complete when:
- [ ] All deliverables exist and are functional
- [ ] Code follows existing project conventions
- [ ] Scripts are executable (`chmod +x`)

---

## Git Tracking

**Branch**: `feature/personal-server-setup`

**Commits**: (to be recorded during implementation)

---

**Task Status**: ✅ COMPLETE

**Current Phase**: All phases complete

**Progress**: 13/13 tasks (100%)

**Last Updated**: 2026-01-09

**Production Server**: `anytype.sinhn.com` (DigitalOcean Droplet)

## Implementation Notes

### Lessons Learned (Phase 1)

1. **Environment Variables**: Use `env_file` directive only - variable names must match container's expected names (ANY_SYNC_BUNDLE_INIT_*)

2. **Config Regeneration**: Delete `data/` directory to regenerate configs when changing EXTERNAL_ADDR
   - **IMPORTANT**: When server `data/` is deleted, ALL client data must also be cleared
   - Old recovery phrases will NOT work - the vault no longer exists on the new server

3. **Anytype Client Setup**:
   - Must log out and create NEW identity on self-hosted network
   - Existing vaults cannot be migrated directly
   - Flatpak users: clear `~/.var/app/io.anytype.anytype/` for fresh start
   - Native Linux: clear `~/.config/anytype/`
   - macOS: clear `~/Library/Application Support/anytype/`

4. **Connection Errors**:
   - `SkipVerifyNotAllowed`: Client using wrong network identity
   - `disk I/O error`: Corrupted client database, clear Anytype data
   - `space is missing`: Client trying to recover vault that doesn't exist on server (happens after server reset). Solution: clear client data, create NEW identity (don't use old recovery phrase)
   - `no access to the space` (mobile): Same issue on mobile - clear app data (Android) or reinstall (iOS), then create new identity

5. **IP Address Changes - Full Reset Required**:
   - Stop server: `docker compose -f compose.wasabi.yml down`
   - Delete server data: `rm -rf ./data`
   - Update `.env.wasabi` with new IP
   - Clear ALL client data (desktop + mobile)
   - Start server: `docker compose -f compose.wasabi.yml up -d`
   - Upload new `client-config.yml` to all clients
   - Create NEW identity (same on all devices using recovery phrase)

6. **Mobile Client Reset**:
   - Android: Settings > Apps > Anytype > Storage > Clear Data
   - iOS: Delete and reinstall the app

7. **Transferring client-config.yml to Mobile**:
   - **Avoid cloud sync** (Google Drive, Dropbox) - sync delays cause "no access to space" errors with stale configs
   - Recommended: Local HTTP server (`python3 -m http.server 8080`), ADB push, email, or direct transfer apps (KDE Connect, LocalSend)
   - If using cloud sync: force refresh on mobile before importing

### Lessons Learned (Phase 4 - Production Deployment)

1. **DigitalOcean 1-Click Docker Image**:
   - Has UFW firewall enabled by default (unlike standard Droplets)
   - Only ports 22, 2375, 2376 are open initially
   - Must manually open: `sudo ufw allow 80,443,33010/tcp && sudo ufw allow 33020/udp`

2. **Hidden Files Not Copied with SCP Glob**:
   - `scp deploy/* server:/path/` does NOT copy `.env.example` (dotfiles)
   - Solution: explicitly copy hidden files or use `scp -r deploy/. server:/path/`

3. **Windows Line Endings in .env**:
   - Causes invisible `\x13` (carriage return) characters in generated configs
   - Results in corrupted addresses like `anytype.sinhn.com\x13:33010`
   - Fix: `sed -i 's/\r$//' .env`
   - Verify clean: `cat -A .env` (should end with `$` not `^M$`)

4. **EXTERNAL_ADDRS Should NOT Include Port**:
   - Bundle automatically appends ports to the external address
   - Wrong: `ANY_SYNC_BUNDLE_INIT_EXTERNAL_ADDRS: "${DOMAIN}:33010"` → generates `domain:33010:33020`
   - Correct: `ANY_SYNC_BUNDLE_INIT_EXTERNAL_ADDRS: "${DOMAIN}"` → generates `domain:33020`

5. **Route53 A Record Configuration**:
   - Subdomain field should only contain the subdomain part (e.g., `anytype`)
   - Route53 automatically appends the domain (e.g., `.sinhn.com`)
   - Wrong: entering `anytype.sinhn.com` creates `anytype.sinhn.com.sinhn.com`

6. **Non-Root User Setup (Recommended)**:
   ```bash
   adduser <username>
   usermod -aG sudo <username>
   usermod -aG docker <username>
   # Copy SSH keys
   mkdir -p /home/<username>/.ssh
   cp ~/.ssh/authorized_keys /home/<username>/.ssh/
   chown -R <username>:<username> /home/<username>/.ssh
   ```

7. **Client "No Access to Space" Error**:
   - Occurs when client has cached data from different network/server
   - Must clear ALL client data on ALL devices before connecting to new server
   - Create NEW identity - old recovery phrases won't work on new server instance

8. **Config Regeneration After Fix**:
   - After fixing .env or docker-compose.yml, must regenerate configs:
   ```bash
   docker compose down
   rm -rf data/bundle/*
   docker compose up -d
   ```

9. **DigitalOcean vs AWS**:
   - DigitalOcean Droplets work fine as alternative to AWS EC2
   - Minimum: $12/mo (1 vCPU, 2GB RAM) sufficient for personal use
   - Static IP included free with Droplet (no extra cost)

### Production Deployment Summary

**Server Details:**
- Provider: DigitalOcean
- Image: 1-Click Docker on Ubuntu
- Domain: anytype.sinhn.com
- IP: 137.184.235.83

**Services Running:**
- Traefik (SSL termination, reverse proxy)
- Any-Sync-Bundle (coordinator, consensus, filenode, sync)
- MongoDB (metadata storage)
- Redis (cache)

**Storage:**
- Wasabi S3 (file storage)

**Ports:**
- 80/tcp (HTTP - Let's Encrypt)
- 443/tcp (HTTPS)
- 33010/tcp (Any-Sync DRPC)
- 33020/udp (Any-Sync QUIC)
