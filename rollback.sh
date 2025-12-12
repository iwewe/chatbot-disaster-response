#!/bin/bash

#==============================================================================
# Emergency Response System - Rollback Script
#==============================================================================
# Usage: ./rollback.sh [backup_timestamp]
# Example: ./rollback.sh 20231211_143025
#==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo "=================================================="
echo "  🔄 Emergency Response System Rollback"
echo "=================================================="
echo ""

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    error "docker-compose.yml not found. Please run from project root directory."
fi

# List available backups
if [ ! -d "backups" ]; then
    error "No backups directory found"
fi

echo "Available backups:"
echo ""
ls -1 backups/ | nl -v 1
echo ""

# Get backup timestamp
if [ -z "$1" ]; then
    read -p "Enter backup number or timestamp: " BACKUP_INPUT

    # Check if input is a number
    if [[ "$BACKUP_INPUT" =~ ^[0-9]+$ ]]; then
        TIMESTAMP=$(ls -1 backups/ | sed -n "${BACKUP_INPUT}p")
    else
        TIMESTAMP="$BACKUP_INPUT"
    fi
else
    TIMESTAMP="$1"
fi

BACKUP_DIR="backups/$TIMESTAMP"

if [ ! -d "$BACKUP_DIR" ]; then
    error "Backup not found: $BACKUP_DIR"
fi

log "Rolling back to: $TIMESTAMP"
echo ""

# Confirm rollback
read -p "Are you sure you want to rollback? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Rollback cancelled"
    exit 0
fi

echo ""
log "Starting rollback process..."
echo ""

# Rollback dashboard
if [ -d "$BACKUP_DIR/dashboard" ]; then
    log "Restoring dashboard files..."
    rm -rf dashboard/*
    cp -r "$BACKUP_DIR/dashboard/"* dashboard/
    success "Dashboard restored"
else
    warning "No dashboard backup found"
fi

# Rollback backend
if [ -d "$BACKUP_DIR/backend/src" ]; then
    log "Restoring backend source..."
    rm -rf backend/src/*
    cp -r "$BACKUP_DIR/backend/src/"* backend/src/

    if [ -f "$BACKUP_DIR/backend/package.json" ]; then
        cp "$BACKUP_DIR/backend/package.json" backend/
    fi
    success "Backend source restored"
else
    warning "No backend backup found"
fi

# Rollback .env
if [ -f "$BACKUP_DIR/.env" ]; then
    log "Restoring .env file..."
    cp "$BACKUP_DIR/.env" .env
    success ".env restored"
fi

# Restart services
log "Restarting services..."

if command -v docker compose &> /dev/null; then
    DOCKER_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    DOCKER_CMD="docker-compose"
else
    error "Neither 'docker compose' nor 'docker-compose' found"
fi

$DOCKER_CMD build backend
$DOCKER_CMD restart

success "Services restarted"

echo ""
log "Waiting for services to initialize..."
sleep 5

# Verify
log "Verifying services..."

if curl -f -s http://localhost:8080 > /dev/null 2>&1; then
    success "Dashboard is accessible"
else
    warning "Dashboard may not be ready yet"
fi

if curl -f -s http://localhost:3000/health > /dev/null 2>&1; then
    success "Backend is healthy"
else
    warning "Backend may not be ready yet"
fi

echo ""
echo "=================================================="
success "Rollback Complete!"
echo "=================================================="
echo ""
echo "Restored from: $BACKUP_DIR"
echo ""
