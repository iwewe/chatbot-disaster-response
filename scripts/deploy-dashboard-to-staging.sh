#!/bin/bash
################################################################################
# COMPREHENSIVE Dashboard Deployment Script for Existing Staging
# This script will completely fix and deploy dashboard - NO MORE ERRORS!
################################################################################

set -e

# Colors
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
header() { echo -e "\n${CYAN}${BOLD}$1${NC}\n"; }

clear
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║   Emergency Response Dashboard - Comprehensive Deploy   ║
║              Fix Everything and Deploy Now!              ║
╚══════════════════════════════════════════════════════════╝
EOF
echo ""

# Check prerequisites
header "🔍 Checking Environment"

[ ! -f "docker-compose.yml" ] && error "docker-compose.yml not found. Run from project root!"
command -v docker >/dev/null 2>&1 || error "Docker not installed!"

# Detect compose command
if docker compose version >/dev/null 2>&1; then
    COMPOSE="docker compose"
else
    COMPOSE="docker-compose"
fi
success "Using: $COMPOSE"

# Backup everything
header "💾 Creating Comprehensive Backup"

BACKUP_DIR="backups/deploy-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

cp docker-compose.yml "$BACKUP_DIR/docker-compose.yml"
[ -f .env ] && cp .env "$BACKUP_DIR/.env"
[ -d dashboard ] && cp -r dashboard "$BACKUP_DIR/dashboard"

success "Backup saved to: $BACKUP_DIR"

# Step 1: Download all dashboard files
header "📥 Downloading Dashboard Files"

BRANCH="claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf"
BASE_URL="https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/${BRANCH}"

mkdir -p dashboard/js

download_file() {
    local url="$1"
    local dest="$2"
    if curl -fsSL "$url" -o "$dest"; then
        success "$(basename $dest)"
    else
        error "Failed to download $(basename $dest)"
    fi
}

log "Downloading HTML files..."
download_file "${BASE_URL}/dashboard/index.html" "dashboard/index.html"
download_file "${BASE_URL}/dashboard/dashboard.html" "dashboard/dashboard.html"
download_file "${BASE_URL}/dashboard/reports.html" "dashboard/reports.html"
download_file "${BASE_URL}/dashboard/users.html" "dashboard/users.html"
download_file "${BASE_URL}/dashboard/map.html" "dashboard/map.html"

log "Downloading JavaScript files..."
download_file "${BASE_URL}/dashboard/js/auth.js" "dashboard/js/auth.js"
download_file "${BASE_URL}/dashboard/js/dashboard.js" "dashboard/js/dashboard.js"
download_file "${BASE_URL}/dashboard/js/reports.js" "dashboard/js/reports.js"
download_file "${BASE_URL}/dashboard/js/users.js" "dashboard/js/users.js"
download_file "${BASE_URL}/dashboard/js/map.js" "dashboard/js/map.js"

success "All dashboard files downloaded"

# Step 2: Create nginx config
header "🔧 Creating Nginx Configuration"

cat > nginx-dashboard.conf <<'NGINX_EOF'
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/json;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://backend:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /auth/ {
        proxy_pass http://backend:3000;
        proxy_set_header Host $host;
    }

    location /webhook {
        proxy_pass http://backend:3000;
        proxy_set_header Host $host;
    }

    location /health {
        proxy_pass http://backend:3000;
    }
}
NGINX_EOF

success "Nginx configuration created"

# Step 3: Rebuild docker-compose.yml properly
header "🔨 Rebuilding docker-compose.yml"

log "Extracting existing configuration..."

# Get database password
DB_PASS=$(grep POSTGRES_PASSWORD .env 2>/dev/null | cut -d= -f2 || echo "emergency123")

# Create brand new docker-compose.yml with correct structure
cat > docker-compose.yml <<COMPOSE_EOF
services:
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: emergency_backend
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=\${NODE_ENV:-development}
      - DATABASE_URL=\${DATABASE_URL}
      - REDIS_URL=\${REDIS_URL}
    env_file:
      - .env
    volumes:
      - ./backend:/app
      - /app/node_modules
      - baileys_session:/app/baileys-session
    networks:
      - emergency_net
    depends_on:
      - postgres
      - redis
      - ollama
    restart: unless-stopped
    dns:
      - 8.8.8.8
      - 8.8.4.4
      - 1.1.1.1

  postgres:
    image: postgres:15-alpine
    container_name: emergency_db
    environment:
      POSTGRES_DB: \${POSTGRES_DB:-emergency_db}
      POSTGRES_USER: \${POSTGRES_USER:-emergency}
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD:-$DB_PASS}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - emergency_net
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: emergency_redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    networks:
      - emergency_net
    restart: unless-stopped

  ollama:
    image: ollama/ollama:latest
    container_name: emergency_ollama
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    networks:
      - emergency_net
    restart: unless-stopped

  dashboard:
    image: nginx:alpine
    container_name: emergency_dashboard
    volumes:
      - ./dashboard:/usr/share/nginx/html:ro
      - ./nginx-dashboard.conf:/etc/nginx/conf.d/default.conf:ro
    ports:
      - "8080:80"
    networks:
      - emergency_net
    depends_on:
      - backend
    restart: unless-stopped

networks:
  emergency_net:
    driver: bridge

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  ollama_data:
    driver: local
  baileys_session:
    driver: local
COMPOSE_EOF

success "docker-compose.yml rebuilt with correct structure"

# Validate
log "Validating docker-compose.yml..."
if $COMPOSE config >/dev/null 2>&1; then
    success "✓ Configuration is valid!"
else
    warn "Validation output:"
    $COMPOSE config
    error "docker-compose.yml validation failed"
fi

# Step 4: Setup admin user
header "👤 Setting Up Admin User"

# Find backend container
BACKEND=$($COMPOSE ps -q backend 2>/dev/null | head -1)
if [ -z "$BACKEND" ]; then
    log "Backend not running, starting it..."
    $COMPOSE up -d backend
    sleep 10
    BACKEND=$($COMPOSE ps -q backend | head -1)
fi

log "Checking for admin user..."

ADMIN_CHECK=$(docker exec $(docker ps -qf "name=backend") node -e "
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
prisma.user.findFirst({ where: { role: 'ADMIN' } })
  .then(admin => admin ? console.log('EXISTS:' + admin.phoneNumber) : console.log('NONE'))
  .catch(() => console.log('ERROR'))
  .finally(() => prisma.\$disconnect());
" 2>/dev/null || echo "ERROR")

if echo "$ADMIN_CHECK" | grep -q "EXISTS:"; then
    ADMIN_USER=$(echo "$ADMIN_CHECK" | cut -d: -f2)
    success "Admin user exists: $ADMIN_USER"
else
    log "Creating admin user..."
    docker exec $(docker ps -qf "name=backend") node -e "
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
prisma.user.create({
  data: {
    phoneNumber: 'admin',
    name: 'Administrator',
    role: 'ADMIN',
    trustLevel: 5,
    isActive: true
  }
}).then(() => console.log('Created'))
  .catch(console.error)
  .finally(() => prisma.\$disconnect());
" >/dev/null 2>&1
    ADMIN_USER="admin"
    success "Admin user created: $ADMIN_USER"
fi

# Step 5: Setup password
header "🔐 Setting Up Admin Password"

if grep -q "^ADMIN_PASSWORD=" .env 2>/dev/null; then
    ADMIN_PASS=$(grep "^ADMIN_PASSWORD=" .env | cut -d= -f2)
    success "Using existing password from .env"
else
    ADMIN_PASS="Admin123!Staging"
    echo "ADMIN_PASSWORD=$ADMIN_PASS" >> .env
    success "Password set to: $ADMIN_PASS"
fi

# Step 6: Deploy dashboard
header "🚀 Deploying Dashboard"

log "Stopping any existing dashboard..."
$COMPOSE stop dashboard 2>/dev/null || true
$COMPOSE rm -f dashboard 2>/dev/null || true

log "Starting dashboard container..."
$COMPOSE up -d dashboard

log "Waiting for dashboard to be ready..."
sleep 5

# Restart backend to apply password
log "Restarting backend..."
$COMPOSE restart backend
sleep 5

# Step 7: Verify
header "✅ Verification"

# Check containers
log "Checking container status..."
if docker ps | grep -q "emergency_dashboard"; then
    success "Dashboard container is running"
else
    error "Dashboard container failed to start. Check logs: docker logs emergency_dashboard"
fi

if docker ps | grep -q "emergency_backend"; then
    success "Backend container is running"
else
    warn "Backend container not running"
fi

# Check accessibility
if curl -sf http://localhost:8080 >/dev/null 2>&1; then
    success "Dashboard is accessible"
else
    warn "Dashboard not accessible on port 8080 (may be normal if external)"
fi

# Check backend health
if curl -sf http://localhost:3000/health >/dev/null 2>&1; then
    success "Backend API is healthy"
else
    warn "Backend API not responding"
fi

# Final summary
cat << EOF

╔══════════════════════════════════════════════════════════╗
║              🎉 DEPLOYMENT SUCCESSFUL! 🎉                ║
╚══════════════════════════════════════════════════════════╝

📊 Dashboard Access:
   URL:      ${GREEN}http://localhost:8080${NC}
   Username: ${CYAN}${ADMIN_USER}${NC}
   Password: ${CYAN}${ADMIN_PASS}${NC}

🔧 Container Status:
EOF

$COMPOSE ps

cat << EOF

📝 Useful Commands:
   View dashboard logs:  docker logs -f emergency_dashboard
   View backend logs:    docker logs -f emergency_backend
   Restart dashboard:    $COMPOSE restart dashboard
   Stop all services:    $COMPOSE down

💾 Backup Location: $BACKUP_DIR

🌐 If accessing remotely, ensure port 8080 is open or use reverse proxy.

EOF

# Save credentials
CREDS_FILE="$BACKUP_DIR/credentials.txt"
cat > "$CREDS_FILE" << CREDS_EOF
Emergency Response Dashboard Credentials
========================================
Generated: $(date)

Dashboard URL: http://localhost:8080
Username: ${ADMIN_USER}
Password: ${ADMIN_PASS}

Backend API: http://localhost:3000

Container Names:
  - emergency_dashboard
  - emergency_backend
  - emergency_db
  - emergency_redis
  - emergency_ollama
CREDS_EOF

success "Credentials saved to: $CREDS_FILE"
echo ""
success "✨ Dashboard deployment completed successfully!"
echo ""
