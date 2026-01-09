#!/bin/bash
# Any-Sync Personal Server - Health Check Script
#
# Checks the status of all services:
# - Container status
# - MongoDB connectivity and replica set status
# - Redis connectivity
# - Port availability (33010 TCP, 33020 UDP)
# - SSL certificate status (if domain configured)
#
# Usage:
#   ./scripts/health-check.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$ROOT_DIR"

# Load domain from .env if exists
if [[ -f "$ROOT_DIR/.env" ]]; then
    set -a
    source "$ROOT_DIR/.env"
    set +a
fi

echo "=========================================="
echo "  Any-Sync Health Check"
echo "=========================================="
echo ""

# Container Status
echo -e "${YELLOW}[Containers]${NC}"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || docker compose ps
echo ""

# MongoDB
echo -e "${YELLOW}[MongoDB]${NC}"
if docker exec mongo mongosh --quiet --eval "db.adminCommand('ping')" 2>/dev/null | grep -q "ok"; then
    echo -e "  ${GREEN}✓${NC} Ping: OK"
else
    echo -e "  ${RED}✗${NC} Ping: FAILED"
fi

RS_STATUS=$(docker exec mongo mongosh --quiet --eval "rs.status().ok" 2>/dev/null || echo "0")
if [[ "$RS_STATUS" == "1" ]]; then
    echo -e "  ${GREEN}✓${NC} Replica Set: OK"
else
    echo -e "  ${RED}✗${NC} Replica Set: NOT INITIALIZED"
    echo "    Try: docker exec mongo mongosh --eval \"rs.initiate()\""
fi
echo ""

# Redis
echo -e "${YELLOW}[Redis]${NC}"
if docker exec redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
    echo -e "  ${GREEN}✓${NC} Ping: OK"
else
    echo -e "  ${RED}✗${NC} Ping: FAILED"
fi
echo ""

# Ports
echo -e "${YELLOW}[Ports]${NC}"
if nc -z localhost 33010 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} 33010/TCP: OPEN"
else
    echo -e "  ${RED}✗${NC} 33010/TCP: CLOSED"
fi

# Note: UDP port check is less reliable
if command -v nc &>/dev/null && nc -zu localhost 33020 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} 33020/UDP: OPEN (may be false positive)"
else
    echo -e "  ${YELLOW}?${NC} 33020/UDP: Cannot verify (UDP check unreliable)"
fi
echo ""

# SSL Certificate (if domain configured)
if [[ -n "${DOMAIN:-}" ]]; then
    echo -e "${YELLOW}[SSL Certificate]${NC}"
    SSL_RESULT=$(curl -sI "https://${DOMAIN}" 2>/dev/null | head -1 || echo "")
    if [[ "$SSL_RESULT" == *"200"* ]] || [[ "$SSL_RESULT" == *"404"* ]]; then
        echo -e "  ${GREEN}✓${NC} HTTPS: Working"

        # Check certificate expiry
        EXPIRY=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2 || echo "")
        if [[ -n "$EXPIRY" ]]; then
            echo -e "  ${GREEN}✓${NC} Certificate expires: $EXPIRY"
        fi
    elif [[ -z "$SSL_RESULT" ]]; then
        echo -e "  ${YELLOW}?${NC} HTTPS: Cannot connect (cert may still be provisioning)"
    else
        echo -e "  ${RED}✗${NC} HTTPS: $SSL_RESULT"
    fi
    echo ""
fi

# Client Config
echo -e "${YELLOW}[Client Config]${NC}"
if [[ -f "$ROOT_DIR/data/bundle/client-config.yml" ]]; then
    echo -e "  ${GREEN}✓${NC} client-config.yml exists"
    echo "  Path: $ROOT_DIR/data/bundle/client-config.yml"
else
    echo -e "  ${RED}✗${NC} client-config.yml not found"
    echo "  Service may still be initializing"
fi
echo ""

# S3 Storage Info
if [[ -n "${S3_BUCKET:-}" ]]; then
    echo -e "${YELLOW}[S3 Storage]${NC}"
    echo "  Bucket: ${S3_BUCKET}"
    echo "  Endpoint: ${S3_ENDPOINT:-not set}"
    echo ""
fi

# Final summary
echo "=========================================="
UNHEALTHY=$(docker compose ps --status exited --status restarting -q 2>/dev/null | wc -l || echo "0")
if [[ "$UNHEALTHY" -gt 0 ]]; then
    echo -e "  ${RED}Some services are unhealthy${NC}"
    echo "  Run: docker compose logs <service> to investigate"
else
    echo -e "  ${GREEN}All services appear healthy${NC}"
fi
echo "=========================================="
