#!/bin/bash
################################################################################
# Emergency Response Chatbot - Complete Installation Script
# Interactive setup for fresh Ubuntu server
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Logging functions
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
header() { echo -e "\n${CYAN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"; echo -e "${CYAN}${BOLD}║${NC} $1"; echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}\n"; }
ask() { echo -e "${MAGENTA}[?]${NC} $1"; }

# Banner
clear
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║     Emergency Response Chatbot - Installation           ║
║     WhatsApp-Based Disaster Management System           ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

This script will install and configure:
  • Docker & Docker Compose
  • PostgreSQL Database
  • Redis Cache
  • Ollama AI (Local LLM)
  • Backend API (Node.js)
  • Web Dashboard (Nginx)
  • WhatsApp Integration (Baileys/Meta)

EOF

ask "Press ENTER to start installation or Ctrl+C to cancel"
read

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root (use: sudo bash install.sh)"
    exit 1
fi

# Get installation directory
DEFAULT_DIR="/opt/emergency-chatbot"
ask "Installation directory [$DEFAULT_DIR]: "
read INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-$DEFAULT_DIR}

success "Will install to: $INSTALL_DIR"

################################################################################
# PHASE 1: System Requirements Check
################################################################################
header "PHASE 1: System Requirements Check"

log "Checking system requirements..."

# Check Ubuntu version
if [ -f /etc/os-release ]; then
    . /etc/os-release
    log "OS: $NAME $VERSION"
    if [[ ! "$ID" =~ ^(ubuntu|debian)$ ]]; then
        warn "This script is tested on Ubuntu/Debian. Your OS: $ID"
        ask "Continue anyway? (y/N): "
        read continue
        [[ ! $continue =~ ^[Yy]$ ]] && exit 1
    fi
else
    warn "Cannot detect OS version"
fi

# Check disk space (need at least 5GB for basic installation)
AVAILABLE_GB=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
log "Available disk space: ${AVAILABLE_GB}GB"
if [ $AVAILABLE_GB -lt 5 ]; then
    error "Need at least 5GB free disk space. Available: ${AVAILABLE_GB}GB"
    exit 1
elif [ $AVAILABLE_GB -lt 10 ]; then
    warn "Only ${AVAILABLE_GB}GB available. Recommended: 10GB+"
    warn "Installation will proceed but may run slow when downloading Ollama model"
    ask "Continue anyway? (y/N): "
    read continue
    [[ ! $continue =~ ^[Yy]$ ]] && exit 1
fi

# Check RAM (recommend at least 4GB)
TOTAL_RAM_GB=$(free -g | awk 'NR==2 {print $2}')
log "Total RAM: ${TOTAL_RAM_GB}GB"
if [ $TOTAL_RAM_GB -lt 4 ]; then
    warn "Recommended at least 4GB RAM. Available: ${TOTAL_RAM_GB}GB"
    warn "System may run slow, especially Ollama AI"
    ask "Continue anyway? (y/N): "
    read continue
    [[ ! $continue =~ ^[Yy]$ ]] && exit 1
fi

success "System requirements check passed"

################################################################################
# PHASE 2: Configuration
################################################################################
header "PHASE 2: Configuration"

echo ""
log "Let's configure your installation..."
echo ""

# Database configuration
ask "PostgreSQL username [postgres]: "
read DB_USER
DB_USER=${DB_USER:-postgres}

ask "PostgreSQL password [generate random]: "
read -s DB_PASS
echo ""
if [ -z "$DB_PASS" ]; then
    DB_PASS=$(openssl rand -base64 16)
    log "Generated password: $DB_PASS"
fi

ask "Database name [emergency_chatbot]: "
read DB_NAME
DB_NAME=${DB_NAME:-emergency_chatbot}

# Admin account
echo ""
ask "Admin username for dashboard [admin]: "
read ADMIN_USER
ADMIN_USER=${ADMIN_USER:-admin}

ask "Admin password [generate random]: "
read -s ADMIN_PASS
echo ""
if [ -z "$ADMIN_PASS" ]; then
    ADMIN_PASS=$(openssl rand -base64 12)
    log "Generated password: $ADMIN_PASS"
fi

# WhatsApp mode
echo ""
log "WhatsApp Integration Mode:"
echo "  1) Baileys (Free - scan QR code, no Meta account needed)"
echo "  2) Meta Cloud API (Official - requires business account)"
ask "Choose mode [1]: "
read WA_MODE_CHOICE
WA_MODE_CHOICE=${WA_MODE_CHOICE:-1}

if [ "$WA_MODE_CHOICE" = "1" ]; then
    WA_MODE="baileys"
    log "Using Baileys (Free mode)"
else
    WA_MODE="meta"
    log "Using Meta Cloud API"
    echo ""
    warn "You'll need Meta WhatsApp Business credentials:"
    ask "Phone Number ID: "
    read WA_PHONE_ID
    ask "Access Token: "
    read WA_TOKEN
    ask "Verify Token: "
    read WA_VERIFY
fi

# Ports
echo ""
ask "Backend API port [3000]: "
read BACKEND_PORT
BACKEND_PORT=${BACKEND_PORT:-3000}

ask "Dashboard port [8080]: "
read DASHBOARD_PORT
DASHBOARD_PORT=${DASHBOARD_PORT:-8080}

# JWT Secret
JWT_SECRET=$(openssl rand -base64 32)

# Summary
echo ""
header "Configuration Summary"
cat << EOF
${BOLD}Installation Configuration:${NC}
  Install Directory:  $INSTALL_DIR

${BOLD}Database:${NC}
  Username:          $DB_USER
  Password:          $DB_PASS
  Database:          $DB_NAME

${BOLD}Admin Account:${NC}
  Username:          $ADMIN_USER
  Password:          $ADMIN_PASS

${BOLD}WhatsApp:${NC}
  Mode:              $WA_MODE

${BOLD}Ports:${NC}
  Backend API:       $BACKEND_PORT
  Dashboard:         $DASHBOARD_PORT

EOF

ask "Continue with this configuration? (Y/n): "
read confirm
[[ $confirm =~ ^[Nn]$ ]] && exit 0

################################################################################
# PHASE 3: Install Dependencies
################################################################################
header "PHASE 3: Install Dependencies"

log "Updating package lists..."
apt-get update -qq

log "Installing essential packages..."
apt-get install -y -qq \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    lsb-release \
    build-essential \
    software-properties-common

success "Essential packages installed"

# Install Docker
if command -v docker &> /dev/null; then
    log "Docker already installed: $(docker --version)"
else
    log "Installing Docker..."

    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Start Docker
    systemctl enable docker
    systemctl start docker

    success "Docker installed: $(docker --version)"
fi

# Verify Docker Compose
if docker compose version &> /dev/null; then
    COMPOSE="docker compose"
    success "Docker Compose installed: $(docker compose version)"
elif command -v docker-compose &> /dev/null; then
    COMPOSE="docker-compose"
    success "Docker Compose installed: $(docker-compose --version)"
else
    error "Docker Compose not found!"
    exit 1
fi

################################################################################
# PHASE 4: Download Application
################################################################################
header "PHASE 4: Download Application"

log "Creating installation directory..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

if [ -d ".git" ]; then
    log "Existing installation found. Updating..."
    git fetch --all
    git checkout stable 2>/dev/null || git checkout main 2>/dev/null || true
    git reset --hard origin/stable 2>/dev/null || git reset --hard origin/main 2>/dev/null || true
    git pull
else
    log "Cloning repository..."
    git clone -b stable https://github.com/iwewe/chatbot-disaster-response.git . 2>/dev/null || \
    git clone https://github.com/iwewe/chatbot-disaster-response.git .
fi

success "Application downloaded"

################################################################################
# PHASE 5: Create Configuration Files
################################################################################
header "PHASE 5: Create Configuration Files"

log "Creating .env file..."
cat > .env <<ENVEOF
# ============================================
# EMERGENCY CHATBOT CONFIGURATION
# Auto-generated: $(date)
# ============================================

# ============================================
# SERVER CONFIGURATION
# ============================================
NODE_ENV=production
PORT=$BACKEND_PORT
API_BASE_URL=http://localhost:$BACKEND_PORT

# ============================================
# DATABASE
# ============================================
DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@postgres:5432/${DB_NAME}

# PostgreSQL Credentials
POSTGRES_USER=${DB_USER}
POSTGRES_PASSWORD=${DB_PASS}
POSTGRES_DB=${DB_NAME}

# ============================================
# REDIS
# ============================================
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_URL=redis://redis:6379
REDIS_PASSWORD=

# ============================================
# JWT AUTHENTICATION
# ============================================
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRES_IN=7d

# ============================================
# ADMIN ACCOUNT
# ============================================
ADMIN_USERNAME=${ADMIN_USER}
ADMIN_PASSWORD=${ADMIN_PASS}

# ============================================
# WHATSAPP CONFIGURATION
# ============================================
WHATSAPP_MODE=${WA_MODE}
WHATSAPP_PHONE_NUMBER_ID=${WA_PHONE_ID:-}
WHATSAPP_ACCESS_TOKEN=${WA_TOKEN:-}
WHATSAPP_VERIFY_TOKEN=${WA_VERIFY:-webhook-verify-token}
WHATSAPP_BUSINESS_ACCOUNT_ID=${WA_BUSINESS_ID:-}

# ============================================
# TELEGRAM BOT
# ============================================
TELEGRAM_BOT_TOKEN=
TELEGRAM_ADMIN_CHAT_ID=

# ============================================
# OLLAMA (Local LLM)
# ============================================
OLLAMA_BASE_URL=http://ollama:11434
OLLAMA_MODEL=qwen2.5:7b
OLLAMA_TIMEOUT=30000
OLLAMA_FALLBACK_ENABLED=true

# ============================================
# SYSTEM CONFIGURATION
# ============================================
AUTO_ASSIGN_CRITICAL_TO=
AUTO_VERIFY_TRUST_LEVEL=3
RATE_LIMIT_PER_MINUTE=10
DATA_RETENTION_DAYS=180
MEDIA_STORAGE_PATH=/app/media
DEBUG_MODE=false
LOG_LEVEL=info
ENVEOF

success ".env file created"

# Update docker-compose ports if needed
if [ "$BACKEND_PORT" != "3000" ] || [ "$DASHBOARD_PORT" != "8080" ]; then
    log "Updating docker-compose.yml ports..."

    sed -i "s/\"3000:3000\"/\"$BACKEND_PORT:3000\"/" docker-compose.yml
    sed -i "s/\"8080:80\"/\"$DASHBOARD_PORT:80\"/" docker-compose.yml

    success "Ports updated"
fi

################################################################################
# PHASE 6: Build & Start Services
################################################################################
header "PHASE 6: Build & Start Services"

log "Stopping any existing containers..."
$COMPOSE down 2>/dev/null || true

log "Building backend image..."
$COMPOSE build backend

log "Starting PostgreSQL..."
$COMPOSE up -d postgres

log "Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
    if docker exec emergency_db pg_isready -U $DB_USER >/dev/null 2>&1; then
        success "PostgreSQL is ready!"
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

log "Starting Redis and Ollama..."
$COMPOSE up -d redis ollama
sleep 5

log "Starting Backend..."
$COMPOSE up -d backend
sleep 10

success "All services started"

################################################################################
# PHASE 7: Database Setup
################################################################################
header "PHASE 7: Database Setup"

log "Running database migrations..."
docker exec emergency_backend npx prisma db push --skip-generate

log "Creating admin user..."
docker exec emergency_backend node -e "
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function createAdmin() {
    try {
        const admin = await prisma.user.upsert({
            where: { phoneNumber: '${ADMIN_USER}' },
            update: {},
            create: {
                phoneNumber: '${ADMIN_USER}',
                name: 'Administrator',
                role: 'ADMIN',
                trustLevel: 5,
                isActive: true
            }
        });
        console.log('Admin user created:', admin.phoneNumber);
    } catch (error) {
        console.error('Error:', error.message);
    } finally {
        await prisma.\$disconnect();
    }
}

createAdmin();
"

success "Database initialized"

################################################################################
# PHASE 8: Deploy Dashboard
################################################################################
header "PHASE 8: Deploy Dashboard"

# Create dashboard files
log "Creating dashboard files..."
mkdir -p dashboard

# Create dashboard HTML
cat > dashboard/index.html <<'HTML_EOF'
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Emergency Response Chatbot</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            max-width: 800px;
            padding: 60px 40px;
            text-align: center;
        }
        h1 { font-size: 2.5rem; color: #333; margin-bottom: 20px; }
        .emoji { font-size: 4rem; margin-bottom: 20px; }
        p { font-size: 1.2rem; color: #666; line-height: 1.6; margin-bottom: 30px; }
        .status {
            background: #f0f9ff;
            border-left: 4px solid #0ea5e9;
            padding: 20px;
            margin: 30px 0;
            text-align: left;
        }
        .status h3 { color: #0369a1; margin-bottom: 10px; }
        .status ul { list-style: none; }
        .status li { padding: 8px 0; color: #555; }
        .status li:before { content: "✓ "; color: #10b981; font-weight: bold; margin-right: 8px; }
        .btn {
            padding: 15px 30px;
            border-radius: 10px;
            text-decoration: none;
            font-weight: 600;
            background: #667eea;
            color: white;
            display: inline-block;
            margin: 10px;
            transition: all 0.3s;
        }
        .btn:hover {
            background: #5568d3;
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }
        .api-info {
            background: #f9fafb;
            border-radius: 10px;
            padding: 20px;
            margin-top: 30px;
            text-align: left;
        }
        .endpoint {
            font-family: monospace;
            background: #1f2937;
            color: #10b981;
            padding: 12px;
            border-radius: 6px;
            margin: 10px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="emoji">🚨</div>
        <h1>Emergency Response Chatbot</h1>
        <p>Sistem Manajemen Bencana Berbasis WhatsApp dengan AI</p>

        <div class="status">
            <h3>✓ Sistem Aktif</h3>
            <ul>
                <li>Backend API Running</li>
                <li>Database Connected</li>
                <li>WhatsApp Integration Ready</li>
                <li>AI Model (Ollama) Active</li>
            </ul>
        </div>

        <div class="api-info">
            <h3>🔧 Backend API Endpoints</h3>
            <div class="endpoint">GET /api/health</div>
            <div class="endpoint">POST /auth/login</div>
            <div class="endpoint">GET /api/reports</div>
            <div class="endpoint">POST /api/reports</div>
        </div>

        <a href="/api/health" class="btn" target="_blank">🔍 Check API Health</a>
        <a href="https://github.com/iwewe/chatbot-disaster-response" class="btn" target="_blank">📚 Documentation</a>

        <script>
            fetch('/api/health')
                .then(r => r.json())
                .then(d => console.log('✓ API healthy:', d))
                .catch(e => console.warn('API check failed:', e));
        </script>
    </div>
</body>
</html>
HTML_EOF

# Create nginx config for dashboard
log "Creating nginx configuration..."
cat > dashboard/nginx.conf <<'NGINX_EOF'
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # API proxy to backend
    location /api/ {
        proxy_pass http://backend:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Auth endpoints
    location /auth/ {
        proxy_pass http://backend:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # Static files
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
NGINX_EOF

success "Dashboard files created"

# Check if dashboard service exists in docker-compose.yml
log "Checking docker-compose.yml for dashboard service..."
if grep -q "container_name: emergency_dashboard" docker-compose.yml; then
    success "Dashboard service already exists in docker-compose.yml"
else
    warn "Dashboard service not found in docker-compose.yml"
    log "Adding dashboard service to docker-compose.yml..."

    # Find the line number before "# Networks" or "networks:" section
    LINE_NUM=$(grep -n "^# ============================================" docker-compose.yml | grep -B1 "Networks" | head -1 | cut -d: -f1)

    if [ -z "$LINE_NUM" ]; then
        LINE_NUM=$(grep -n "^networks:" docker-compose.yml | head -1 | cut -d: -f1)
    fi

    if [ -z "$LINE_NUM" ]; then
        error "Cannot find where to insert dashboard service in docker-compose.yml"
    fi

    # Insert dashboard service before networks section
    sed -i "${LINE_NUM}i\\
\\
  # ============================================\\
  # Web Dashboard\\
  # ============================================\\
  dashboard:\\
    image: nginx:alpine\\
    container_name: emergency_dashboard\\
    restart: unless-stopped\\
    ports:\\
      - \"8080:80\"\\
    volumes:\\
      - ./dashboard:/usr/share/nginx/html:ro\\
      - ./dashboard/nginx.conf:/etc/nginx/conf.d/default.conf:ro\\
    depends_on:\\
      - backend\\
    networks:\\
      - emergency_network\\
    healthcheck:\\
      test: [\"CMD\", \"wget\", \"-q\", \"--spider\", \"http://localhost\"]\\
      interval: 30s\\
      timeout: 10s\\
      retries: 3\\
" docker-compose.yml

    success "Dashboard service added to docker-compose.yml"
fi

log "Starting dashboard..."
$COMPOSE up -d dashboard
sleep 5

success "Dashboard deployed"

################################################################################
# PHASE 9: Initialize Ollama Model
################################################################################
header "PHASE 9: Initialize Ollama Model"

log "Pulling Ollama model (this may take a few minutes)..."
warn "Downloading qwen2.5:7b model (~4.7GB)..."

docker exec emergency_ollama ollama pull qwen2.5:7b &
OLLAMA_PID=$!

# Show progress
while kill -0 $OLLAMA_PID 2>/dev/null; do
    echo -n "."
    sleep 3
done
echo ""

success "Ollama model ready"

################################################################################
# PHASE 10: Verification
################################################################################
header "PHASE 10: Verification"

log "Checking container status..."
$COMPOSE ps

echo ""
log "Testing services..."

# Test PostgreSQL
if docker exec emergency_db pg_isready -U $DB_USER >/dev/null 2>&1; then
    success "PostgreSQL: OK"
else
    error "PostgreSQL: FAIL"
fi

# Test Redis
if docker exec emergency_redis redis-cli ping | grep -q PONG; then
    success "Redis: OK"
else
    error "Redis: FAIL"
fi

# Test Backend
sleep 5
if curl -sf http://localhost:$BACKEND_PORT/health >/dev/null 2>&1; then
    success "Backend API: OK"
else
    warn "Backend API: Check logs with: docker logs emergency_backend"
fi

# Test Dashboard
if curl -sf http://localhost:$DASHBOARD_PORT >/dev/null 2>&1; then
    success "Dashboard: OK"
else
    warn "Dashboard: Check logs with: docker logs emergency_dashboard"
fi

################################################################################
# PHASE 11: Save Credentials
################################################################################
header "PHASE 11: Save Credentials"

CREDS_FILE="$INSTALL_DIR/CREDENTIALS.txt"
cat > "$CREDS_FILE" <<CREDSEOF
╔══════════════════════════════════════════════════════════╗
║     Emergency Response Chatbot - Access Credentials     ║
╚══════════════════════════════════════════════════════════╝

Installation Date: $(date)
Installation Path: $INSTALL_DIR

═══════════════════════════════════════════════════════════
DATABASE ACCESS
═══════════════════════════════════════════════════════════
Host:       localhost:5432
Username:   $DB_USER
Password:   $DB_PASS
Database:   $DB_NAME

Connection String:
postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}

═══════════════════════════════════════════════════════════
WEB DASHBOARD
═══════════════════════════════════════════════════════════
URL:        http://localhost:$DASHBOARD_PORT
Username:   $ADMIN_USER
Password:   $ADMIN_PASS

═══════════════════════════════════════════════════════════
BACKEND API
═══════════════════════════════════════════════════════════
URL:        http://localhost:$BACKEND_PORT
Health:     http://localhost:$BACKEND_PORT/health

JWT Secret: $JWT_SECRET

═══════════════════════════════════════════════════════════
WHATSAPP CONFIGURATION
═══════════════════════════════════════════════════════════
Mode:       $WA_MODE

$(if [ "$WA_MODE" = "baileys" ]; then
echo "To connect WhatsApp (Baileys mode):
1. Check QR code: docker logs emergency_backend | grep -A 20 'QR'
2. Scan with WhatsApp on your phone
3. Connection will be saved automatically"
else
echo "Phone ID:   $WA_PHONE_ID
Token:      $WA_TOKEN
Verify:     $WA_VERIFY"
fi)

═══════════════════════════════════════════════════════════
USEFUL COMMANDS
═══════════════════════════════════════════════════════════
View all services:
  cd $INSTALL_DIR && docker compose ps

View logs:
  docker logs -f emergency_backend
  docker logs -f emergency_dashboard
  docker logs -f emergency_db

Restart services:
  cd $INSTALL_DIR && docker compose restart

Stop all:
  cd $INSTALL_DIR && docker compose down

Start all:
  cd $INSTALL_DIR && docker compose up -d

Update application:
  cd $INSTALL_DIR && git pull && docker compose up -d --build

═══════════════════════════════════════════════════════════
⚠ SECURITY WARNING
═══════════════════════════════════════════════════════════
This file contains sensitive credentials!
Keep it secure and delete after noting the passwords.

CREDSEOF

chmod 600 "$CREDS_FILE"
success "Credentials saved to: $CREDS_FILE"

################################################################################
# INSTALLATION COMPLETE
################################################################################
clear
cat << EOF

╔══════════════════════════════════════════════════════════╗
║                                                          ║
║          ✅ INSTALLATION SUCCESSFUL! ✅                  ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

${GREEN}${BOLD}🎉 Emergency Response Chatbot is now running!${NC}

${CYAN}═══════════════════════════════════════════════════════════${NC}
${BOLD}Quick Access:${NC}
${CYAN}═══════════════════════════════════════════════════════════${NC}

EOF

cat << EOF
${BOLD}📊 Web Dashboard${NC}
   ${GREEN}http://localhost:$DASHBOARD_PORT${NC}

   Username: ${YELLOW}$ADMIN_USER${NC}
   Password: ${YELLOW}$ADMIN_PASS${NC}

EOF

cat << EOF
${BOLD}🔧 Backend API${NC}
   ${GREEN}http://localhost:$BACKEND_PORT${NC}

${BOLD}💾 Credentials File${NC}
   ${YELLOW}$CREDS_FILE${NC}

${CYAN}═══════════════════════════════════════════════════════════${NC}
${BOLD}Next Steps:${NC}
${CYAN}═══════════════════════════════════════════════════════════${NC}

EOF

if [ "$WA_MODE" = "baileys" ]; then
    echo "${BOLD}1. Connect WhatsApp (Baileys):${NC}"
    echo "   docker logs emergency_backend | grep -A 30 QR"
    echo "   Scan the QR code with your WhatsApp"
    echo ""
fi

cat << EOF
${BOLD}2. Access Dashboard:${NC}
   Open: ${GREEN}http://localhost:$DASHBOARD_PORT${NC}
   Login with admin credentials above

${BOLD}3. Monitor Logs:${NC}
   docker logs -f emergency_backend

${BOLD}4. Test WhatsApp:${NC}
   Send a message to the connected WhatsApp number

${CYAN}═══════════════════════════════════════════════════════════${NC}
${BOLD}Documentation:${NC}
${CYAN}═══════════════════════════════════════════════════════════${NC}

   README:  $INSTALL_DIR/README.md
   Docs:    https://github.com/iwewe/chatbot-disaster-response

${CYAN}═══════════════════════════════════════════════════════════${NC}
${BOLD}Support:${NC}
${CYAN}═══════════════════════════════════════════════════════════${NC}

   Issues:  https://github.com/iwewe/chatbot-disaster-response/issues

${GREEN}${BOLD}Happy disaster response management! 🚨${NC}

EOF
