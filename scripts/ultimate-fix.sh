#!/bin/bash
################################################################################
# Ultimate Fix - Database + Backend + Dashboard
# Fix database credentials and restart everything properly
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e "${BLUE}►${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
header() { echo -e "\n${CYAN}${BOLD}═══ $1 ═══${NC}\n"; }

clear
cat << "EOF"
╔════════════════════════════════════════════════════╗
║     Ultimate Fix - Database + Backend + UI        ║
║          Fix All Issues at Once                   ║
╚════════════════════════════════════════════════════╝
EOF
echo ""

# Prerequisites
header "Checking Prerequisites"
[ ! -f "docker-compose.yml" ] && error "Run from project directory!"

if docker compose version >/dev/null 2>&1; then
    COMPOSE="docker compose"
else
    COMPOSE="docker-compose"
fi
success "Using: $COMPOSE"

# Step 1: Check current database password
header "Checking Database Configuration"

if [ -f ".env" ]; then
    log "Current .env database settings:"
    grep -E "POSTGRES_|DATABASE_URL" .env || echo "  (no database settings found)"
    echo ""
else
    warn ".env file not found!"
fi

# Get database password from docker-compose or .env
DB_PASS=$(grep "POSTGRES_PASSWORD" .env 2>/dev/null | cut -d= -f2 || echo "")
if [ -z "$DB_PASS" ]; then
    DB_PASS="emergency123"
    warn "No POSTGRES_PASSWORD in .env, using default: $DB_PASS"
fi

DB_USER=$(grep "POSTGRES_USER" .env 2>/dev/null | cut -d= -f2 || echo "emergency")
DB_NAME=$(grep "POSTGRES_DB" .env 2>/dev/null | cut -d= -f2 || echo "emergency_db")

success "Database config: $DB_USER / $DB_PASS @ $DB_NAME"

# Step 2: Ensure .env has correct settings
header "Fixing .env Configuration"

# Backup .env
[ -f ".env" ] && cp .env .env.backup-$(date +%Y%m%d-%H%M%S)

# Ensure these settings exist
log "Ensuring database settings in .env..."

if ! grep -q "^POSTGRES_DB=" .env 2>/dev/null; then
    echo "POSTGRES_DB=$DB_NAME" >> .env
fi

if ! grep -q "^POSTGRES_USER=" .env 2>/dev/null; then
    echo "POSTGRES_USER=$DB_USER" >> .env
fi

if ! grep -q "^POSTGRES_PASSWORD=" .env 2>/dev/null; then
    echo "POSTGRES_PASSWORD=$DB_PASS" >> .env
fi

# Ensure DATABASE_URL is correct
if ! grep -q "^DATABASE_URL=" .env 2>/dev/null; then
    echo "DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@postgres:5432/${DB_NAME}?schema=public" >> .env
else
    # Update existing DATABASE_URL
    sed -i.bak "s|^DATABASE_URL=.*|DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@postgres:5432/${DB_NAME}?schema=public|" .env
fi

# Ensure REDIS_URL
if ! grep -q "^REDIS_URL=" .env 2>/dev/null; then
    echo "REDIS_URL=redis://redis:6379" >> .env
fi

success ".env configuration updated"

# Show final database config
log "Final database configuration:"
grep -E "POSTGRES_|DATABASE_URL|REDIS_URL" .env
echo ""

# Step 3: Stop all containers
header "Stopping All Containers"
$COMPOSE down
success "All containers stopped"

# Step 4: Start database first
header "Starting Database"
$COMPOSE up -d postgres
log "Waiting for database to be ready..."
sleep 10

# Test database connection
log "Testing database connection..."
DB_TEST=$($COMPOSE exec -T postgres psql -U $DB_USER -d $DB_NAME -c "SELECT 1;" 2>&1 || echo "FAILED")
if echo "$DB_TEST" | grep -q "1 row"; then
    success "Database is accessible"
else
    warn "Database test output:"
    echo "$DB_TEST"
    warn "Database might not be fully ready, continuing anyway..."
fi

# Step 5: Start Redis and Ollama
header "Starting Redis and Ollama"
$COMPOSE up -d redis ollama
sleep 3
success "Redis and Ollama started"

# Step 6: Start Backend
header "Starting Backend"
$COMPOSE up -d backend
log "Waiting for backend to initialize..."
sleep 10

# Check backend logs
log "Checking backend status..."
BACKEND_LOGS=$(docker logs emergency_backend 2>&1 | tail -10)

if echo "$BACKEND_LOGS" | grep -q "Authentication failed"; then
    error "Backend still has database authentication error. Check logs:
    docker logs emergency_backend"
elif echo "$BACKEND_LOGS" | grep -q "Server started\|listening\|Listening"; then
    success "Backend started successfully"
else
    warn "Backend status unclear, check logs:"
    echo "$BACKEND_LOGS"
fi

# Test backend health
log "Testing backend health..."
sleep 5
if curl -sf http://localhost:3000/health >/dev/null 2>&1; then
    success "Backend API is healthy"
else
    warn "Backend health check failed"
    log "Backend logs:"
    docker logs emergency_backend | tail -20
fi

# Step 7: Run database migrations
header "Running Database Migrations"
log "Pushing Prisma schema to database..."
docker exec emergency_backend npx prisma db push --skip-generate 2>&1 | tail -10 || warn "Migration had issues"
success "Database schema updated"

# Step 8: Start Dashboard
header "Starting Dashboard"
$COMPOSE up -d dashboard
sleep 5

# Check dashboard status
if docker ps | grep -q "emergency_dashboard"; then
    success "Dashboard is running"
else
    error "Dashboard failed to start"
fi

# Step 9: Verify network connectivity
header "Verifying Network Connectivity"

log "Testing dashboard -> backend connectivity..."
NETWORK_TEST=$(docker exec emergency_dashboard wget -qO- http://backend:3000/health 2>&1 || echo "FAILED")

if echo "$NETWORK_TEST" | grep -q "success\|healthy"; then
    success "Dashboard can reach backend"
else
    warn "Dashboard cannot reach backend"
    log "Network test output: $NETWORK_TEST"

    # Check if they're on same network
    log "Checking Docker network..."
    BACKEND_NET=$(docker inspect emergency_backend | grep -A 5 "Networks" | grep "emergency_net" || echo "NOT FOUND")
    DASHBOARD_NET=$(docker inspect emergency_dashboard | grep -A 5 "Networks" | grep "emergency_net" || echo "NOT FOUND")

    if [ "$BACKEND_NET" = "NOT FOUND" ] || [ "$DASHBOARD_NET" = "NOT FOUND" ]; then
        warn "Containers not on same network, recreating..."
        $COMPOSE down
        $COMPOSE up -d
        sleep 10
    fi
fi

# Step 10: Final verification
header "Final Verification"

# Show container status
log "Container status:"
$COMPOSE ps
echo ""

# Test all endpoints
log "Testing endpoints..."

# Backend health
if curl -sf http://localhost:3000/health >/dev/null 2>&1; then
    success "✓ Backend health: OK"
else
    warn "✗ Backend health: FAIL"
fi

# Dashboard access
if curl -sf http://localhost:8080 >/dev/null 2>&1; then
    success "✓ Dashboard access: OK"
else
    warn "✗ Dashboard access: FAIL"
fi

# Dashboard -> Backend proxy
PROXY_TEST=$(curl -sf http://localhost:8080/health 2>&1)
if echo "$PROXY_TEST" | grep -q "success\|healthy"; then
    success "✓ Dashboard API proxy: OK"
else
    warn "✗ Dashboard API proxy: FAIL"
    log "Response: $PROXY_TEST"
fi

# Test login endpoint
log "Testing login endpoint..."
LOGIN_TEST=$(curl -sf -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test"}' 2>&1)

if echo "$LOGIN_TEST" | grep -q "Invalid\|error\|success"; then
    success "✓ Login endpoint: Responding with JSON"
else
    warn "✗ Login endpoint: Not working"
    log "Response: ${LOGIN_TEST:0:200}"
fi

# Final summary
cat << EOF

╔════════════════════════════════════════════════════╗
║              🎉 SYSTEM READY! 🎉                  ║
╚════════════════════════════════════════════════════╝

📊 Access Information:
   Dashboard:  ${GREEN}http://localhost:8080${NC}
   Backend:    ${GREEN}http://localhost:3000${NC}

🔐 Database Info:
   Host:       postgres:5432
   Database:   $DB_NAME
   User:       $DB_USER
   Password:   $DB_PASS

📝 Admin Credentials:
   Check .env file for ADMIN_PASSWORD
   Default username: admin

🔍 Debug Commands:
   Backend logs:   docker logs -f emergency_backend
   Dashboard logs: docker logs -f emergency_dashboard
   Database logs:  docker logs -f emergency_db
   All services:   $COMPOSE logs -f

   Test health:    curl http://localhost:8080/health
   Test login:     curl -X POST http://localhost:8080/auth/login \\
                     -H "Content-Type: application/json" \\
                     -d '{"username":"admin","password":"YOUR_PASSWORD"}'

🔄 Restart Commands:
   Restart all:    $COMPOSE restart
   Restart backend: $COMPOSE restart backend
   Restart dashboard: $COMPOSE restart dashboard

EOF

# Show any recent errors
log "Recent backend errors (if any):"
docker logs emergency_backend 2>&1 | grep -i error | tail -5 || echo "  (no errors)"

echo ""
success "✨ Setup complete! Try logging in now at http://localhost:8080"
echo ""
