#!/bin/bash
################################################################################
# Fix Dashboard API Proxy - Solve "Unexpected token" JSON error
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}►${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }

echo "Fixing Dashboard API Proxy Issue"
echo "================================="
echo ""

# Check if we're in the right directory
[ ! -f "docker-compose.yml" ] && error "Run this from project root directory!"

# Detect compose command
if docker compose version >/dev/null 2>&1; then
    COMPOSE="docker compose"
else
    COMPOSE="docker-compose"
fi

# Step 1: Check backend is running and accessible
log "Checking backend container..."
if ! docker ps | grep -q "emergency_backend"; then
    warn "Backend container not running, starting it..."
    $COMPOSE up -d backend
    sleep 5
fi
success "Backend container is running"

# Step 2: Test backend API directly
log "Testing backend API..."
if curl -sf http://localhost:3000/health >/dev/null 2>&1; then
    success "Backend API is accessible from host"
else
    warn "Backend API not responding from host"
fi

# Step 3: Check if backend is accessible from dashboard container
log "Testing backend from dashboard container..."
BACKEND_TEST=$(docker exec emergency_dashboard wget -qO- http://backend:3000/health 2>&1 || echo "FAILED")

if echo "$BACKEND_TEST" | grep -q "success\|healthy"; then
    success "Backend is accessible from dashboard container"
else
    warn "Backend NOT accessible from dashboard container"
    log "Network issue detected, will recreate containers..."
fi

# Step 4: Backup and recreate nginx config with better proxy settings
log "Creating improved nginx configuration..."

cat > nginx-dashboard.conf <<'EOF'
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # Enable logging for debugging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log debug;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/json;

    # Dashboard static files
    location / {
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache";
    }

    # Proxy ALL /auth/* requests to backend
    location /auth {
        proxy_pass http://backend:3000/auth;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Important for JSON responses
        proxy_set_header Accept application/json;
        proxy_set_header Content-Type application/json;

        # Disable buffering for immediate response
        proxy_buffering off;
        proxy_request_buffering off;
    }

    # Proxy ALL /api/* requests to backend
    location /api {
        proxy_pass http://backend:3000/api;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Important for JSON responses
        proxy_set_header Accept application/json;
        proxy_set_header Content-Type application/json;

        # WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_cache_bypass $http_upgrade;

        # Disable buffering
        proxy_buffering off;
        proxy_request_buffering off;
    }

    # Proxy /webhook to backend
    location /webhook {
        proxy_pass http://backend:3000/webhook;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Proxy /health to backend
    location /health {
        proxy_pass http://backend:3000/health;
        proxy_set_header Host $host;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

success "Nginx configuration updated"

# Step 5: Recreate dashboard container with new config
log "Recreating dashboard container..."
$COMPOSE stop dashboard
$COMPOSE rm -f dashboard
$COMPOSE up -d dashboard

log "Waiting for dashboard to start..."
sleep 5

# Step 6: Verify nginx config inside container
log "Verifying nginx configuration..."
docker exec emergency_dashboard nginx -t 2>&1 | grep -q "successful" && success "Nginx config is valid" || warn "Nginx config may have issues"

# Step 7: Test API proxy from inside dashboard container
log "Testing API proxy..."

# Test health endpoint
HEALTH_TEST=$(docker exec emergency_dashboard wget -qO- http://localhost/health 2>/dev/null || echo "FAILED")
if echo "$HEALTH_TEST" | grep -q "success\|healthy"; then
    success "API proxy is working (/health)"
else
    warn "API proxy test failed"
    log "Health response: $HEALTH_TEST"
fi

# Step 8: Check nginx logs for errors
log "Checking nginx error logs..."
NGINX_ERRORS=$(docker exec emergency_dashboard tail -5 /var/log/nginx/error.log 2>/dev/null || echo "")
if [ -z "$NGINX_ERRORS" ]; then
    success "No nginx errors"
else
    warn "Recent nginx errors:"
    echo "$NGINX_ERRORS"
fi

# Step 9: Restart backend to ensure it's fresh
log "Restarting backend for good measure..."
$COMPOSE restart backend
sleep 5

# Final summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
success "Dashboard API proxy has been fixed!"
echo ""
echo "📊 Dashboard URL: http://localhost:8080"
echo ""
echo "🧪 Test Commands:"
echo "   1. Test health:  curl http://localhost:8080/health"
echo "   2. Test auth:    curl -X POST http://localhost:8080/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"your-password\"}'"
echo ""
echo "📝 Debug Commands:"
echo "   Dashboard logs:  docker logs -f emergency_dashboard"
echo "   Backend logs:    docker logs -f emergency_backend"
echo "   Nginx logs:      docker exec emergency_dashboard tail -f /var/log/nginx/access.log"
echo "   Nginx errors:    docker exec emergency_dashboard tail -f /var/log/nginx/error.log"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test login endpoint specifically
log "Testing login endpoint..."
LOGIN_TEST=$(curl -sf -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"test"}' 2>&1 || echo "FAILED")

if echo "$LOGIN_TEST" | grep -q "Invalid credentials\|success\|error"; then
    success "Login endpoint is responding with JSON"
    echo "   Response: $LOGIN_TEST"
else
    warn "Login endpoint may not be working correctly"
    echo "   Response: $LOGIN_TEST"
fi

echo ""
log "Please try logging in again at: http://localhost:8080"
echo ""
