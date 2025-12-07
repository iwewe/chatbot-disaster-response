#!/bin/bash
################################################################################
# Emergency Response System - Curl Deployment Script
# Deploys/updates the system without Git using direct downloads
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

    log_info "Downloading $(basename $dest)..."

    # Create directory if doesn't exist
    mkdir -p "$(dirname $dest)"

    # Download with curl
    if curl -fsSL "$url" -o "$dest"; then
        log_success "Downloaded $(basename $dest)"
        return 0
    else
        log_error "Failed to download $(basename $dest)"
        return 1
    fi
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    log_error "Please do not run this script as root"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

log_info "Starting deployment using Curl method..."
echo "Source: GitHub Repository"
echo "Branch: $BRANCH"
echo "Installation directory: $INSTALL_DIR"
echo ""

# Backup existing installation
if [ -d "$INSTALL_DIR" ]; then
    log_warning "Existing installation found"

    # Backup .env file
    if [ -f "$INSTALL_DIR/.env" ]; then
        BACKUP_FILE="$BACKUP_DIR/env-backup-$(date +%Y%m%d-%H%M%S)"
        cp "$INSTALL_DIR/.env" "$BACKUP_FILE"
        log_success "Backed up .env to $BACKUP_FILE"
    fi

    # Ask user if they want to backup
    read -p "Do you want to backup current installation? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        BACKUP_TAR="$BACKUP_DIR/installation-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
        tar -czf "$BACKUP_TAR" -C "$HOME" "$(basename $INSTALL_DIR)"
        log_success "Backup created: $BACKUP_TAR"
    fi
fi

# Create installation directory
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Download essential files
log_info "Downloading essential configuration files..."

download_file "${BASE_URL}/docker-compose.yml" "docker-compose.yml"
download_file "${BASE_URL}/package.json" "package.json"
download_file "${BASE_URL}/.env.example" ".env.example"
download_file "${BASE_URL}/.dockerignore" ".dockerignore" || true
download_file "${BASE_URL}/.gitignore" ".gitignore" || true

# Download backend files
log_info "Downloading backend files..."

# Backend package.json
download_file "${BASE_URL}/backend/package.json" "backend/package.json"
download_file "${BASE_URL}/backend/Dockerfile" "backend/Dockerfile"
download_file "${BASE_URL}/backend/.dockerignore" "backend/.dockerignore" || true

# Prisma schema
download_file "${BASE_URL}/backend/prisma/schema.prisma" "backend/prisma/schema.prisma"

# Backend source files
mkdir -p backend/src/{config,controllers,middleware,routes,services,utils}

# Config files
download_file "${BASE_URL}/backend/src/config/database.js" "backend/src/config/database.js"
download_file "${BASE_URL}/backend/src/config/index.js" "backend/src/config/index.js"

# Controllers
download_file "${BASE_URL}/backend/src/controllers/api.controller.js" "backend/src/controllers/api.controller.js"
download_file "${BASE_URL}/backend/src/controllers/auth.controller.js" "backend/src/controllers/auth.controller.js"
download_file "${BASE_URL}/backend/src/controllers/webhook.controller.js" "backend/src/controllers/webhook.controller.js"
download_file "${BASE_URL}/backend/src/controllers/media.controller.js" "backend/src/controllers/media.controller.js" || true

# Middleware
download_file "${BASE_URL}/backend/src/middleware/auth.middleware.js" "backend/src/middleware/auth.middleware.js"

# Routes
download_file "${BASE_URL}/backend/src/routes/index.js" "backend/src/routes/index.js"

# Services
download_file "${BASE_URL}/backend/src/services/whatsapp.service.js" "backend/src/services/whatsapp.service.js"
download_file "${BASE_URL}/backend/src/services/whatsapp-baileys.service.js" "backend/src/services/whatsapp-baileys.service.js"
download_file "${BASE_URL}/backend/src/services/whatsapp-factory.service.js" "backend/src/services/whatsapp-factory.service.js"
download_file "${BASE_URL}/backend/src/services/ollama.service.js" "backend/src/services/ollama.service.js"
download_file "${BASE_URL}/backend/src/services/telegram.service.js" "backend/src/services/telegram.service.js"
download_file "${BASE_URL}/backend/src/services/message-processor.service.js" "backend/src/services/message-processor.service.js"

# Utils
download_file "${BASE_URL}/backend/src/utils/logger.js" "backend/src/utils/logger.js"

# Main server file
download_file "${BASE_URL}/backend/src/server.js" "backend/src/server.js"

# Download dashboard files
log_info "Downloading dashboard files..."

mkdir -p dashboard/js

download_file "${BASE_URL}/dashboard/index.html" "dashboard/index.html"
download_file "${BASE_URL}/dashboard/dashboard.html" "dashboard/dashboard.html"
download_file "${BASE_URL}/dashboard/reports.html" "dashboard/reports.html"
download_file "${BASE_URL}/dashboard/users.html" "dashboard/users.html"
download_file "${BASE_URL}/dashboard/map.html" "dashboard/map.html"

download_file "${BASE_URL}/dashboard/js/auth.js" "dashboard/js/auth.js"
download_file "${BASE_URL}/dashboard/js/dashboard.js" "dashboard/js/dashboard.js"
download_file "${BASE_URL}/dashboard/js/reports.js" "dashboard/js/reports.js"
download_file "${BASE_URL}/dashboard/js/users.js" "dashboard/js/users.js"
download_file "${BASE_URL}/dashboard/js/map.js" "dashboard/js/map.js"

# Setup .env if it doesn't exist
if [ ! -f ".env" ]; then
    log_warning ".env file not found"
    log_info "Creating .env from .env.example..."
    cp .env.example .env
    log_warning "IMPORTANT: Please edit .env file with your configuration"
    echo ""
    echo "Press Enter after editing .env file to continue..."
    read -r
fi

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if docker-compose is installed
if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
    log_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Use docker compose or docker-compose
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

# Source .env file
set -a
source .env
set +a

log_info "Stopping existing containers..."
$COMPOSE_CMD down || true

# Build and start containers
log_info "Building Docker containers (this may take a few minutes)..."
$COMPOSE_CMD build --no-cache

log_info "Starting containers..."
$COMPOSE_CMD up -d

# Wait for database to be ready
log_info "Waiting for database to be ready..."
sleep 10

# Run database migrations
log_info "Running database migrations..."
docker exec emergency_backend npx prisma db push --skip-generate || {
    log_warning "Migration failed, but continuing..."
}

# Check container status
log_info "Checking container status..."
$COMPOSE_CMD ps

# Display service URLs
echo ""
log_success "Deployment completed successfully!"
echo ""
echo "======================================================"
echo "  Service URLs:"
echo "======================================================"
echo "  Backend API:    http://localhost:3000"
echo "  PostgreSQL:     localhost:5432"
echo "  Redis:          localhost:6379"
echo "  Ollama:         http://localhost:11434"
echo ""
echo "  Dashboard:      Deploy using scripts/deploy-dashboard.sh"
echo "======================================================"
echo ""

log_info "To view logs, run: $COMPOSE_CMD logs -f"
