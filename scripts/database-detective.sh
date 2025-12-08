#!/bin/bash
################################################################################
# Database Configuration Detective
# Investigate and fix database setup issues
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e "${BLUE}🔍${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
header() { echo -e "\n${CYAN}${BOLD}═══ $1 ═══${NC}\n"; }
info() { echo -e "${CYAN}ℹ${NC} $1"; }

clear
cat << "EOF"
╔════════════════════════════════════════════════════╗
║        Database Configuration Detective           ║
║      Investigate & Auto-Fix Database Issues       ║
╚════════════════════════════════════════════════════╝
EOF
echo ""

# Check prerequisites
[ ! -f "docker-compose.yml" ] && error "Run from project directory!" && exit 1
[ ! -d "backend" ] && error "backend directory not found!" && exit 1

# Detect compose command
if docker compose version >/dev/null 2>&1; then
    COMPOSE="docker compose"
else
    COMPOSE="docker-compose"
fi

# Investigation Phase
header "🔍 PHASE 1: INVESTIGATION"

# 1. Check Prisma Schema
log "Checking Prisma schema configuration..."
if [ -f "backend/prisma/schema.prisma" ]; then
    success "Found Prisma schema"

    echo ""
    info "Current datasource configuration:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    grep -A 3 "datasource db" backend/prisma/schema.prisma | head -4
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Detect database provider
    if grep -q 'provider.*=.*"postgresql"' backend/prisma/schema.prisma; then
        SCHEMA_DB="postgresql"
        success "Prisma schema is configured for: ${CYAN}PostgreSQL${NC}"
    elif grep -q 'provider.*=.*"sqlite"' backend/prisma/schema.prisma; then
        SCHEMA_DB="sqlite"
        success "Prisma schema is configured for: ${CYAN}SQLite${NC}"
    else
        warn "Cannot detect database provider from schema"
        SCHEMA_DB="unknown"
    fi
else
    error "Prisma schema not found at backend/prisma/schema.prisma"
    exit 1
fi

# 2. Check .env file
log "Checking .env configuration..."
if [ -f ".env" ]; then
    success "Found .env file"
    echo ""
    info "Current DATABASE_URL configuration:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if grep -q "^DATABASE_URL=" .env; then
        DB_URL=$(grep "^DATABASE_URL=" .env | cut -d= -f2-)
        echo "$DB_URL"

        # Detect from DATABASE_URL
        if [[ "$DB_URL" == postgresql://* ]]; then
            ENV_DB="postgresql"
            success ".env is configured for: ${CYAN}PostgreSQL${NC}"
        elif [[ "$DB_URL" == file:* ]] || [[ "$DB_URL" == *.db* ]]; then
            ENV_DB="sqlite"
            success ".env is configured for: ${CYAN}SQLite${NC}"
        else
            warn ".env DATABASE_URL format unclear"
            ENV_DB="unknown"
        fi
    else
        error "DATABASE_URL not found in .env!"
        ENV_DB="missing"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
else
    warn ".env file not found!"
    ENV_DB="missing"
fi

# 3. Check docker-compose.yml
log "Checking docker-compose.yml services..."
if grep -q "postgres:" docker-compose.yml; then
    success "PostgreSQL service defined in docker-compose.yml"
    COMPOSE_HAS_POSTGRES=true
else
    info "No PostgreSQL service in docker-compose.yml"
    COMPOSE_HAS_POSTGRES=false
fi

# 4. Check NODE_ENV
log "Checking environment..."
if [ -f ".env" ]; then
    NODE_ENV=$(grep "^NODE_ENV=" .env | cut -d= -f2 || echo "not set")
    info "NODE_ENV: ${CYAN}$NODE_ENV${NC}"
else
    NODE_ENV="not set"
fi

# 5. Check backend logs for actual error
log "Checking backend error logs..."
if docker ps -a | grep -q "emergency_backend"; then
    BACKEND_ERROR=$(docker logs emergency_backend 2>&1 | grep -i "error\|denied\|fatal" | tail -3)
    if [ ! -z "$BACKEND_ERROR" ]; then
        warn "Recent backend errors:"
        echo "$BACKEND_ERROR"
    fi
fi

# Analysis Phase
header "📊 PHASE 2: ANALYSIS"

echo ""
info "Configuration Summary:"
echo "  Prisma Schema:     ${CYAN}$SCHEMA_DB${NC}"
echo "  .env DATABASE_URL: ${CYAN}$ENV_DB${NC}"
echo "  PostgreSQL in compose: $([ "$COMPOSE_HAS_POSTGRES" = true ] && echo "${GREEN}Yes${NC}" || echo "${YELLOW}No${NC}")"
echo "  NODE_ENV:          ${CYAN}$NODE_ENV${NC}"
echo ""

# Determine what to do
NEEDS_FIX=false
FIX_ACTION=""

if [ "$SCHEMA_DB" != "$ENV_DB" ] && [ "$ENV_DB" != "missing" ]; then
    error "❌ MISMATCH DETECTED!"
    echo "   Prisma schema expects: $SCHEMA_DB"
    echo "   .env is configured for: $ENV_DB"
    NEEDS_FIX=true

    # Ask user what they want
    echo ""
    warn "What would you like to use for development?"
    echo "  1) SQLite (recommended for development - no PostgreSQL needed)"
    echo "  2) PostgreSQL (production-like setup)"
    echo ""
    read -p "Enter choice [1-2]: " DB_CHOICE

    if [ "$DB_CHOICE" = "1" ]; then
        FIX_ACTION="switch_to_sqlite"
    elif [ "$DB_CHOICE" = "2" ]; then
        FIX_ACTION="fix_postgresql"
    else
        error "Invalid choice"
        exit 1
    fi

elif [ "$ENV_DB" = "missing" ]; then
    error "❌ DATABASE_URL NOT CONFIGURED!"
    NEEDS_FIX=true

    echo ""
    warn "Which database would you like to use?"
    echo "  1) SQLite (recommended for development)"
    echo "  2) PostgreSQL (production-like)"
    echo ""
    read -p "Enter choice [1-2]: " DB_CHOICE

    if [ "$DB_CHOICE" = "1" ]; then
        FIX_ACTION="setup_sqlite"
    else
        FIX_ACTION="setup_postgresql"
    fi

elif [ "$SCHEMA_DB" = "postgresql" ] && [ "$ENV_DB" = "postgresql" ]; then
    info "✓ Both configured for PostgreSQL"

    # Check if DATABASE_URL is valid
    if [[ ! "$DB_URL" =~ postgresql://.*:.*@.*:.*/.*  ]]; then
        error "❌ DATABASE_URL format is invalid!"
        echo "   Current: $DB_URL"
        echo "   Expected format: postgresql://user:password@host:port/database"
        NEEDS_FIX=true
        FIX_ACTION="fix_postgresql"
    fi

elif [ "$SCHEMA_DB" = "sqlite" ] && [ "$ENV_DB" = "sqlite" ]; then
    success "✓ Both configured for SQLite - looks good!"
fi

# Fix Phase
if [ "$NEEDS_FIX" = true ]; then
    header "🔧 PHASE 3: AUTOMATIC FIX"

    # Backup
    log "Creating backups..."
    [ -f ".env" ] && cp .env .env.backup-$(date +%Y%m%d-%H%M%S)
    [ -f "backend/prisma/schema.prisma" ] && cp backend/prisma/schema.prisma backend/prisma/schema.prisma.backup
    success "Backups created"

    case $FIX_ACTION in
        switch_to_sqlite|setup_sqlite)
            header "Switching to SQLite Configuration"

            # 1. Update Prisma schema
            log "Updating Prisma schema to use SQLite..."
            sed -i 's/provider.*=.*"postgresql"/provider = "sqlite"/' backend/prisma/schema.prisma
            sed -i 's|url.*=.*env("DATABASE_URL")|url = env("DATABASE_URL")|' backend/prisma/schema.prisma
            success "Prisma schema updated"

            # 2. Update .env
            log "Updating .env with SQLite DATABASE_URL..."
            if grep -q "^DATABASE_URL=" .env; then
                sed -i 's|^DATABASE_URL=.*|DATABASE_URL="file:./dev.db"|' .env
            else
                echo 'DATABASE_URL="file:./dev.db"' >> .env
            fi
            success ".env updated"

            # 3. Remove PostgreSQL from docker-compose if exists
            if [ "$COMPOSE_HAS_POSTGRES" = true ]; then
                warn "PostgreSQL service still in docker-compose.yml"
                info "You can remove it manually if not needed"
            fi

            # 4. Update DATABASE_URL in backend if container exists
            log "Regenerating Prisma client..."
            if [ -d "backend/node_modules" ]; then
                cd backend
                npx prisma generate || warn "Failed to generate Prisma client"
                cd ..
            fi

            success "✓ SQLite configuration complete!"
            info "Database file will be created at: backend/dev.db"
            ;;

        fix_postgresql|setup_postgresql)
            header "Fixing PostgreSQL Configuration"

            # Get credentials
            DB_USER=$(grep "POSTGRES_USER=" .env 2>/dev/null | cut -d= -f2 || echo "emergency")
            DB_PASS=$(grep "POSTGRES_PASSWORD=" .env 2>/dev/null | cut -d= -f2 || echo "emergency123")
            DB_NAME=$(grep "POSTGRES_DB=" .env 2>/dev/null | cut -d= -f2 || echo "emergency_db")

            echo ""
            info "Current PostgreSQL settings:"
            echo "  User:     $DB_USER"
            echo "  Password: $DB_PASS"
            echo "  Database: $DB_NAME"
            echo ""
            read -p "Keep these settings? (Y/n): " KEEP_SETTINGS

            if [[ $KEEP_SETTINGS =~ ^[Nn]$ ]]; then
                read -p "Enter database user [$DB_USER]: " NEW_USER
                read -sp "Enter database password: " NEW_PASS
                echo ""
                read -p "Enter database name [$DB_NAME]: " NEW_NAME

                DB_USER=${NEW_USER:-$DB_USER}
                DB_PASS=${NEW_PASS:-$DB_PASS}
                DB_NAME=${NEW_NAME:-$DB_NAME}
            fi

            # Update .env
            log "Updating .env with correct PostgreSQL settings..."

            # Remove old DATABASE_URL
            sed -i '/^DATABASE_URL=/d' .env
            sed -i '/^POSTGRES_/d' .env

            # Add new settings
            cat >> .env <<ENVEOF

# PostgreSQL Configuration
POSTGRES_USER=$DB_USER
POSTGRES_PASSWORD=$DB_PASS
POSTGRES_DB=$DB_NAME
DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@postgres:5432/${DB_NAME}?schema=public
ENVEOF

            success ".env updated with PostgreSQL configuration"

            # Update Prisma schema
            log "Ensuring Prisma schema uses PostgreSQL..."
            sed -i 's/provider.*=.*"sqlite"/provider = "postgresql"/' backend/prisma/schema.prisma
            success "Prisma schema updated"

            ;;
    esac

    # Restart services
    header "🔄 PHASE 4: RESTART SERVICES"

    log "Stopping all containers..."
    $COMPOSE down

    log "Starting services..."
    if [ "$FIX_ACTION" = "switch_to_sqlite" ] || [ "$FIX_ACTION" = "setup_sqlite" ]; then
        # For SQLite, we don't need PostgreSQL
        $COMPOSE up -d backend redis ollama dashboard
    else
        # For PostgreSQL, start database first
        $COMPOSE up -d postgres
        sleep 5
        $COMPOSE up -d backend redis ollama dashboard
    fi

    log "Waiting for services to be ready..."
    sleep 10

    # Run migrations
    log "Running database migrations..."
    docker exec emergency_backend npx prisma db push --skip-generate || warn "Migration had issues"

    success "✓ Services restarted"

else
    success "✓ No fixes needed - configuration looks correct"
fi

# Final verification
header "✅ PHASE 5: VERIFICATION"

log "Checking service status..."
$COMPOSE ps
echo ""

log "Testing backend..."
sleep 5
if curl -sf http://localhost:3000/health >/dev/null 2>&1; then
    success "✓ Backend is responding!"
else
    warn "⚠ Backend not responding yet"
    info "Check logs: docker logs emergency_backend"
fi

log "Testing dashboard..."
if curl -sf http://localhost:8080 >/dev/null 2>&1; then
    success "✓ Dashboard is accessible!"
else
    warn "⚠ Dashboard not responding yet"
fi

# Show final configuration
echo ""
header "📋 FINAL CONFIGURATION"
echo ""
info "Database Configuration:"
grep -A 3 "datasource db" backend/prisma/schema.prisma | head -4
echo ""
info "DATABASE_URL from .env:"
grep "^DATABASE_URL=" .env
echo ""

cat << EOF
╔════════════════════════════════════════════════════╗
║            Investigation Complete!                ║
╚════════════════════════════════════════════════════╝

🌐 Access Dashboard: http://localhost:8080
📊 Backend API: http://localhost:3000

📝 Next Steps:
   1. Check backend logs: docker logs -f emergency_backend
   2. If SQLite: database will be at backend/dev.db
   3. If PostgreSQL: ensure container is running

🔍 Debug:
   Show all logs: $COMPOSE logs -f
   Restart: $COMPOSE restart backend

EOF
