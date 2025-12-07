#!/bin/bash
################################################################################
# Emergency Response System - Monitoring Script
# Monitors health and status of all services
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="$HOME/chatbot-disaster-response"

# Functions
print_header() {
    echo -e "${CYAN}======================================================"
    echo -e "  $1"
    echo -e "======================================================${NC}"
}

check_service() {
    local service=$1
    local port=$2
    local name=$3

    if nc -z localhost $port 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $name (port $port) - ${GREEN}Running${NC}"
        return 0
    else
        echo -e "${RED}✗${NC} $name (port $port) - ${RED}Not Running${NC}"
        return 1
    fi
}

check_url() {
    local url=$1
    local name=$2

    if curl -sf "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $name - ${GREEN}Responding${NC}"
        return 0
    else
        echo -e "${RED}✗${NC} $name - ${RED}Not Responding${NC}"
        return 1
    fi
}

get_container_status() {
    local container=$1

    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        local uptime=$(docker ps --filter "name=${container}" --format '{{.Status}}')
        echo -e "${GREEN}✓${NC} Running - $uptime"
    elif docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        echo -e "${RED}✗${NC} Stopped"
    else
        echo -e "${YELLOW}?${NC} Not Found"
    fi
}

# Clear screen
clear

print_header "Emergency Response System - Status Monitor"
echo ""
echo "Monitoring time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Check if installation exists
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${RED}Installation directory not found: $INSTALL_DIR${NC}"
    exit 1
fi

cd "$INSTALL_DIR"

# Check Docker
print_header "Docker Services"
echo ""

if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker installed"

    # Use docker compose or docker-compose
    if command -v docker compose &> /dev/null && docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi

    echo ""
    echo "Container Status:"
    echo "  Backend:    $(get_container_status 'emergency_backend')"
    echo "  PostgreSQL: $(get_container_status 'emergency_db')"
    echo "  Redis:      $(get_container_status 'emergency_redis')"
    echo "  Ollama:     $(get_container_status 'emergency_ollama')"
    echo "  Dashboard:  $(get_container_status 'emergency_dashboard')"
else
    echo -e "${RED}✗${NC} Docker not installed"
fi

echo ""

# Check Network Ports
print_header "Network Services"
echo ""

check_service "backend" 3000 "Backend API"
check_service "postgres" 5432 "PostgreSQL"
check_service "redis" 6379 "Redis"
check_service "ollama" 11434 "Ollama"
check_service "dashboard" 8080 "Dashboard (Docker)" || check_service "nginx" 80 "Dashboard (Nginx)"

echo ""

# Check API Endpoints
print_header "API Health Checks"
echo ""

if check_url "http://localhost:3000/health" "Backend Health Endpoint"; then
    # Get detailed health info
    HEALTH_DATA=$(curl -s http://localhost:3000/health 2>/dev/null)

    if [ ! -z "$HEALTH_DATA" ]; then
        echo ""
        echo "Service Health Details:"

        # Parse JSON using grep and sed (works without jq)
        OLLAMA_STATUS=$(echo "$HEALTH_DATA" | grep -o '"ollama":{[^}]*"status":"[^"]*"' | sed 's/.*"status":"\([^"]*\)".*/\1/')
        WHATSAPP_STATUS=$(echo "$HEALTH_DATA" | grep -o '"whatsapp":{[^}]*"status":"[^"]*"' | sed 's/.*"status":"\([^"]*\)".*/\1/')
        DB_STATUS=$(echo "$HEALTH_DATA" | grep -o '"database":{[^}]*"status":"[^"]*"' | sed 's/.*"status":"\([^"]*\)".*/\1/')

        [ "$OLLAMA_STATUS" = "healthy" ] && echo -e "  Ollama:    ${GREEN}✓ $OLLAMA_STATUS${NC}" || echo -e "  Ollama:    ${YELLOW}⚠ $OLLAMA_STATUS${NC}"
        [ "$WHATSAPP_STATUS" = "healthy" ] && echo -e "  WhatsApp:  ${GREEN}✓ $WHATSAPP_STATUS${NC}" || echo -e "  WhatsApp:  ${YELLOW}⚠ $WHATSAPP_STATUS${NC}"
        [ "$DB_STATUS" = "healthy" ] && echo -e "  Database:  ${GREEN}✓ $DB_STATUS${NC}" || echo -e "  Database:  ${YELLOW}⚠ $DB_STATUS${NC}"
    fi
fi

echo ""

# Check Ollama Models
if nc -z localhost 11434 2>/dev/null; then
    MODELS=$(curl -s http://localhost:11434/api/tags 2>/dev/null | grep -o '"name":"[^"]*"' | sed 's/"name":"\([^"]*\)"/\1/' | head -5)

    if [ ! -z "$MODELS" ]; then
        echo "Ollama Models:"
        echo "$MODELS" | while read -r model; do
            echo -e "  ${GREEN}✓${NC} $model"
        done
    else
        echo -e "${YELLOW}⚠${NC} No Ollama models found"
        echo "  Run: docker exec emergency_ollama ollama pull qwen2.5:1.5b"
    fi

    echo ""
fi

# Resource Usage
print_header "Resource Usage"
echo ""

if command -v docker &> /dev/null; then
    echo "Container Resource Usage:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" 2>/dev/null | grep emergency || echo "No containers running"
fi

echo ""

# Recent Logs (if any errors)
print_header "Recent Errors (Last 5 minutes)"
echo ""

if command -v docker &> /dev/null && docker ps | grep -q emergency_backend; then
    ERROR_LOGS=$(docker logs --since 5m emergency_backend 2>&1 | grep -i "error" | tail -5)

    if [ ! -z "$ERROR_LOGS" ]; then
        echo -e "${RED}Recent errors found:${NC}"
        echo "$ERROR_LOGS"
    else
        echo -e "${GREEN}✓${NC} No recent errors in backend logs"
    fi
fi

echo ""

# Database Stats
if docker ps | grep -q emergency_db; then
    print_header "Database Statistics"
    echo ""

    # Try to get database stats
    DB_STATS=$(docker exec emergency_backend node -e "
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const [users, reports] = await Promise.all([
      prisma.user.count(),
      prisma.report.count(),
    ]);

    const critical = await prisma.report.count({
      where: { urgency: 'CRITICAL', status: { not: 'RESOLVED' } },
    });

    const pending = await prisma.report.count({
      where: { status: 'PENDING_VERIFICATION' },
    });

    console.log('Users:', users);
    console.log('Reports:', reports);
    console.log('Critical:', critical);
    console.log('Pending:', pending);
  } catch (error) {
    console.log('Error:', error.message);
  }
}

main().catch(console.error).finally(() => prisma.\$disconnect());
" 2>/dev/null)

    if [ ! -z "$DB_STATS" ]; then
        echo "$DB_STATS" | while IFS=: read -r key value; do
            echo -e "  $key: ${CYAN}$value${NC}"
        done
    else
        echo -e "${YELLOW}⚠${NC} Could not retrieve database stats"
    fi

    echo ""
fi

# Disk Usage
print_header "Disk Usage"
echo ""

if [ -d "$INSTALL_DIR" ]; then
    DISK_USAGE=$(du -sh "$INSTALL_DIR" 2>/dev/null | awk '{print $1}')
    echo -e "Installation Size: ${CYAN}$DISK_USAGE${NC}"
fi

# Docker volumes
if command -v docker &> /dev/null; then
    echo ""
    echo "Docker Volumes:"
    docker volume ls | grep emergency | awk '{printf "  %-30s %s\n", $2, $1}' || echo "  No volumes found"
fi

echo ""

# Quick Actions
print_header "Quick Actions"
echo ""
echo "View logs:        ./scripts/restart-services.sh (option 9)"
echo "Restart service:  ./scripts/restart-services.sh"
echo "Update dashboard: ./scripts/update-dashboard.sh"
echo "Setup admin:      ./scripts/setup-admin.sh"
echo ""
echo "To monitor continuously, run: watch -n 5 ./scripts/monitor.sh"
echo ""
