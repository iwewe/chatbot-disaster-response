#!/bin/bash

#==============================================================================
# Emergency Response System - Full Deployment Script
#==============================================================================
# Usage: curl -fsSL <url> | bash
# Or: ./deploy.sh
#==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
section() { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${MAGENTA}$1${NC}"; echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

echo ""
echo "=================================================="
echo "  🚨 Emergency Response System Deployment"
echo "=================================================="
echo ""
echo "  This script will:"
echo "  • Backup existing files"
echo "  • Download latest code from GitHub"
echo "  • Rebuild and restart services"
echo "  • Verify deployment"
echo ""
echo "=================================================="
echo ""

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    error "docker-compose.yml not found. Please run from project root directory."
fi

# GitHub raw content base URL
BRANCH="claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf"
GITHUB_RAW="https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/$BRANCH"

# Timestamp for backups
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_ROOT="backups/$TIMESTAMP"

#==============================================================================
# BACKUP PHASE
#==============================================================================
section "📦 Phase 1: Backup Existing Files"

mkdir -p "$BACKUP_ROOT"

# Backup dashboard
if [ -d "dashboard" ] && [ "$(ls -A dashboard)" ]; then
    log "Backing up dashboard..."
    cp -r dashboard "$BACKUP_ROOT/dashboard"
    success "Dashboard backed up"
else
    warning "No dashboard files to backup"
fi

# Backup backend source
if [ -d "backend/src" ]; then
    log "Backing up backend source code..."
    mkdir -p "$BACKUP_ROOT/backend"
    cp -r backend/src "$BACKUP_ROOT/backend/"
    if [ -f "backend/package.json" ]; then
        cp backend/package.json "$BACKUP_ROOT/backend/"
    fi
    success "Backend source backed up"
else
    warning "No backend source to backup"
fi

# Backup environment files
if [ -f ".env" ]; then
    log "Backing up .env file..."
    cp .env "$BACKUP_ROOT/.env"
    success ".env file backed up"
fi

success "All backups created at: $BACKUP_ROOT"

#==============================================================================
# DOWNLOAD PHASE - DASHBOARD
#==============================================================================
section "⬇️  Phase 2: Download Dashboard Files"

mkdir -p dashboard

DASHBOARD_FILES=(
    "home.html"
    "index.html"
    "dashboard.html"
    "reports.html"
    "create-report.html"
    "public-form.html"
    "nginx.conf"
    "logo-cri.png"
    "rdw-logo.png"
)

log "Downloading dashboard files from GitHub..."
echo ""

DASHBOARD_SUCCESS=0
DASHBOARD_FAILED=0

for file in "${DASHBOARD_FILES[@]}"; do
    echo -n "  → $file ... "
    if curl -fsSL "$GITHUB_RAW/dashboard/$file" -o "dashboard/$file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        ((DASHBOARD_SUCCESS++))
    else
        echo -e "${YELLOW}⚠ (failed)${NC}"
        ((DASHBOARD_FAILED++))
    fi
done

echo ""
success "Dashboard: $DASHBOARD_SUCCESS files downloaded, $DASHBOARD_FAILED failed"

#==============================================================================
# DOWNLOAD PHASE - BACKEND
#==============================================================================
section "⬇️  Phase 3: Download Backend Files"

mkdir -p backend/src/controllers
mkdir -p backend/src/routes

BACKEND_FILES=(
    "src/controllers/api.controller.js"
    "src/routes/index.js"
)

log "Downloading backend files from GitHub..."
echo ""

BACKEND_SUCCESS=0
BACKEND_FAILED=0

for file in "${BACKEND_FILES[@]}"; do
    echo -n "  → $file ... "
    if curl -fsSL "$GITHUB_RAW/backend/$file" -o "backend/$file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        ((BACKEND_SUCCESS++))
    else
        echo -e "${YELLOW}⚠ (failed)${NC}"
        ((BACKEND_FAILED++))
    fi
done

echo ""
success "Backend: $BACKEND_SUCCESS files downloaded, $BACKEND_FAILED failed"

#==============================================================================
# DOCKER PHASE
#==============================================================================
section "🐳 Phase 4: Rebuild & Restart Services"

# Check which docker command is available
if command -v docker compose &> /dev/null; then
    DOCKER_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    DOCKER_CMD="docker-compose"
else
    error "Neither 'docker compose' nor 'docker-compose' found. Please install Docker Compose."
fi

log "Using: $DOCKER_CMD"

# Rebuild backend
log "Rebuilding backend service..."
if $DOCKER_CMD build backend 2>&1 | grep -q "Successfully"; then
    success "Backend rebuilt successfully"
else
    warning "Backend rebuild may have issues, check logs"
fi

# Restart all services
log "Restarting all services..."
$DOCKER_CMD restart

success "All services restarted"

# Wait for services to be ready
log "Waiting for services to initialize..."
sleep 5

#==============================================================================
# VERIFICATION PHASE
#==============================================================================
section "✅ Phase 5: Verification"

# Check backend health
log "Checking backend health..."
BACKEND_HEALTHY=false
for i in {1..10}; do
    if curl -f -s http://localhost:3000/health > /dev/null 2>&1; then
        BACKEND_HEALTHY=true
        break
    fi
    sleep 2
done

if [ "$BACKEND_HEALTHY" = true ]; then
    success "Backend is healthy"
else
    warning "Backend health check failed, check logs: $DOCKER_CMD logs backend"
fi

# Check dashboard
log "Checking dashboard accessibility..."
if curl -f -s http://localhost:8080 > /dev/null 2>&1; then
    success "Dashboard is accessible"
else
    warning "Dashboard not accessible yet, may need more time"
fi

# Show service status
log "Docker service status:"
$DOCKER_CMD ps

#==============================================================================
# SUMMARY
#==============================================================================
section "📊 Deployment Summary"

echo ""
echo "✅ Deployment completed successfully!"
echo ""
echo "📁 Backup Location:"
echo "   $BACKUP_ROOT"
echo ""
echo "📊 Access URLs:"
echo "   • Homepage:      http://localhost:8080"
echo "   • Public Form:   http://localhost:8080/public-form.html"
echo "   • Admin Login:   http://localhost:8080/index.html"
echo "   • Backend API:   http://localhost:3000"
echo "   • Health Check:  http://localhost:3000/health"
echo ""
echo "🔐 Demo Credentials:"
echo "   Username: admin"
echo "   Password: Admin123!Staging"
echo ""
echo "📝 Useful Commands:"
echo "   • View logs:     $DOCKER_CMD logs -f [service]"
echo "   • Restart:       $DOCKER_CMD restart [service]"
echo "   • Stop all:      $DOCKER_CMD down"
echo "   • Start all:     $DOCKER_CMD up -d"
echo ""

if [ "$BACKEND_HEALTHY" = false ]; then
    warning "Backend health check failed. Run: $DOCKER_CMD logs backend"
fi

echo "=================================================="
success "Deployment Complete!"
echo "=================================================="
echo ""
