#!/bin/bash
################################################################################
# Emergency Response System - Dashboard Deployment Script
# Deploys the web dashboard using Nginx or Docker
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
DASHBOARD_DIR="$INSTALL_DIR/dashboard"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
SITE_NAME="emergency-dashboard"

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

# Check if dashboard directory exists
if [ ! -d "$DASHBOARD_DIR" ]; then
    log_error "Dashboard directory not found: $DASHBOARD_DIR"
    log_info "Please run deploy-git.sh or deploy-curl.sh first"
    exit 1
fi

# Display deployment options
echo "======================================================"
echo "  Emergency Response Dashboard Deployment"
echo "======================================================"
echo ""
echo "Choose deployment method:"
echo "  1) Nginx (Recommended for production)"
echo "  2) Docker Nginx"
echo "  3) Simple HTTP Server (Development only)"
echo ""
read -p "Enter choice [1-3]: " DEPLOY_METHOD

case $DEPLOY_METHOD in
    1)
        #######################################
        # NGINX DEPLOYMENT
        #######################################
        log_info "Deploying with Nginx..."

        # Check if nginx is installed
        if ! command -v nginx &> /dev/null; then
            log_warning "Nginx is not installed. Installing..."
            sudo apt update
            sudo apt install -y nginx
        fi

        # Get domain/IP
        read -p "Enter domain or IP (e.g., emresc.iwewe.web.id or localhost): " DOMAIN
        DOMAIN=${DOMAIN:-localhost}

        # Get port
        read -p "Enter port [80]: " PORT
        PORT=${PORT:-80}

        # Get backend URL
        read -p "Enter backend URL [http://localhost:3000]: " BACKEND_URL
        BACKEND_URL=${BACKEND_URL:-http://localhost:3000}

        # Copy dashboard to web root
        WEB_ROOT="/var/www/html/$SITE_NAME"
        log_info "Copying dashboard files to $WEB_ROOT..."
        sudo mkdir -p "$WEB_ROOT"
        sudo cp -r "$DASHBOARD_DIR"/* "$WEB_ROOT/"
        sudo chown -R www-data:www-data "$WEB_ROOT"

        # Create Nginx configuration
        log_info "Creating Nginx configuration..."
        sudo tee "$NGINX_AVAILABLE/$SITE_NAME" > /dev/null <<EOF
server {
    listen $PORT;
    server_name $DOMAIN;

    root $WEB_ROOT;
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
        try_files \$uri \$uri/ /index.html;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Proxy API requests to backend
    location /api/ {
        proxy_pass $BACKEND_URL;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Proxy auth requests to backend
    location /auth/ {
        proxy_pass $BACKEND_URL;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Proxy webhook requests to backend
    location /webhook {
        proxy_pass $BACKEND_URL;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Logs
    access_log /var/log/nginx/${SITE_NAME}-access.log;
    error_log /var/log/nginx/${SITE_NAME}-error.log;
}
EOF

        # Enable site
        sudo ln -sf "$NGINX_AVAILABLE/$SITE_NAME" "$NGINX_ENABLED/$SITE_NAME"

        # Test nginx configuration
        log_info "Testing Nginx configuration..."
        sudo nginx -t

        # Reload nginx
        log_info "Reloading Nginx..."
        sudo systemctl reload nginx

        # Enable nginx on boot
        sudo systemctl enable nginx

        log_success "Dashboard deployed successfully!"
        echo ""
        echo "======================================================"
        echo "  Dashboard URL: http://$DOMAIN:$PORT"
        echo "======================================================"
        echo ""
        log_info "To enable HTTPS, run: sudo certbot --nginx -d $DOMAIN"
        ;;

    2)
        #######################################
        # DOCKER NGINX DEPLOYMENT
        #######################################
        log_info "Deploying with Docker Nginx..."

        cd "$INSTALL_DIR"

        # Create nginx config for dashboard
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
}
EOF

        # Add dashboard service to docker-compose.yml if not exists
        if ! grep -q "dashboard:" docker-compose.yml; then
            log_info "Adding dashboard service to docker-compose.yml..."

            # Backup docker-compose.yml
            cp docker-compose.yml docker-compose.yml.backup

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

        # Use docker compose or docker-compose
        if command -v docker &> /dev/null && docker compose version &> /dev/null; then
            COMPOSE_CMD="docker compose"
        else
            COMPOSE_CMD="docker-compose"
        fi

        # Start dashboard container
        log_info "Starting dashboard container..."
        $COMPOSE_CMD up -d dashboard

        log_success "Dashboard deployed successfully!"
        echo ""
        echo "======================================================"
        echo "  Dashboard URL: http://localhost:8080"
        echo "======================================================"
        echo ""
        log_info "To change port, edit docker-compose.yml and restart"
        ;;

    3)
        #######################################
        # SIMPLE HTTP SERVER (Development)
        #######################################
        log_info "Starting simple HTTP server (Development mode)..."

        # Get port
        read -p "Enter port [8000]: " PORT
        PORT=${PORT:-8000}

        cd "$DASHBOARD_DIR"

        log_warning "This is for development only!"
        log_info "Starting server on http://localhost:$PORT"
        echo ""
        echo "Press Ctrl+C to stop the server"
        echo ""

        # Check if python3 is available
        if command -v python3 &> /dev/null; then
            python3 -m http.server $PORT
        elif command -v python &> /dev/null; then
            python -m SimpleHTTPServer $PORT
        else
            log_error "Python is not installed. Cannot start HTTP server."
            log_info "Please use Nginx deployment instead."
            exit 1
        fi
        ;;

    *)
        log_error "Invalid choice"
        exit 1
        ;;
esac
