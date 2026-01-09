# Local Testing Environment Guide

This guide covers how to use the any-sync-bundle local testing environment with Wasabi S3 storage (Phase 1).

## Overview

The local testing environment allows you to run a complete any-sync server on your local machine using:
- **AIO (All-In-One) container**: Bundles all services with embedded MongoDB and Redis
- **Wasabi S3**: Cloud object storage for file sync
- **Zero external dependencies**: Everything runs in a single container

```
┌─────────────────────────────────────────────────────────┐
│                    LOCAL MACHINE                        │
│                                                         │
│  ┌───────────────────────────────────────────────────┐ │
│  │            ANY-SYNC-BUNDLE (AIO)                  │ │
│  │                                                   │ │
│  │   Coordinator │ Filenode │ Sync │ Consensus      │ │
│  │   MongoDB (embedded) │ Redis (embedded)          │ │
│  │                                                   │ │
│  │   Ports: 33010 (TCP), 33020 (UDP)                │ │
│  └───────────────────────────────────────────────────┘ │
│                                                         │
│  ./data/                                                │
│    ├── bundle-config.yml   (server config)             │
│    ├── client-config.yml   ◄── Copy to Anytype client  │
│    └── storage/            (local data)                │
└─────────────────────────────────────────────────────────┘
                        │
                        │ HTTPS (S3 API)
                        ▼
                [Wasabi S3 Bucket]
```

---

## Prerequisites

1. **Docker** installed and running
2. **Wasabi account** at https://wasabi.com (free tier available)
3. **Local IP address** (not `localhost` or `127.0.0.1`)

### Create Wasabi Bucket

1. Sign up/log in at https://console.wasabisys.com
2. Create a new bucket in your preferred region
3. Generate access keys: **Access Keys > Create New Access Key**
4. Save your Access Key ID and Secret Key

---

## Quick Start

```bash
# 1. Copy environment template
cp .env.wasabi.example .env.wasabi

# 2. Edit .env.wasabi with your values (see Configuration section)
nano .env.wasabi

# 3. Start the container
docker compose -f compose.wasabi.yml up -d

# 4. Check logs for successful startup
docker compose -f compose.wasabi.yml logs -f

# 5. Once running, configure Anytype client with:
#    ./data/client-config.yml
```

---

## Configuration

### Environment Variables (.env.wasabi)

Copy `.env.wasabi.example` to `.env.wasabi` and configure:

| Variable | Description | Example |
|----------|-------------|---------|
| `ANY_SYNC_BUNDLE_INIT_EXTERNAL_ADDRS` | Your machine's local IP | `192.168.1.100` |
| `ANY_SYNC_BUNDLE_INIT_S3_BUCKET` | Wasabi bucket name | `my-anysync-bucket` |
| `ANY_SYNC_BUNDLE_INIT_S3_ENDPOINT` | Wasabi region endpoint | `https://s3.us-east-1.wasabisys.com` |
| `ANY_SYNC_BUNDLE_INIT_S3_REGION` | Wasabi region | `us-east-1` |
| `AWS_ACCESS_KEY_ID` | Wasabi access key | (from Wasabi console) |
| `AWS_SECRET_ACCESS_KEY` | Wasabi secret key | (from Wasabi console) |

### Find Your Local IP

```bash
# Linux
ip addr | grep "inet " | grep -v 127.0.0.1

# macOS
ipconfig getifaddr en0

# Windows (PowerShell)
(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" }).IPAddress
```

### Wasabi Region Endpoints

| Region | Endpoint |
|--------|----------|
| US East 1 (N. Virginia) | `https://s3.us-east-1.wasabisys.com` |
| US East 2 (N. Virginia) | `https://s3.us-east-2.wasabisys.com` |
| US West 1 (Oregon) | `https://s3.us-west-1.wasabisys.com` |
| US Central 1 (Texas) | `https://s3.us-central-1.wasabisys.com` |
| EU Central 1 (Amsterdam) | `https://s3.eu-central-1.wasabisys.com` |
| EU Central 2 (Frankfurt) | `https://s3.eu-central-2.wasabisys.com` |
| EU West 1 (London) | `https://s3.eu-west-1.wasabisys.com` |
| EU West 2 (Paris) | `https://s3.eu-west-2.wasabisys.com` |
| AP Northeast 1 (Tokyo) | `https://s3.ap-northeast-1.wasabisys.com` |
| AP Northeast 2 (Osaka) | `https://s3.ap-northeast-2.wasabisys.com` |
| AP Southeast 1 (Singapore) | `https://s3.ap-southeast-1.wasabisys.com` |
| AP Southeast 2 (Sydney) | `https://s3.ap-southeast-2.wasabisys.com` |

---

## Common Operations

### Start the Server

```bash
docker compose -f compose.wasabi.yml up -d
```

### Stop the Server

```bash
docker compose -f compose.wasabi.yml down
```

### View Logs

```bash
# Follow logs in real-time
docker compose -f compose.wasabi.yml logs -f

# View last 100 lines
docker compose -f compose.wasabi.yml logs --tail=100
```

### Check Container Status

```bash
docker compose -f compose.wasabi.yml ps
```

### Restart the Server

```bash
docker compose -f compose.wasabi.yml restart
```

---

## Updating Configuration

### Changing S3 Credentials or Bucket

For S3 credential changes, a simple restart is sufficient:

```bash
# 1. Edit your configuration
nano .env.wasabi

# 2. Restart the container
docker compose -f compose.wasabi.yml down
docker compose -f compose.wasabi.yml up -d
```

### Changing External Address (IP Changed)

When your local IP changes, you must regenerate **both** the server config and reset the Anytype client:

```bash
# 1. Stop the container
docker compose -f compose.wasabi.yml down

# 2. Find your new IP
ip addr | grep "inet " | grep -v 127.0.0.1

# 3. Update .env.wasabi with the new IP
nano .env.wasabi
# Change: ANY_SYNC_BUNDLE_INIT_EXTERNAL_ADDRS=<new-ip>

# 4. Delete server data directory (regenerates client-config.yml)
rm -rf ./data

# 5. Clear Anytype client data (required for new network identity)
# Flatpak:
rm -rf ~/.var/app/io.anytype.anytype/
# Native Linux:
rm -rf ~/.config/anytype/
# macOS:
rm -rf ~/Library/Application\ Support/anytype/

# 6. Start the server
docker compose -f compose.wasabi.yml up -d

# 7. Wait for new client-config.yml to be generated
cat ./data/client-config.yml

# 8. Open Anytype, upload new client-config.yml, create NEW identity
```

> **Why both?** The server embeds your IP into `client-config.yml` on first run. The Anytype client caches network identity - it won't accept a new config without clearing its data.

### Full Reset (Clean Slate)

To completely reset both server and client:

```bash
# Stop server
docker compose -f compose.wasabi.yml down -v

# Clear server data
rm -rf ./data

# Clear Anytype client data
rm -rf ~/.var/app/io.anytype.anytype/    # Flatpak
# OR
rm -rf ~/.config/anytype/                 # Native Linux
# OR
rm -rf ~/Library/Application\ Support/anytype/  # macOS

# Start fresh
docker compose -f compose.wasabi.yml up -d
```

> **Note**: S3 data in Wasabi is preserved. Only local metadata is cleared.

---

## Anytype Client Setup

### First-Time Setup

1. **Start the server** and wait for `./data/client-config.yml` to be generated

2. **Clear any existing Anytype data** (important for clean setup):
   ```bash
   # Flatpak
   rm -rf ~/.var/app/io.anytype.anytype/
   # Native Linux
   rm -rf ~/.config/anytype/
   # macOS
   rm -rf ~/Library/Application\ Support/anytype/
   ```

3. **Open Anytype** desktop app

4. **Go to Settings** > Network > Self-hosted network

5. **Upload** `./data/client-config.yml`

6. **Create a NEW identity** (don't try to log in with existing account)

7. **Verify sync** by creating a page and checking Wasabi bucket for new objects

### Important Notes

- **New identity required**: Existing Anytype vaults cannot be migrated to self-hosted networks
- **Always clear client data** when switching networks or after regenerating server config
- **Mobile**: Transfer `client-config.yml` to your device using methods below

### Transferring client-config.yml to Mobile

**Avoid cloud sync services** (Google Drive, Dropbox) - sync delays can cause connection failures with stale config files.

**Recommended methods:**

| Method | Command/Steps |
|--------|---------------|
| Local HTTP server | `cd ./data && python3 -m http.server 8080`<br>Open `http://YOUR_IP:8080/client-config.yml` on mobile |
| ADB (Android) | `adb push ./data/client-config.yml /sdcard/Download/` |
| Email | Send as attachment to yourself |
| Messaging apps | Telegram "Saved Messages", Signal "Note to Self" |
| Direct transfer | KDE Connect, LocalSend, AirDrop (iOS) |

**If using cloud sync:** Force refresh on mobile before importing - pull down to refresh or manually download the file.

### Switching Networks

To switch from official Anytype network to self-hosted (or vice versa):

1. Stop the server (if switching away from self-hosted)
2. Clear Anytype client data completely
3. Open Anytype fresh
4. Upload new network config (or use default)
5. Create new identity

---

## Troubleshooting

### Container Won't Start

```bash
# Check logs for errors
docker compose -f compose.wasabi.yml logs

# Common issues:
# - Port 33010 or 33020 already in use
# - Invalid S3 credentials
# - Network connectivity issues
```

### S3 Connection Failed

1. Verify bucket name matches exactly
2. Check region and endpoint match
3. Confirm access keys are valid
4. Test with AWS CLI:
   ```bash
   aws s3 ls s3://your-bucket --endpoint-url https://s3.us-east-1.wasabisys.com
   ```

### Client Connection Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `SkipVerifyNotAllowed` | Client has old network identity | Clear Anytype data, upload new config, create new identity |
| `space is missing` | Trying to recover vault that doesn't exist on server | Clear Anytype data, create NEW identity (don't use old recovery phrase) |
| `disk I/O error` | Corrupted client database | Clear Anytype data and restart |
| `no access to the space` | Mobile client has mismatched network identity | Clear app data (Android) or reinstall (iOS), create new identity |
| Connection timeout | Wrong IP in config | Regenerate server config with correct IP |
| Connection refused | Server not running | Verify container is running with `docker ps` |

### "space is missing" Error (Desktop)

```
failed to run node can't run service 'client.space': create tech space for old accounts: init tech space: space is missing
```

This happens when entering a recovery phrase for a vault that **doesn't exist on the current server**. Common causes:
- Server `./data/` was deleted (regenerating config)
- Trying to use recovery phrase from official Anytype network
- Server was completely reset

**Solution**: You cannot recover that vault. Clear client data and create a **new identity**:

```bash
# Clear client data
rm -rf ~/.var/app/io.anytype.anytype/   # Flatpak
rm -rf ~/.config/anytype/                # Native Linux
rm -rf ~/Library/Application\ Support/anytype/  # macOS

# Then: reopen Anytype, upload client-config.yml, create NEW identity
```

### "no access to the space" Error (Mobile)

This is the same issue on mobile - the app has cached credentials for a vault that doesn't exist on the server.

**Android:**
1. Settings > Apps > Anytype > Storage > **Clear Data**
2. Reopen Anytype
3. Upload `client-config.yml`
4. Create **new identity**

**iOS:**
1. Delete Anytype app
2. Reinstall from App Store
3. Upload `client-config.yml`
4. Create **new identity**

### Client Won't Connect After IP Change

Both server and client need to be reset:

```bash
# Server side
docker compose -f compose.wasabi.yml down
rm -rf ./data

# Client side
rm -rf ~/.var/app/io.anytype.anytype/   # Flatpak

# Update IP in .env.wasabi, then restart server
docker compose -f compose.wasabi.yml up -d

# Upload new client-config.yml to Anytype, create new identity
```

### Verify Server is Running

```bash
# Check if ports are listening
ss -tlnp | grep 33010
ss -ulnp | grep 33020

# Or netstat
netstat -an | grep 33010
```

---

## Data Directory Structure

```
./data/
├── bundle-config.yml    # Server configuration (auto-generated)
├── client-config.yml    # Client config to share with Anytype app
└── storage/
    ├── network-store/   # Network configuration
    ├── storage-sync/    # Sync node persistence (AnyStore)
    └── storage-file/    # Local file cache (if not using S3)
```

---

## File Reference

| File | Purpose |
|------|---------|
| `compose.wasabi.yml` | Docker Compose configuration for local testing |
| `.env.wasabi.example` | Environment variable template |
| `.env.wasabi` | Your actual configuration (not committed to git) |
| `./data/client-config.yml` | Generated config to share with Anytype client |

---

## Quick Reference

### IP Changed? Run this:

```bash
docker compose -f compose.wasabi.yml down
rm -rf ./data
rm -rf ~/.var/app/io.anytype.anytype/   # Adjust for your install type
# Update IP in .env.wasabi
docker compose -f compose.wasabi.yml up -d
# Then: upload new client-config.yml to Anytype, create new identity
```

---

## Next Steps

After successful local testing:
- Phase 2: Production deployment with Traefik and SSL
- Phase 3: Complete documentation and backup procedures
- Phase 4: AWS EC2 deployment

See `.kiro/specs/personal-server-setup/tasks.md` for the full implementation roadmap.
