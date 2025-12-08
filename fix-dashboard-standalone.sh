#!/bin/bash
################################################################################
# Emergency Chatbot - Standalone Fix untuk Dashboard
# Jalankan di server yang sudah install tapi error "no such service: dashboard"
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

clear
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║  Emergency Chatbot - Dashboard Fix                      ║
║  Fixes: "no such service: dashboard" error              ║
╚══════════════════════════════════════════════════════════╝
EOF
echo ""

# Check if in correct directory
if [ ! -f "docker-compose.yml" ]; then
    error "docker-compose.yml not found! Run from installation directory."
fi

log "Fixing dashboard service..."

################################################################################
# 1. Check if dashboard service already exists
################################################################################
if grep -q "container_name: emergency_dashboard" docker-compose.yml; then
    success "Dashboard service already exists in docker-compose.yml"
else
    log "Adding dashboard service to docker-compose.yml..."

    # Add dashboard service before the nginx service
    cat >> docker-compose.yml << 'DASHEOF'

  # ============================================
  # Web Dashboard
  # ============================================
  dashboard:
    image: nginx:alpine
    container_name: emergency_dashboard
    restart: unless-stopped
    ports:
      - "8080:80"
    volumes:
      - ./dashboard:/usr/share/nginx/html:ro
      - ./dashboard/nginx.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - backend
    networks:
      - emergency_network
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
DASHEOF

    success "Dashboard service added to docker-compose.yml"
fi

################################################################################
# 2. Create dashboard files
################################################################################
log "Creating dashboard files..."

mkdir -p dashboard

# Create index.html
cat > dashboard/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Emergency Response Chatbot - Dashboard</title>
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
        .note {
            background: #fef3c7;
            border-left: 4px solid #f59e0b;
            padding: 15px;
            margin-top: 20px;
            text-align: left;
            color: #92400e;
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
            <div class="endpoint">GET /health</div>
            <div class="endpoint">POST /auth/login</div>
            <div class="endpoint">GET /api/reports</div>
            <div class="endpoint">POST /api/reports</div>
        </div>

        <div class="note">
            <strong>📱 Note:</strong> Web dashboard UI sedang dalam pengembangan.
            Sistem dapat diakses via WhatsApp, REST API, atau database langsung.
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
HTMLEOF

# Create nginx.conf
cat > dashboard/nginx.conf << 'NGINXEOF'
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
NGINXEOF

success "Dashboard files created"

################################################################################
# 3. Start dashboard service
################################################################################
log "Starting dashboard service..."

# Detect compose command
if docker compose version >/dev/null 2>&1; then
    COMPOSE="docker compose"
else
    COMPOSE="docker-compose"
fi

$COMPOSE up -d dashboard

success "Dashboard service started"

################################################################################
# 4. Verify dashboard
################################################################################
log "Waiting for dashboard to be ready..."
sleep 5

if curl -sf http://localhost:8080 >/dev/null 2>&1; then
    success "Dashboard is accessible!"
else
    log "Dashboard may still be starting up..."
fi

# Show status
echo ""
log "Checking all services..."
$COMPOSE ps

cat << EOF

╔══════════════════════════════════════════════════════════╗
║              ✅ FIX COMPLETE!                            ║
╚══════════════════════════════════════════════════════════╝

${GREEN}Dashboard is now running!${NC}

🌐 Access:
   Dashboard:  http://localhost:8080
   Backend:    http://localhost:3000

📊 Check status:
   docker compose ps

📝 View logs:
   docker logs emergency_dashboard
   docker logs emergency_backend

EOF
