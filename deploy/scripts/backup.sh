#!/bin/bash
# Any-Sync Personal Server - Backup Script
#
# Creates backups of:
# - MongoDB database (mongodump) - coordinator/consensus data, spaces metadata
# - Configuration files (.env, traefik/, bundle config)
#
# Backups are stored in ./backups/ with timestamps (configurable via BACKUP_DIR)
#
# Usage:
#   ./scripts/backup.sh
#   BACKUP_DIR=/custom/path ./scripts/backup.sh
#
# See docs/BACKUP.md for detailed backup and restore procedures

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS="${RETENTION_DAYS:-7}"

cd "$ROOT_DIR"

echo "=========================================="
echo "  Any-Sync Backup"
echo "=========================================="
echo ""
echo "Backup directory: $BACKUP_DIR"
echo "Timestamp: $TIMESTAMP"
echo "Retention: $RETENTION_DAYS days"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Track success/failure
BACKUP_SUCCESS=true

# 1. MongoDB backup
echo -e "${YELLOW}[1/3]${NC} Backing up MongoDB..."
MONGO_BACKUP="$BACKUP_DIR/mongodb_${TIMESTAMP}.gz"

if docker exec mongo mongodump --archive --gzip 2>/dev/null > "$MONGO_BACKUP"; then
    SIZE=$(du -h "$MONGO_BACKUP" | cut -f1)
    echo -e "  ${GREEN}✓${NC} MongoDB backup: $MONGO_BACKUP ($SIZE)"
else
    echo -e "  ${RED}✗${NC} MongoDB backup failed"
    rm -f "$MONGO_BACKUP"
    BACKUP_SUCCESS=false
fi

# 2. Configuration backup
echo ""
echo -e "${YELLOW}[2/3]${NC} Backing up configuration..."
CONFIG_BACKUP="$BACKUP_DIR/configs_${TIMESTAMP}.tar.gz"

# Build list of files to backup
FILES_TO_BACKUP=()
[[ -f "$ROOT_DIR/.env" ]] && FILES_TO_BACKUP+=(".env")
[[ -d "$ROOT_DIR/traefik" ]] && FILES_TO_BACKUP+=("traefik/")
[[ -f "$ROOT_DIR/data/bundle/bundle-config.yml" ]] && FILES_TO_BACKUP+=("data/bundle/bundle-config.yml")
[[ -f "$ROOT_DIR/data/bundle/client-config.yml" ]] && FILES_TO_BACKUP+=("data/bundle/client-config.yml")

if [[ ${#FILES_TO_BACKUP[@]} -gt 0 ]]; then
    if tar -czf "$CONFIG_BACKUP" -C "$ROOT_DIR" "${FILES_TO_BACKUP[@]}" 2>/dev/null; then
        SIZE=$(du -h "$CONFIG_BACKUP" | cut -f1)
        echo -e "  ${GREEN}✓${NC} Config backup: $CONFIG_BACKUP ($SIZE)"
        echo "  Includes: ${FILES_TO_BACKUP[*]}"
    else
        echo -e "  ${RED}✗${NC} Config backup failed"
        BACKUP_SUCCESS=false
    fi
else
    echo -e "  ${YELLOW}!${NC} No configuration files found to backup"
fi

# 3. Storage information
echo ""
echo -e "${YELLOW}[3/3]${NC} Storage information..."

# Check if using S3 or local storage
if [[ -f "$ROOT_DIR/.env" ]]; then
    source "$ROOT_DIR/.env"
    if [[ -n "${S3_BUCKET:-}" ]]; then
        echo -e "  ${GREEN}✓${NC} File storage: Wasabi S3 (bucket: $S3_BUCKET)"
        echo "  Note: S3 data is stored in cloud, not included in local backup"
        echo "  Wasabi provides 11x9s durability - no local backup needed"
    fi
fi

if [[ -d "$ROOT_DIR/data/bundle/storage" ]]; then
    STORAGE_SIZE=$(du -sh "$ROOT_DIR/data/bundle/storage" 2>/dev/null | cut -f1 || echo "unknown")
    echo -e "  ${YELLOW}!${NC} Local bundle storage: $STORAGE_SIZE"
    echo "  To backup local storage (optional):"
    echo "    tar -czf $BACKUP_DIR/storage_${TIMESTAMP}.tar.gz -C data/bundle storage/"
fi

# Summary
echo ""
echo "=========================================="
if $BACKUP_SUCCESS; then
    echo -e "  ${GREEN}Backup Complete${NC}"
else
    echo -e "  ${YELLOW}Backup Completed with Warnings${NC}"
fi
echo "=========================================="
echo ""
echo "Backup files created:"
ls -lh "$BACKUP_DIR"/*_${TIMESTAMP}* 2>/dev/null || echo "  (none)"
echo ""

# Quick restore reference
echo "Quick Restore Commands:"
echo "  MongoDB:  docker exec -i mongo mongorestore --archive --gzip < $MONGO_BACKUP"
echo "  Configs:  tar -xzf $CONFIG_BACKUP -C $ROOT_DIR"
echo ""
echo "See docs/BACKUP.md for detailed restore procedures"
echo ""

# Cleanup old backups
echo "Cleaning up backups older than $RETENTION_DAYS days..."
DELETED_COUNT=0
while IFS= read -r -d '' file; do
    rm -f "$file"
    ((DELETED_COUNT++))
done < <(find "$BACKUP_DIR" -name "mongodb_*.gz" -mtime +$RETENTION_DAYS -print0 2>/dev/null)
while IFS= read -r -d '' file; do
    rm -f "$file"
    ((DELETED_COUNT++))
done < <(find "$BACKUP_DIR" -name "configs_*.tar.gz" -mtime +$RETENTION_DAYS -print0 2>/dev/null)

if [[ $DELETED_COUNT -gt 0 ]]; then
    echo "  Deleted $DELETED_COUNT old backup file(s)"
else
    echo "  No old backups to clean up"
fi

echo ""
echo "Done."

# Exit with error if backup failed
$BACKUP_SUCCESS || exit 1
