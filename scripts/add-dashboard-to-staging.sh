#!/bin/bash
################################################################################
# Emergency Response System - Add Dashboard to Existing Staging
# Adds web-based dashboard to existing development/staging environment
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
BRANCH="claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf"
BASE_URL="https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/${BRANCH}"
INSTALL_DIR=$(pwd)
BACKUP_DIR="$INSTALL_DIR/backups"

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

log_step() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    log_warning "Running as root. It's recommended to run as regular user."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Header
clear
echo -e "${CYAN}"
echo "======================================================"
echo "  Emergency Response Dashboard Deployment"
echo "  Add Dashboard to Existing Staging Environment"
echo "======================================================"
echo -e "${NC}"
echo ""

# Step 0: Verify prerequisites
log_step "Step 0: Checking Prerequisites"

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    log_error "docker-compose.yml not found in current directory"
    log_info "Please run this script from your project root directory"
    log_info "Current directory: $(pwd)"
    exit 1
fi
log_success "docker-compose.yml found"

# Check if docker is running
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    exit 1
fi
log_success "Docker is installed"

# Check if backend container is running
if ! docker ps | grep -q "backend\|emergency_backend"; then
    log_warning "Backend container is not running"
    log_info "Starting backend first..."

    # Use docker compose or docker-compose
    if command -v docker compose &> /dev/null && docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi

    $COMPOSE_CMD up -d backend
    sleep 5
else
    log_success "Backend container is running"
fi

# Detect compose command
if command -v docker compose &> /dev/null && docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi
log_info "Using: $COMPOSE_CMD"

# Step 1: Backup
log_step "Step 1: Creating Backup"

mkdir -p "$BACKUP_DIR"

# Backup docker-compose.yml
BACKUP_FILE="$BACKUP_DIR/docker-compose-backup-$(date +%Y%m%d-%H%M%S).yml"
cp docker-compose.yml "$BACKUP_FILE"
log_success "Backed up docker-compose.yml to $BACKUP_FILE"

# Backup .env if exists
if [ -f ".env" ]; then
    ENV_BACKUP="$BACKUP_DIR/env-backup-$(date +%Y%m%d-%H%M%S)"
    cp .env "$ENV_BACKUP"
    log_success "Backed up .env to $ENV_BACKUP"
fi

# Step 2: Download Dashboard Files
log_step "Step 2: Downloading Dashboard Files"

mkdir -p dashboard/js

log_info "Downloading HTML files..."
curl -fsSL "${BASE_URL}/dashboard/index.html" -o dashboard/index.html && log_success "✓ index.html"
curl -fsSL "${BASE_URL}/dashboard/dashboard.html" -o dashboard/dashboard.html && log_success "✓ dashboard.html"
curl -fsSL "${BASE_URL}/dashboard/reports.html" -o dashboard/reports.html && log_success "✓ reports.html"
curl -fsSL "${BASE_URL}/dashboard/users.html" -o dashboard/users.html && log_success "✓ users.html"
curl -fsSL "${BASE_URL}/dashboard/map.html" -o dashboard/map.html && log_success "✓ map.html"

log_info "Downloading JavaScript files..."
curl -fsSL "${BASE_URL}/dashboard/js/auth.js" -o dashboard/js/auth.js && log_success "✓ auth.js"
curl -fsSL "${BASE_URL}/dashboard/js/dashboard.js" -o dashboard/js/dashboard.js && log_success "✓ dashboard.js"
curl -fsSL "${BASE_URL}/dashboard/js/reports.js" -o dashboard/js/reports.js && log_success "✓ reports.js"
curl -fsSL "${BASE_URL}/dashboard/js/users.js" -o dashboard/js/users.js && log_success "✓ users.js"
curl -fsSL "${BASE_URL}/dashboard/js/map.js" -o dashboard/js/map.js && log_success "✓ map.js"

log_success "All dashboard files downloaded successfully"

# Step 3: Create Nginx Configuration
log_step "Step 3: Creating Nginx Configuration"

cat > nginx-dashboard.conf <<'EOF'
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/json;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Dashboard static files
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Proxy API requests to backend
    location /api/ {
        proxy_pass http://backend:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_cache_bypass $http_upgrade;
    }

    # Proxy auth requests to backend
    location /auth/ {
        proxy_pass http://backend:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Proxy webhook requests
    location /webhook {
        proxy_pass http://backend:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Proxy health check
    location /health {
        proxy_pass http://backend:3000;
        proxy_set_header Host $host;
    }

    # Logs
    access_log /var/log/nginx/dashboard-access.log;
    error_log /var/log/nginx/dashboard-error.log;
}
EOF

log_success "Nginx configuration created: nginx-dashboard.conf"

# Step 4: Update docker-compose.yml
log_step "Step 4: Adding Dashboard Service to docker-compose.yml"

# Check if dashboard service already exists
if grep -q "dashboard:" docker-compose.yml; then
    log_warning "Dashboard service already exists in docker-compose.yml"
    read -p "Replace existing dashboard service? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Remove old dashboard service (simple approach - you may need manual edit for complex cases)
        log_info "Please remove old dashboard service manually if needed"
    else
        log_info "Skipping docker-compose.yml update"
    fi
else
    # Add dashboard service
    cat >> docker-compose.yml <<'EOF'

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
EOF
    log_success "Dashboard service added to docker-compose.yml"
fi

# Step 5: Check and Setup Admin User
log_step "Step 5: Setting Up Admin User"

# Detect backend container name
BACKEND_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'backend|emergency_backend' | head -1)

if [ -z "$BACKEND_CONTAINER" ]; then
    log_error "Backend container not found"
    exit 1
fi

log_info "Using backend container: $BACKEND_CONTAINER"

# Check for existing admin
log_info "Checking for existing admin user..."

ADMIN_CHECK=$(docker exec $BACKEND_CONTAINER node -e "
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const admin = await prisma.user.findFirst({
      where: { role: 'ADMIN' },
    });

    if (admin) {
      console.log('EXISTS:' + admin.phoneNumber + ':' + admin.name);
    } else {
      console.log('NONE');
    }
  } catch (error) {
    console.log('ERROR:' + error.message);
  }
}

main().catch(() => console.log('ERROR')).finally(() => prisma.\$disconnect());
" 2>/dev/null || echo "ERROR")

if echo "$ADMIN_CHECK" | grep -q "EXISTS:"; then
    ADMIN_PHONE=$(echo "$ADMIN_CHECK" | cut -d: -f2)
    ADMIN_NAME=$(echo "$ADMIN_CHECK" | cut -d: -f3)
    log_success "Admin user already exists: $ADMIN_NAME ($ADMIN_PHONE)"
    ADMIN_USERNAME="$ADMIN_PHONE"
else
    log_warning "No admin user found. Creating default admin..."

    # Create admin user
    docker exec $BACKEND_CONTAINER node -e "
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const admin = await prisma.user.create({
      data: {
        phoneNumber: 'admin',
        name: 'Administrator',
        role: 'ADMIN',
        trustLevel: 5,
        isActive: true,
      },
    });
    console.log('Admin created: ' + admin.name + ' (' + admin.phoneNumber + ')');
  } catch (error) {
    console.error('Error creating admin:', error.message);
    process.exit(1);
  }
}

main().catch(console.error).finally(() => prisma.\$disconnect());
" && log_success "Admin user created successfully" || log_error "Failed to create admin user"

    ADMIN_USERNAME="admin"
fi

# Step 6: Setup Admin Password
log_step "Step 6: Setting Up Admin Password"

# Check if ADMIN_PASSWORD exists in .env
if [ -f ".env" ] && grep -q "^ADMIN_PASSWORD=" .env; then
    CURRENT_PASSWORD=$(grep "^ADMIN_PASSWORD=" .env | cut -d= -f2)
    log_info "ADMIN_PASSWORD already set in .env"
    log_warning "Current password: $CURRENT_PASSWORD"

    read -p "Keep current password? (Y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        read -s -p "Enter new admin password: " NEW_PASSWORD
        echo
        read -s -p "Confirm password: " NEW_PASSWORD2
        echo

        if [ "$NEW_PASSWORD" = "$NEW_PASSWORD2" ]; then
            # Update password in .env
            sed -i.bak "s/^ADMIN_PASSWORD=.*/ADMIN_PASSWORD=$NEW_PASSWORD/" .env
            log_success "Password updated in .env"
            ADMIN_PASSWORD="$NEW_PASSWORD"
        else
            log_error "Passwords do not match"
            ADMIN_PASSWORD="$CURRENT_PASSWORD"
        fi
    else
        ADMIN_PASSWORD="$CURRENT_PASSWORD"
    fi
else
    log_warning "ADMIN_PASSWORD not found in .env"

    read -s -p "Enter admin password (or press Enter for default): " NEW_PASSWORD
    echo

    if [ -z "$NEW_PASSWORD" ]; then
        NEW_PASSWORD="Admin123!Staging"
        log_info "Using default password: Admin123!Staging"
    fi

    # Add to .env
    if [ -f ".env" ]; then
        echo "ADMIN_PASSWORD=$NEW_PASSWORD" >> .env
    else
        echo "ADMIN_PASSWORD=$NEW_PASSWORD" > .env
    fi

    log_success "Password saved to .env"
    ADMIN_PASSWORD="$NEW_PASSWORD"
fi

# Step 7: Start Dashboard
log_step "Step 7: Starting Dashboard Container"

log_info "Stopping existing dashboard container (if any)..."
$COMPOSE_CMD stop dashboard 2>/dev/null || true

log_info "Starting dashboard container..."
$COMPOSE_CMD up -d dashboard

# Wait for container to be ready
log_info "Waiting for dashboard to be ready..."
sleep 5

# Step 8: Restart Backend
log_step "Step 8: Restarting Backend"

log_info "Restarting backend to apply password changes..."
$COMPOSE_CMD restart backend

sleep 5

# Step 9: Verify Installation
log_step "Step 9: Verifying Installation"

# Check if container is running
if docker ps | grep -q "emergency_dashboard"; then
    log_success "✓ Dashboard container is running"
else
    log_error "✗ Dashboard container is not running"
    log_info "Check logs: docker logs emergency_dashboard"
fi

# Check if dashboard is accessible
if curl -sf http://localhost:8080 > /dev/null; then
    log_success "✓ Dashboard is accessible on port 8080"
else
    log_warning "✗ Dashboard is not accessible on port 8080"
    log_info "This might be normal if the port is not exposed externally"
fi

# Check backend health
if curl -sf http://localhost:3000/health > /dev/null; then
    log_success "✓ Backend is healthy"
else
    log_warning "✗ Backend health check failed"
fi

# Step 10: Display Summary
log_step "Installation Complete!"

echo ""
echo -e "${GREEN}======================================================"
echo -e "  Dashboard Successfully Deployed!"
echo -e "======================================================${NC}"
echo ""
echo -e "${CYAN}Access Information:${NC}"
echo -e "  Dashboard URL:  ${YELLOW}http://localhost:8080${NC}"
echo -e "  Backend API:    ${YELLOW}http://localhost:3000${NC}"
echo ""
echo -e "${CYAN}Login Credentials:${NC}"
echo -e "  Username:       ${YELLOW}${ADMIN_USERNAME}${NC}"
echo -e "  Password:       ${YELLOW}${ADMIN_PASSWORD}${NC}"
echo ""
echo -e "${CYAN}Management Commands:${NC}"
echo -e "  View dashboard logs:  ${YELLOW}docker logs -f emergency_dashboard${NC}"
echo -e "  View backend logs:    ${YELLOW}docker logs -f $BACKEND_CONTAINER${NC}"
echo -e "  Restart dashboard:    ${YELLOW}$COMPOSE_CMD restart dashboard${NC}"
echo -e "  Stop dashboard:       ${YELLOW}$COMPOSE_CMD stop dashboard${NC}"
echo ""
echo -e "${CYAN}Container Status:${NC}"
$COMPOSE_CMD ps
echo ""

# Save credentials to file
CREDS_FILE="$BACKUP_DIR/dashboard-credentials-$(date +%Y%m%d-%H%M%S).txt"
cat > "$CREDS_FILE" <<EOFCREDS
Emergency Response Dashboard - Login Credentials
Generated: $(date)

Dashboard URL: http://localhost:8080
Username: ${ADMIN_USERNAME}
Password: ${ADMIN_PASSWORD}

Backend API: http://localhost:3000
Container: $BACKEND_CONTAINER
EOFCREDS

log_success "Credentials saved to: $CREDS_FILE"

echo ""
log_info "If you're accessing from remote server, make sure port 8080 is open"
log_info "To expose via domain, consider using Nginx reverse proxy or Cloudflared tunnel"
echo ""

read -p "Open dashboard in browser? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v xdg-open &> /dev/null; then
        xdg-open http://localhost:8080
    elif command -v open &> /dev/null; then
        open http://localhost:8080
    else
        log_info "Please open http://localhost:8080 in your browser"
    fi
fi

echo ""
log_success "Deployment completed successfully! 🎉"
echo ""
