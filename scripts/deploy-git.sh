#!/bin/bash
################################################################################
# Emergency Response System - Git Deployment Script
# Deploys/updates the system from GitHub repository
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/iwewe/chatbot-disaster-response.git"
BRANCH="claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf"
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

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    log_error "Please do not run this script as root"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

log_info "Starting deployment from Git repository..."
echo "Repository: $REPO_URL"
echo "Branch: $BRANCH"
echo "Installation directory: $INSTALL_DIR"
echo ""

# Check if this is first install or update
if [ -d "$INSTALL_DIR" ]; then
    log_info "Existing installation found. Performing update..."

    # Backup current .env file
    if [ -f "$INSTALL_DIR/.env" ]; then
        BACKUP_FILE="$BACKUP_DIR/env-backup-$(date +%Y%m%d-%H%M%S)"
        cp "$INSTALL_DIR/.env" "$BACKUP_FILE"
        log_success "Backed up .env to $BACKUP_FILE"
    fi

    # Navigate to installation directory
    cd "$INSTALL_DIR"

    # Check if git repository
    if [ -d ".git" ]; then
        log_info "Pulling latest changes..."
        git fetch origin
        git checkout "$BRANCH"
        git pull origin "$BRANCH"
        log_success "Code updated successfully"
    else
        log_error "Directory exists but is not a git repository"
        log_info "Please remove $INSTALL_DIR and run this script again"
        exit 1
    fi
else
    log_info "No existing installation found. Performing fresh install..."

    # Clone repository
    log_info "Cloning repository..."
    git clone -b "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    log_success "Repository cloned successfully"
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

# Setup .env if it doesn't exist
if [ ! -f ".env" ]; then
    log_warning ".env file not found"
    if [ -f ".env.example" ]; then
        log_info "Creating .env from .env.example..."
        cp .env.example .env
        log_warning "IMPORTANT: Please edit .env file with your configuration before continuing"
        echo ""
        echo "Press Enter after editing .env file to continue..."
        read -r
    else
        log_error ".env.example not found. Cannot create configuration."
        exit 1
    fi
fi

# Source .env file
set -a
source .env
set +a

log_info "Stopping existing containers..."
$COMPOSE_CMD down

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

# Check if admin user exists
log_info "Checking for admin user..."
docker exec emergency_backend node -e "
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const admin = await prisma.user.findFirst({
    where: { role: 'ADMIN' },
  });

  if (!admin) {
    console.log('⚠️  No admin user found!');
    console.log('Run: npm run setup-admin OR docker exec -it emergency_backend node -e \"<create admin script>\"');
  } else {
    console.log('✅ Admin user exists:', admin.name);
  }
}

main().catch(console.error).finally(() => prisma.\$disconnect());
" 2>/dev/null || log_warning "Could not check admin user"

# Show logs
echo ""
log_info "Showing recent logs (Ctrl+C to exit)..."
echo ""
sleep 2
$COMPOSE_CMD logs --tail=50 -f
