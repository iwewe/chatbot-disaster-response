#!/bin/bash
################################################################################
# Emergency Response System - Dashboard Update Script
# Updates only the dashboard files without touching backend
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BRANCH="claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf"
BASE_URL="https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/${BRANCH}"
INSTALL_DIR="$HOME/chatbot-disaster-response"
DASHBOARD_DIR="$INSTALL_DIR/dashboard"
BACKUP_DIR="$HOME/emergency-backups"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

download_file() {
    local url=$1
    local dest=$2

    if curl -fsSL "$url" -o "$dest"; then
        return 0
    else
        log_error "Failed to download $(basename $dest)"
        return 1
    fi
}

# Create backup directory
mkdir -p "$BACKUP_DIR"

log_info "Updating dashboard files..."
echo "Source: GitHub Repository"
echo "Branch: $BRANCH"
echo ""

# Check if installation exists
if [ ! -d "$INSTALL_DIR" ]; then
    log_error "Installation directory not found: $INSTALL_DIR"
    log_info "Please run deploy-git.sh or deploy-curl.sh first"
    exit 1
fi

# Backup current dashboard
if [ -d "$DASHBOARD_DIR" ]; then
    BACKUP_TAR="$BACKUP_DIR/dashboard-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "$BACKUP_TAR" -C "$INSTALL_DIR" "dashboard"
    log_success "Backup created: $BACKUP_TAR"
fi

# Create dashboard directory
mkdir -p "$DASHBOARD_DIR/js"

# Choose update method
echo "Choose update method:"
echo "  1) Git pull (if installed via git)"
echo "  2) Curl download (direct download)"
echo ""
read -p "Enter choice [1-2]: " METHOD

case $METHOD in
    1)
        # Git pull method
        cd "$INSTALL_DIR"

        if [ ! -d ".git" ]; then
            log_error "Not a git repository. Use Curl method instead."
            exit 1
        fi

        log_info "Pulling latest dashboard files..."
        git fetch origin
        git checkout "$BRANCH"

        # Only pull dashboard files
        git checkout origin/$BRANCH -- dashboard/

        log_success "Dashboard files updated from git"
        ;;

    2)
        # Curl download method
        log_info "Downloading dashboard files..."

        # HTML files
        download_file "${BASE_URL}/dashboard/index.html" "$DASHBOARD_DIR/index.html"
        download_file "${BASE_URL}/dashboard/dashboard.html" "$DASHBOARD_DIR/dashboard.html"
        download_file "${BASE_URL}/dashboard/reports.html" "$DASHBOARD_DIR/reports.html"
        download_file "${BASE_URL}/dashboard/users.html" "$DASHBOARD_DIR/users.html"
        download_file "${BASE_URL}/dashboard/map.html" "$DASHBOARD_DIR/map.html"

        # JavaScript files
        download_file "${BASE_URL}/dashboard/js/auth.js" "$DASHBOARD_DIR/js/auth.js"
        download_file "${BASE_URL}/dashboard/js/dashboard.js" "$DASHBOARD_DIR/js/dashboard.js"
        download_file "${BASE_URL}/dashboard/js/reports.js" "$DASHBOARD_DIR/js/reports.js"
        download_file "${BASE_URL}/dashboard/js/users.js" "$DASHBOARD_DIR/js/users.js"
        download_file "${BASE_URL}/dashboard/js/map.js" "$DASHBOARD_DIR/js/map.js"

        log_success "Dashboard files downloaded"
        ;;

    *)
        log_error "Invalid choice"
        exit 1
        ;;
esac

# Detect deployment method and update accordingly
echo ""
log_info "Detecting deployment method..."

# Check if deployed via Nginx
if [ -d "/var/www/html/emergency-dashboard" ]; then
    log_info "Nginx deployment detected"
    read -p "Update Nginx files? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo cp -r "$DASHBOARD_DIR"/* "/var/www/html/emergency-dashboard/"
        sudo chown -R www-data:www-data "/var/www/html/emergency-dashboard"
        log_success "Nginx files updated"
    fi
fi

# Check if deployed via Docker
if command -v docker &> /dev/null; then
    if command -v docker compose &> /dev/null && docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi

    cd "$INSTALL_DIR"

    if $COMPOSE_CMD ps 2>/dev/null | grep -q "dashboard"; then
        log_info "Docker dashboard deployment detected"
        read -p "Restart dashboard container? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            $COMPOSE_CMD restart dashboard
            log_success "Dashboard container restarted"
        fi
    fi
fi

echo ""
log_success "Dashboard update completed!"
echo ""
log_info "Clear your browser cache to see the changes"
echo "  - Chrome/Edge: Ctrl+Shift+R or Ctrl+F5"
echo "  - Firefox: Ctrl+Shift+R"
echo "  - Safari: Cmd+Shift+R"
echo ""
