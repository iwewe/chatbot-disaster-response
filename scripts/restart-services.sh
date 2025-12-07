#!/bin/bash
################################################################################
# Emergency Response System - Service Restart Script
# Quickly restart specific services or all services
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="$HOME/chatbot-disaster-response"

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

# Check if installation directory exists
if [ ! -d "$INSTALL_DIR" ]; then
    log_error "Installation directory not found: $INSTALL_DIR"
    exit 1
fi

cd "$INSTALL_DIR"

# Use docker compose or docker-compose
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

# Display menu
echo "======================================================"
echo "  Emergency Response System - Service Restart"
echo "======================================================"
echo ""
echo "Choose service to restart:"
echo "  1) All services"
echo "  2) Backend only"
echo "  3) Database (PostgreSQL)"
echo "  4) Redis"
echo "  5) Ollama"
echo "  6) Dashboard"
echo "  7) Rebuild backend (no cache)"
echo "  8) Full rebuild (all services, no cache)"
echo "  9) View logs"
echo "  0) Exit"
echo ""
read -p "Enter choice [0-9]: " CHOICE

case $CHOICE in
    1)
        log_info "Restarting all services..."
        $COMPOSE_CMD restart
        log_success "All services restarted"
        $COMPOSE_CMD ps
        ;;

    2)
        log_info "Restarting backend..."
        $COMPOSE_CMD restart backend
        log_success "Backend restarted"
        log_info "Waiting for backend to be ready..."
        sleep 5
        docker logs --tail=20 emergency_backend
        ;;

    3)
        log_info "Restarting PostgreSQL..."
        $COMPOSE_CMD restart postgres
        log_success "PostgreSQL restarted"
        log_warning "Backend might need restart if DB connection is lost"
        ;;

    4)
        log_info "Restarting Redis..."
        $COMPOSE_CMD restart redis
        log_success "Redis restarted"
        ;;

    5)
        log_info "Restarting Ollama..."
        $COMPOSE_CMD restart ollama
        log_success "Ollama restarted"
        log_info "Checking Ollama status..."
        sleep 3
        curl -s http://localhost:11434/api/tags | jq '.' || echo "Ollama API not responding yet"
        ;;

    6)
        log_info "Restarting Dashboard..."
        if $COMPOSE_CMD ps | grep -q "dashboard"; then
            $COMPOSE_CMD restart dashboard
            log_success "Dashboard restarted"
        else
            log_warning "Dashboard container not found"
            log_info "Deploy dashboard using: ./scripts/deploy-dashboard.sh"
        fi
        ;;

    7)
        log_warning "Rebuilding backend (no cache)..."
        log_info "This will take a few minutes..."
        $COMPOSE_CMD stop backend
        $COMPOSE_CMD build --no-cache backend
        $COMPOSE_CMD up -d backend

        log_info "Waiting for backend to be ready..."
        sleep 5

        # Run migrations
        log_info "Running database migrations..."
        docker exec emergency_backend npx prisma db push --skip-generate || {
            log_warning "Migration failed, but continuing..."
        }

        log_success "Backend rebuilt and started"
        docker logs --tail=30 emergency_backend
        ;;

    8)
        log_warning "Full rebuild (all services, no cache)..."
        log_info "This will take several minutes..."

        read -p "Are you sure? This will stop all services. (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cancelled"
            exit 0
        fi

        $COMPOSE_CMD down
        $COMPOSE_CMD build --no-cache
        $COMPOSE_CMD up -d

        log_info "Waiting for services to be ready..."
        sleep 10

        # Run migrations
        log_info "Running database migrations..."
        docker exec emergency_backend npx prisma db push --skip-generate || {
            log_warning "Migration failed, but continuing..."
        }

        log_success "All services rebuilt and started"
        $COMPOSE_CMD ps
        ;;

    9)
        log_info "Viewing logs..."
        echo ""
        echo "Available services:"
        $COMPOSE_CMD ps --format table
        echo ""
        read -p "Enter service name (or 'all' for all logs): " SERVICE

        if [ "$SERVICE" = "all" ]; then
            $COMPOSE_CMD logs -f --tail=100
        else
            $COMPOSE_CMD logs -f --tail=100 $SERVICE
        fi
        ;;

    0)
        log_info "Exiting..."
        exit 0
        ;;

    *)
        log_error "Invalid choice"
        exit 1
        ;;
esac

echo ""
log_info "Done!"
