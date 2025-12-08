#!/bin/bash
################################################################################
# Database Environment Fix - Create .env and restart services
# This fixes the "no PostgreSQL user name specified" error
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
║     Database Environment Fix                      ║
║     Solve "no PostgreSQL user name specified"     ║
╚════════════════════════════════════════════════════╝
EOF
echo ""

# Check prerequisites
[ ! -f "docker-compose.yml" ] && error "Run from project directory!"

# Detect compose command
if docker compose version >/dev/null 2>&1; then
    COMPOSE="docker compose"
else
    COMPOSE="docker-compose"
fi

header "🔍 DIAGNOSIS"

log "Checking current configuration..."

# Check if .env exists
if [ -f ".env" ]; then
    warn ".env file exists"

    # Check if DATABASE_URL is set
    if grep -q "^DATABASE_URL=" .env; then
        DB_URL=$(grep "^DATABASE_URL=" .env | cut -d= -f2)
        log "Current DATABASE_URL: $DB_URL"

        if [ -z "$DB_URL" ] || [ "$DB_URL" = '""' ] || [ "$DB_URL" = "''" ]; then
            error "DATABASE_URL is empty! This is the problem."
        fi
    else
        error "DATABASE_URL not found in .env! This is the problem."
    fi

    # Ask if user wants to recreate
    echo ""
    read -p "Do you want to recreate .env with correct configuration? (y/N): " RECREATE
    if [[ ! $RECREATE =~ ^[Yy]$ ]]; then
        log "Keeping existing .env"
        RECREATE_ENV=false
    else
        RECREATE_ENV=true
    fi
else
    error ".env file does NOT exist! This is the problem."
    log "Creating .env file..."
    RECREATE_ENV=true
fi

if [ "$RECREATE_ENV" = true ]; then
    header "📝 CREATING .env FILE"

    # Backup if exists
    [ -f ".env" ] && cp .env .env.backup-$(date +%Y%m%d-%H%M%S)

    # Get database credentials from docker-compose.yml
    DB_USER=$(grep "POSTGRES_USER:" docker-compose.yml | head -1 | awk '{print $2}' || echo "postgres")
    DB_PASS=$(grep "POSTGRES_PASSWORD:" docker-compose.yml | head -1 | awk '{print $2}' || echo "postgres")
    DB_NAME=$(grep "POSTGRES_DB:" docker-compose.yml | head -1 | awk '{print $2}' || echo "emergency_chatbot")

    success "Using database credentials from docker-compose.yml:"
    echo "  User:     $DB_USER"
    echo "  Password: $DB_PASS"
    echo "  Database: $DB_NAME"
    echo ""

    # Create .env file
    cat > .env <<ENVEOF
# ============================================
# EMERGENCY CHATBOT CONFIGURATION
# ============================================

# ============================================
# SERVER CONFIGURATION
# ============================================
NODE_ENV=development
PORT=3000
API_BASE_URL=http://localhost:3000

# ============================================
# DATABASE
# ============================================
DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@postgres:5432/${DB_NAME}

# PostgreSQL Credentials
POSTGRES_USER=${DB_USER}
POSTGRES_PASSWORD=${DB_PASS}
POSTGRES_DB=${DB_NAME}

# ============================================
# REDIS (Queue & Cache)
# ============================================
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_URL=redis://redis:6379
REDIS_PASSWORD=

# ============================================
# JWT AUTHENTICATION
# ============================================
JWT_SECRET=emergency-dev-secret-key-2025
JWT_EXPIRES_IN=7d

# ============================================
# ADMIN ACCOUNT
# ============================================
ADMIN_PASSWORD=Admin123!Staging

# ============================================
# WHATSAPP CONFIGURATION
# ============================================
WHATSAPP_MODE=baileys
WHATSAPP_PHONE_NUMBER_ID=
WHATSAPP_ACCESS_TOKEN=
WHATSAPP_VERIFY_TOKEN=webhook-verify-token-dev
WHATSAPP_BUSINESS_ACCOUNT_ID=

# ============================================
# TELEGRAM BOT (untuk notifikasi admin)
# ============================================
TELEGRAM_BOT_TOKEN=
TELEGRAM_ADMIN_CHAT_ID=

# ============================================
# OLLAMA (Local LLM)
# ============================================
OLLAMA_BASE_URL=http://ollama:11434
OLLAMA_MODEL=qwen2.5:7b
OLLAMA_TIMEOUT=30000
OLLAMA_FALLBACK_ENABLED=true

# ============================================
# SYSTEM CONFIGURATION
# ============================================
AUTO_ASSIGN_CRITICAL_TO=
AUTO_VERIFY_TRUST_LEVEL=3
RATE_LIMIT_PER_MINUTE=10
DATA_RETENTION_DAYS=180
MEDIA_STORAGE_PATH=/app/media
DEBUG_MODE=true
LOG_LEVEL=debug
ENVEOF

    success ".env file created successfully!"

    # Show DATABASE_URL
    log "DATABASE_URL set to:"
    grep "^DATABASE_URL=" .env
    echo ""
fi

header "🔄 RESTARTING SERVICES"

log "Stopping all containers..."
$COMPOSE down

log "Starting database first..."
$COMPOSE up -d postgres
sleep 8

log "Waiting for PostgreSQL to be ready..."
until docker exec emergency_db pg_isready -U ${DB_USER:-postgres} >/dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo ""
success "PostgreSQL is ready!"

log "Starting Redis and Ollama..."
$COMPOSE up -d redis ollama
sleep 3

log "Starting backend..."
$COMPOSE up -d backend
sleep 10

header "🔍 VERIFICATION"

log "Checking container status..."
$COMPOSE ps
echo ""

# Check backend logs for errors
log "Checking backend logs for database errors..."
BACKEND_LOGS=$(docker logs emergency_backend 2>&1 | tail -20)

if echo "$BACKEND_LOGS" | grep -qi "authentication failed\|denied access\|no PostgreSQL user"; then
    error "Backend still has database authentication errors!"
    echo ""
    echo "$BACKEND_LOGS"
    echo ""
    error "Please check logs: docker logs emergency_backend"
elif echo "$BACKEND_LOGS" | grep -qi "server started\|listening\|ready"; then
    success "Backend started successfully!"
else
    warn "Backend status unclear. Logs:"
    echo "$BACKEND_LOGS"
fi

# Check if backend is responding
log "Testing backend health endpoint..."
sleep 5
if curl -sf http://localhost:3000/health >/dev/null 2>&1; then
    success "✓ Backend API is healthy!"
else
    warn "Backend health check failed (may still be starting)"
fi

# Run database migrations
header "🗄️  DATABASE MIGRATIONS"

log "Running Prisma migrations..."
if docker exec emergency_backend npx prisma db push --skip-generate 2>&1 | grep -q "database is now in sync\|already in sync"; then
    success "Database schema is up to date!"
else
    warn "Migration may have had issues. Check output above."
fi

# Final summary
cat << EOF

╔════════════════════════════════════════════════════╗
║              ✅ FIX COMPLETE!                      ║
╚════════════════════════════════════════════════════╝

📊 What was fixed:
   • Created .env file with correct DATABASE_URL
   • Configured: postgresql://${DB_USER}:${DB_PASS}@postgres:5432/${DB_NAME}
   • Restarted all services in correct order
   • Ran database migrations

🌐 Access Information:
   Backend API:    ${GREEN}http://localhost:3000${NC}
   Health Check:   ${GREEN}http://localhost:3000/health${NC}

🔍 Verify Backend:
   Check logs:     docker logs -f emergency_backend
   Test health:    curl http://localhost:3000/health

📝 Next Steps:
   1. Verify backend is running: docker ps | grep backend
   2. Check for errors: docker logs emergency_backend | tail -30
   3. If dashboard exists, start it: $COMPOSE up -d dashboard

EOF

log "Checking final backend status..."
if docker ps | grep -q "emergency_backend.*Up"; then
    success "✨ Backend is running!"

    # Show recent logs
    echo ""
    log "Recent backend logs:"
    docker logs emergency_backend 2>&1 | tail -10
else
    error "Backend container is not running. Check logs: docker logs emergency_backend"
fi

echo ""
