#!/bin/bash

#==============================================================================
# Emergency Response Dashboard Update Script
#==============================================================================
# Updates dashboard files from GitHub repository
# Usage: bash update-dashboard.sh
#==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

ask() {
    echo -en "${YELLOW}$1${NC}"
}

#==============================================================================
# Main Script
#==============================================================================

echo "=================================================="
echo "  Emergency Response Dashboard Update"
echo "=================================================="
echo ""

# Get current directory
CURRENT_DIR=$(pwd)

# Check if we're in the project directory
if [ ! -f "docker-compose.yml" ]; then
    error "docker-compose.yml not found. Please run this script from the project root directory."
fi

# Check if dashboard directory exists
if [ ! -d "dashboard" ]; then
    log "Creating dashboard directory..."
    mkdir -p dashboard
fi

# Backup existing dashboard files
BACKUP_DIR="dashboard_backup_$(date +%Y%m%d_%H%M%S)"
if [ -d "dashboard" ] && [ "$(ls -A dashboard)" ]; then
    log "Backing up existing dashboard files to $BACKUP_DIR..."
    cp -r dashboard "$BACKUP_DIR"
    success "Backup created at $BACKUP_DIR"
fi

# Get the branch name
BRANCH="claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf"

# Ask user if they want to pull from git
ask "Do you want to pull latest changes from git? (y/N): "
read -r pull_git

if [[ $pull_git =~ ^[Yy]$ ]]; then
    log "Pulling latest changes from git..."
    if git pull origin "$BRANCH"; then
        success "Git pull completed successfully"
    else
        warn "Git pull failed or had conflicts. Continuing with manual file update..."
    fi
else
    log "Skipping git pull. Will update dashboard files manually..."

    # GitHub raw content base URL
    GITHUB_RAW="https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/$BRANCH/dashboard"

    log "Downloading dashboard files from GitHub..."

    # Download each file
    files=(
        "index.html"
        "dashboard.html"
        "reports.html"
        "create-report.html"
        "public-form.html"
        "nginx.conf"
    )

    for file in "${files[@]}"; do
        log "Downloading $file..."
        if wget -q -O "dashboard/$file" "$GITHUB_RAW/$file" 2>/dev/null; then
            success "Downloaded $file"
        else
            warn "Failed to download $file (file may not exist on remote)"
        fi
    done
fi

# Verify dashboard files exist
log "Verifying dashboard files..."
required_files=(
    "dashboard/index.html"
    "dashboard/dashboard.html"
    "dashboard/reports.html"
    "dashboard/create-report.html"
    "dashboard/public-form.html"
)

missing_files=0
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        error "Required file missing: $file"
        missing_files=1
    fi
done

if [ $missing_files -eq 0 ]; then
    success "All required dashboard files are present"
fi

# Create nginx.conf if it doesn't exist
if [ ! -f "dashboard/nginx.conf" ]; then
    log "Creating nginx.conf..."
    cat > dashboard/nginx.conf <<'EOF'
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # Enable gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # API proxy to backend
    location /api/ {
        proxy_pass http://backend:3000/api/;
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
        proxy_pass http://backend:3000/auth/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # SPA fallback
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF
    success "Created nginx.conf"
fi

# Restart dashboard service
log "Restarting dashboard service..."
if docker compose restart dashboard 2>/dev/null || docker-compose restart dashboard 2>/dev/null; then
    success "Dashboard service restarted successfully"
else
    error "Failed to restart dashboard service. Please check Docker Compose."
fi

# Wait for service to be ready
log "Waiting for dashboard to be ready..."
sleep 3

# Check if dashboard is accessible
log "Checking dashboard accessibility..."
if curl -f -s http://localhost:8080 > /dev/null; then
    success "Dashboard is accessible at http://localhost:8080"
else
    warn "Dashboard may not be fully ready yet. Please check manually."
fi

echo ""
echo "=================================================="
echo "  Dashboard Update Complete!"
echo "=================================================="
echo ""
echo "📊 Dashboard URLs:"
echo "   • Main Dashboard: http://localhost:8080"
echo "   • Login Page: http://localhost:8080/index.html"
echo "   • Public Form: http://localhost:8080/public-form.html"
echo ""
echo "🔐 Demo Credentials:"
echo "   Username: admin"
echo "   Password: Admin123!Staging"
echo ""
echo "📁 Backup Location: $BACKUP_DIR"
echo ""
success "All updates completed successfully!"
