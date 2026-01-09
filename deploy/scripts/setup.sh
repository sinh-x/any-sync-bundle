#!/bin/bash
# Any-Sync Personal Server - Initial Setup Script
#
# This script:
# 1. Checks prerequisites (Docker, Docker Compose)
# 2. Validates .env configuration
# 3. Creates required directories
# 4. Initializes Traefik certificate storage
# 5. Starts all containers
# 6. Waits for services to be healthy
#
# Usage:
#   ./scripts/setup.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "  Any-Sync Personal Server Setup"
echo "=========================================="
echo ""

# 1. Check prerequisites
echo -e "${YELLOW}[1/6]${NC} Checking prerequisites..."

if ! command -v docker &>/dev/null; then
    echo -e "  ${RED}ERROR:${NC} Docker not installed"
    echo "  Install Docker: https://docs.docker.com/engine/install/"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} Docker found: $(docker --version | head -1)"

if ! docker compose version &>/dev/null; then
    echo -e "  ${RED}ERROR:${NC} Docker Compose v2 not installed"
    echo "  Docker Compose should be included with Docker Desktop or Docker Engine"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} Docker Compose found: $(docker compose version --short)"

# 2. Check .env configuration
echo ""
echo -e "${YELLOW}[2/6]${NC} Checking configuration..."

if [[ ! -f "$ROOT_DIR/.env" ]]; then
    echo -e "  ${RED}ERROR:${NC} .env file not found"
    echo "  Copy .env.example to .env and fill in your values:"
    echo "    cp .env.example .env"
    echo "    nano .env"
    exit 1
fi

# Load and validate required variables
set -a
source "$ROOT_DIR/.env"
set +a

REQUIRED_VARS=(DOMAIN ACME_EMAIL S3_ENDPOINT S3_REGION S3_BUCKET S3_ACCESS_KEY S3_SECRET_KEY)
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        echo -e "  ${RED}ERROR:${NC} $var not set in .env"
        exit 1
    fi
done
echo -e "  ${GREEN}✓${NC} All required variables configured"
echo -e "  ${GREEN}✓${NC} Domain: $DOMAIN"
echo -e "  ${GREEN}✓${NC} S3 Bucket: $S3_BUCKET"

# 3. Create directories
echo ""
echo -e "${YELLOW}[3/6]${NC} Creating directories..."

mkdir -p "$ROOT_DIR/data"/{mongodb,redis,bundle}
mkdir -p "$ROOT_DIR/traefik"
echo -e "  ${GREEN}✓${NC} Data directories created"

# 4. Initialize Traefik certificate storage
echo ""
echo -e "${YELLOW}[4/6]${NC} Initializing Traefik..."

ACME_FILE="$ROOT_DIR/traefik/acme.json"
if [[ ! -f "$ACME_FILE" ]]; then
    touch "$ACME_FILE"
    chmod 600 "$ACME_FILE"
    echo -e "  ${GREEN}✓${NC} Created acme.json with secure permissions"
else
    chmod 600 "$ACME_FILE"
    echo -e "  ${GREEN}✓${NC} acme.json exists (permissions verified)"
fi

# 5. Start containers
echo ""
echo -e "${YELLOW}[5/6]${NC} Starting containers..."

cd "$ROOT_DIR"
docker compose pull
docker compose up -d
echo -e "  ${GREEN}✓${NC} Containers started"

# 6. Wait for services to be healthy
echo ""
echo -e "${YELLOW}[6/6]${NC} Waiting for services to be healthy..."

echo "  Waiting for MongoDB..."
TIMEOUT=60
ELAPSED=0
while ! docker exec mongo mongosh --quiet --eval "rs.status().ok" 2>/dev/null | grep -q "1"; do
    if [[ $ELAPSED -ge $TIMEOUT ]]; then
        echo -e "  ${YELLOW}WARNING:${NC} MongoDB timeout - may still be initializing"
        break
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done
if [[ $ELAPSED -lt $TIMEOUT ]]; then
    echo -e "  ${GREEN}✓${NC} MongoDB healthy (replica set initialized)"
fi

echo "  Waiting for Redis..."
ELAPSED=0
while ! docker exec redis redis-cli ping 2>/dev/null | grep -q "PONG"; do
    if [[ $ELAPSED -ge $TIMEOUT ]]; then
        echo -e "  ${YELLOW}WARNING:${NC} Redis timeout - may still be initializing"
        break
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done
if [[ $ELAPSED -lt $TIMEOUT ]]; then
    echo -e "  ${GREEN}✓${NC} Redis healthy"
fi

echo "  Waiting for any-sync-bundle..."
sleep 10  # Give it time to generate config

# Summary
echo ""
echo "=========================================="
echo -e "  ${GREEN}Setup Complete${NC}"
echo "=========================================="
echo ""
docker compose ps
echo ""

if [[ -f "$ROOT_DIR/data/bundle/client-config.yml" ]]; then
    echo -e "${GREEN}Client config generated:${NC}"
    echo "  $ROOT_DIR/data/bundle/client-config.yml"
    echo ""
    echo "Copy this file to your Anytype client to connect."
else
    echo -e "${YELLOW}Waiting for client-config.yml to be generated...${NC}"
    echo "Check in a few moments: $ROOT_DIR/data/bundle/client-config.yml"
fi

echo ""
echo "Next steps:"
echo "  1. Wait 1-2 minutes for Let's Encrypt SSL certificate"
echo "  2. Test connection: nc -zv $DOMAIN 33010"
echo "  3. Check health: ./scripts/health-check.sh"
echo ""
