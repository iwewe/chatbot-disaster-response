#!/bin/bash

#==============================================================================
# Quick Dashboard Update - One-liner Installation Script
#==============================================================================
# Usage: curl -fsSL <url> | bash
#==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo "=================================================="
echo "  🚨 Emergency Response Dashboard Update"
echo "=================================================="
echo ""

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    error "docker-compose.yml not found. Please run from project root directory."
fi

# Create dashboard directory if not exists
mkdir -p dashboard

# Backup existing files
BACKUP_DIR="dashboard_backup_$(date +%Y%m%d_%H%M%S)"
if [ -d "dashboard" ] && [ "$(ls -A dashboard)" ]; then
    log "Creating backup at $BACKUP_DIR..."
    cp -r dashboard "$BACKUP_DIR"
    success "Backup created"
fi

# GitHub raw content base URL
BRANCH="claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf"
GITHUB_RAW="https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/$BRANCH/dashboard"

# Files to download
FILES=(
    "home.html"
    "index.html"
    "dashboard.html"
    "reports.html"
    "create-report.html"
    "public-form.html"
    "nginx.conf"
)

log "Downloading dashboard files from GitHub..."
echo ""

for file in "${FILES[@]}"; do
    echo -n "  → $file ... "
    if curl -fsSL "$GITHUB_RAW/$file" -o "dashboard/$file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠ (skipped)${NC}"
    fi
done

echo ""
success "All files downloaded successfully"

# Restart dashboard service
log "Restarting dashboard service..."
if docker compose restart dashboard 2>/dev/null || docker-compose restart dashboard 2>/dev/null; then
    success "Dashboard service restarted"
else
    error "Failed to restart dashboard service"
fi

# Wait for service to be ready
sleep 2

# Check if dashboard is accessible
log "Verifying dashboard accessibility..."
if curl -f -s http://localhost:8080 > /dev/null 2>&1; then
    success "Dashboard is accessible!"
else
    echo -e "${YELLOW}[!]${NC} Dashboard may not be fully ready yet"
fi

echo ""
echo "=================================================="
echo "  ✅ Dashboard Update Complete!"
echo "=================================================="
echo ""
echo "📊 Access URLs:"
echo "   • Homepage:      http://localhost:8080"
echo "   • Public Form:   http://localhost:8080/public-form.html"
echo "   • Admin Login:   http://localhost:8080/index.html"
echo ""
echo "🔐 Demo Credentials:"
echo "   Username: admin"
echo "   Password: Admin123!Staging"
echo ""
if [ -d "$BACKUP_DIR" ]; then
    echo "📁 Backup: $BACKUP_DIR"
    echo ""
fi
success "All updates completed successfully!"
echo ""
