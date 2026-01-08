# Personal Any-Sync Server Setup Requirements

## 1. Introduction

This document specifies the requirements for setting up a personal any-sync server for self-hosted Anytype synchronization. The implementation provides two deployment modes:

1. **Local Testing**: Quick setup for development/testing on local machine
2. **Production**: Full deployment on AWS EC2 with SSL and domain

Both environments use Wasabi S3 for file storage and can run simultaneously (local for testing, production for daily use).

**Architecture Overview**: Docker Compose deployments using Wasabi S3 storage. Local uses AIO (all-in-one) image for simplicity. Production uses separate containers with Traefik reverse proxy and Let's Encrypt SSL.

## 2. User Stories

### Local Testing
- **As a developer**, I want to test any-sync-bundle locally before production deployment, so that I can verify the setup works
- **As a developer**, I want local and production to use the same S3 bucket, so that I can test with real data
- **As a developer**, I want to run local and production simultaneously, so that I can compare behavior or migrate gradually

### Server Administrator
- **As a self-hoster**, I want to deploy any-sync-bundle with a single command, so that I can quickly get my personal sync server running
- **As a self-hoster**, I want to use S3-compatible storage, so that I can scale file storage independently and use existing object storage
- **As a self-hoster**, I want my server accessible over the internet with SSL, so that my Anytype clients can sync from anywhere securely

### Maintenance
- **As a server admin**, I want clear documentation on backup procedures, so that I can protect my data
- **As a server admin**, I want to monitor server health, so that I can ensure reliable sync service
- **As a server admin**, I want to update the server easily, so that I can stay current with security fixes

### Client Configuration
- **As an Anytype user**, I want to easily configure my client to use my personal server, so that I can sync without manual network configuration
- **As an Anytype user**, I want the client config file generated automatically, so that I don't have to manually edit configuration
- **As an Anytype user**, I want separate client configs for local and production, so that I can switch between environments

## 3. Acceptance Criteria

### Local Testing Requirements
- **WHEN** user runs `docker compose -f compose.wasabi.yml up -d`, **THEN** the AIO container **SHALL** start with embedded MongoDB/Redis
- **WHEN** local deployment starts, **THEN** it **SHALL** use the configured local IP as external address
- **WHEN** local deployment completes, **THEN** it **SHALL** generate `data/client-config.yml` for local testing
- **WHEN** Anytype client uses local client-config.yml, **THEN** it **SHALL** connect via local IP:33010

### Production Deployment Requirements
- **WHEN** user runs the setup script, **THEN** the system **SHALL** deploy all required containers (Traefik, any-sync-bundle, MongoDB, Redis)
- **WHEN** containers start, **THEN** the system **SHALL** automatically generate bundle-config.yml with Wasabi S3 storage configuration
- **WHEN** deployment completes, **THEN** the system **SHALL** generate client-config.yml for Anytype clients
- **IF** any container fails health check, **THEN** the system **SHALL** report clear error messages

### Dual Environment Requirements
- **WHEN** both local and production run simultaneously, **THEN** they **SHALL NOT** conflict (different data directories, different networks)
- **WHEN** both environments use same Wasabi bucket, **THEN** they **SHALL** share file storage data
- **WHEN** user switches client-config.yml, **THEN** Anytype client **SHALL** connect to the corresponding environment

### Wasabi S3 Storage Requirements
- **WHEN** Wasabi credentials are provided, **THEN** the system **SHALL** configure filenode to use Wasabi S3 backend
- **WHEN** filenode starts, **THEN** it **SHALL** connect to pre-existing Wasabi bucket (user creates bucket beforehand)
- **IF** Wasabi connection fails, **THEN** the system **SHALL** log detailed error and fail fast

### Network/SSL Requirements
- **WHEN** domain is configured, **THEN** the system **SHALL** expose services via reverse proxy (Traefik)
- **WHEN** SSL is enabled, **THEN** the system **SHALL** obtain certificates via Let's Encrypt HTTP challenge
- **WHEN** client connects, **THEN** the system **SHALL** accept connections on TCP 33010 and QUIC/UDP 33020
- **IF** SSL certificate renewal fails, **THEN** the system **SHALL** alert administrator

### Documentation Requirements
- **WHEN** user reads setup guide, **THEN** they **SHALL** be able to complete deployment without external help
- **WHEN** troubleshooting is needed, **THEN** documentation **SHALL** cover common failure scenarios
- **WHEN** backup is needed, **THEN** documentation **SHALL** provide clear backup/restore procedures

## 4. Technical Architecture

### Local Testing Stack
- **Image**: AIO (all-in-one) with embedded MongoDB/Redis
- **Container Runtime**: Docker with Docker Compose
- **External Address**: Local machine IP (e.g., 192.168.x.x:33010)
- **SSL**: None (local network only)
- **Data Directory**: `./data/` (local to project)

### Production Stack
- **Server**: AWS EC2 instance (Ubuntu 22.04/24.04)
- **Container Runtime**: Docker with Docker Compose
- **Reverse Proxy**: Traefik with Let's Encrypt SSL
- **External Address**: Domain name (e.g., sync.domain.com:33010)
- **DNS**: AWS Route53 with A record pointing to EC2 public IP
- **Data Directory**: `/opt/anysync/data/`

### Shared Services
- **Object Storage**: Wasabi S3 (same bucket for both environments)

### Local Testing Topology
```
┌─────────────── Local Machine ───────────────┐
│                                              │
│  [any-sync-bundle AIO]                       │
│    - Embedded MongoDB                        │
│    - Embedded Redis                          │
│    - Ports: 33010 TCP, 33020 UDP            │
│                                              │
│  Data: ./data/                               │
│    - bundle-config.yml                       │
│    - client-config.yml  ◄── Use this config │
│    - storage/                                │
└──────────────────────────────────────────────┘
            │
            │ S3 API (HTTPS)
            ▼
    [Wasabi S3 Bucket]
            ▲
            │ S3 API (HTTPS)
            │
┌─────────────── EC2 Instance ────────────────┐
│                                              │
│  [Traefik :80/:443] ──► SSL termination     │
│        │                                     │
│        └──► [any-sync-bundle]               │
│                   │                          │
│  Direct ports:    │                          │
│    :33010 TCP ◄───┤                          │
│    :33020 UDP ◄───┘                          │
│                                              │
│  [MongoDB]  [Redis]                          │
│                                              │
│  Data: /opt/anysync/data/                    │
│    - client-config.yml  ◄── Use this config │
└──────────────────────────────────────────────┘

Anytype Client:
  - Local testing: Use local client-config.yml → connects to 192.168.x.x:33010
  - Production:    Use prod client-config.yml  → connects to sync.domain.com:33010
```

## 5. Feature Specifications

### Local Testing Features
1. **compose.wasabi.yml**: Docker Compose file for local testing with Wasabi
2. **.env.wasabi.example**: Template for Wasabi credentials
3. **AIO image**: Uses all-in-one image with embedded MongoDB/Redis
4. **Client config**: Generates client-config.yml with local IP address

### Production Features
1. **One-command deployment**: setup.sh script to bring up entire stack
2. **S3 storage integration**: Configure filenode with Wasabi credentials
3. **SSL termination**: Automatic HTTPS with Let's Encrypt via Traefik
4. **Client config generation**: Auto-generate client-config.yml with domain

### Automation Scripts (Production)
1. **setup.sh**: Initial deployment and configuration
2. **backup.sh**: Backup MongoDB and configs
3. **update.sh**: Pull latest images and restart services
4. **health-check.sh**: Verify all services are operational

### Documentation
1. **README.md**: Quick start guide for both local and production
2. **CONFIGURATION.md**: All configuration options explained
3. **TROUBLESHOOTING.md**: Common issues and solutions
4. **BACKUP.md**: Backup and restore procedures

## 6. Success Criteria

### Deployment Success
- **WHEN** setup.sh completes, **THEN** all containers **SHALL** be healthy within 60 seconds
- **WHEN** client-config.yml is used, **THEN** Anytype client **SHALL** connect successfully
- **WHEN** file is synced, **THEN** it **SHALL** appear in S3 bucket

### Operational Success
- **WHEN** server runs for 24 hours, **THEN** uptime **SHALL** be >99%
- **WHEN** backup.sh runs, **THEN** backup **SHALL** complete without data loss
- **WHEN** update.sh runs, **THEN** downtime **SHALL** be <5 minutes

## 7. Assumptions and Dependencies

### Technical Assumptions
- User has AWS account with EC2 access
- User has a domain managed in AWS Route53
- User has Wasabi account with S3 bucket created
- Ports 80, 443, 33010 (TCP), 33020 (UDP) are open in EC2 security group
- EC2 instance has at least 2GB RAM and 20GB EBS storage

### External Dependencies
- Let's Encrypt ACME servers for SSL certificates
- AWS Route53 for DNS (A record only, one-time setup)
- Wasabi S3 for file storage
- Docker Hub / GitHub Container Registry for images

## 8. Constraints and Limitations

### Technical Constraints
- Single-node deployment (not HA/clustered)
- MongoDB runs as single replica set member
- QUIC/UDP requires direct port exposure (no HTTP proxy)

### Security Constraints
- SSL/TLS required for production use
- Default credentials must be changed before deployment
- S3 bucket should not be publicly accessible

## 9. Out of Scope

- Multi-node/HA deployment
- Kubernetes deployment
- Custom authentication providers
- Monitoring stack (Prometheus/Grafana)
- Automated disaster recovery

---

**Document Status**: Phase 1 Validated

**Last Updated**: 2026-01-09

**Version**: 1.1

**Implementation Status**: Local testing requirements validated
