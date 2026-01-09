#!/bin/bash
# Any-Sync Personal Server - Update Script
#
# Updates all containers to their latest versions:
# 1. Creates a backup before updating
# 2. Pulls latest images
# 3. Restarts containers with new images
# 4. Runs health check
#
# Usage:
#   ./scripts/update.sh
#   SKIP_BACKUP=1 ./scripts/update.sh  # Skip backup step

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$ROOT_DIR"

echo "=========================================="
echo "  Any-Sync Update"
echo "=========================================="
echo ""

# 1. Backup (unless skipped)
if [[ "${SKIP_BACKUP:-}" != "1" ]]; then
    echo -e "${YELLOW}[1/4]${NC} Creating backup..."
    "$SCRIPT_DIR/backup.sh"
    echo ""
else
    echo -e "${YELLOW}[1/4]${NC} Skipping backup (SKIP_BACKUP=1)"
    echo ""
fi

# 2. Pull latest images
echo -e "${YELLOW}[2/4]${NC} Pulling latest images..."
docker compose pull
echo -e "  ${GREEN}✓${NC} Images pulled"
echo ""

# 3. Restart containers
echo -e "${YELLOW}[3/4]${NC} Restarting containers..."
docker compose up -d
echo -e "  ${GREEN}✓${NC} Containers restarted"
echo ""

# Wait for services to stabilize
echo "  Waiting for services to stabilize..."
sleep 10

# 4. Health check
echo -e "${YELLOW}[4/4]${NC} Running health check..."
echo ""
"$SCRIPT_DIR/health-check.sh"

echo ""
echo "=========================================="
echo -e "  ${GREEN}Update Complete${NC}"
echo "=========================================="
echo ""
echo "Current image versions:"
docker compose images --format "table {{.Repository}}\t{{.Tag}}" 2>/dev/null || docker compose images
echo ""
