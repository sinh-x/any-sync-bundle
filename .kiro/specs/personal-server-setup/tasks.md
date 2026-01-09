# Personal Any-Sync Server Setup - Implementation Tasks

## Task Overview

This document breaks down the implementation into actionable tasks. The implementation follows two phases: local testing with Wasabi S3, then production deployment to AWS EC2.

**Total Tasks**: 15 tasks organized into 4 phases

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

## Phase 2: Production Deployment Files

- [ ] **2.1** Create production directory structure
  - **Description**: Create `deploy/` directory with subdirectories for traefik, scripts, docs
  - **Deliverables**:
    - `deploy/` directory structure
  - **Requirements**: Production Deployment Requirements
  - **Dependencies**: Phase 1 complete

- [ ] **2.2** Create production Docker Compose
  - **Description**: Create `deploy/docker-compose.yml` with Traefik, any-sync-bundle (non-AIO), MongoDB, Redis
  - **Deliverables**:
    - `deploy/docker-compose.yml`
    - `deploy/.env.example`
  - **Requirements**: Production Deployment Requirements, Network/SSL Requirements
  - **Dependencies**: 2.1

- [ ] **2.3** Create Traefik configuration
  - **Description**: Create Traefik static config with Let's Encrypt HTTP challenge
  - **Deliverables**:
    - `deploy/traefik/traefik.yml`
  - **Requirements**: Network/SSL Requirements
  - **Dependencies**: 2.1

- [ ] **2.4** Create setup script
  - **Description**: Create setup.sh for initial deployment (prereq check, dirs, containers, MongoDB init)
  - **Deliverables**:
    - `deploy/scripts/setup.sh`
  - **Requirements**: Production Deployment Requirements
  - **Dependencies**: 2.2, 2.3

- [ ] **2.5** Create operational scripts
  - **Description**: Create health-check.sh, backup.sh, update.sh
  - **Deliverables**:
    - `deploy/scripts/health-check.sh`
    - `deploy/scripts/backup.sh`
    - `deploy/scripts/update.sh`
  - **Requirements**: Maintenance user stories
  - **Dependencies**: 2.2

---

## Phase 3: Documentation

- [ ] **3.1** Create deployment README
  - **Description**: Quick start guide for both local testing and production deployment
  - **Deliverables**:
    - `deploy/docs/README.md`
  - **Requirements**: Documentation Requirements
  - **Dependencies**: Phase 2 complete

- [ ] **3.2** Create configuration reference
  - **Description**: Document all environment variables for both environments
  - **Deliverables**:
    - `deploy/docs/CONFIGURATION.md`
  - **Requirements**: Documentation Requirements
  - **Dependencies**: 2.2

- [ ] **3.3** Create troubleshooting guide
  - **Description**: Document common issues and solutions for both environments
  - **Deliverables**:
    - `deploy/docs/TROUBLESHOOTING.md`
  - **Requirements**: Documentation Requirements
  - **Dependencies**: Phase 2 complete

- [ ] **3.4** Create backup documentation
  - **Description**: Document backup and restore procedures
  - **Deliverables**:
    - `deploy/docs/BACKUP.md`
  - **Requirements**: Documentation Requirements
  - **Dependencies**: 2.5

---

## Phase 4: Production Deployment

- [ ] **4.1** Deploy to AWS EC2
  - **Description**: Launch EC2, configure security group, Route53 A record, run setup.sh, verify SSL
  - **Deliverables**:
    - Running production server
    - Valid SSL certificate
    - Production client-config.yml
  - **Requirements**: All production requirements
  - **Dependencies**: Phase 2, Phase 3

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
├── deploy/                         # Phase 2-4: Production
│   ├── docker-compose.yml
│   ├── .env.example
│   ├── traefik/
│   │   └── traefik.yml
│   ├── scripts/
│   │   ├── setup.sh
│   │   ├── health-check.sh
│   │   ├── backup.sh
│   │   └── update.sh
│   └── docs/
│       ├── README.md
│       ├── CONFIGURATION.md
│       ├── TROUBLESHOOTING.md
│       └── BACKUP.md
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

**Task Status**: In Progress

**Current Phase**: Phase 2 - Production Deployment Files

**Progress**: 5/15 tasks (33%)

**Last Updated**: 2026-01-09

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
