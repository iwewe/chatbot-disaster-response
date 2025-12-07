#!/bin/bash
set -e

BRANCH="claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf"
BASE_URL="https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/${BRANCH}"

echo "🔧 Memperbaiki Baileys dan Dependencies..."
echo ""

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Error: docker-compose.yml tidak ditemukan!"
    echo "Pastikan Anda berada di directory emergency-chatbot-dev"
    exit 1
fi

# Download fixed files from GitHub
echo "📥 Downloading fixed files dari GitHub..."

# 1. WhatsApp Baileys Service (fixed makeInMemoryStore issue)
echo "  → whatsapp-baileys.service.js"
curl -fsSL "${BASE_URL}/backend/src/services/whatsapp-baileys.service.js" \
  -o backend/src/services/whatsapp-baileys.service.js

# 2. API Controller (fixed missing ollamaService import)
echo "  → api.controller.js"
curl -fsSL "${BASE_URL}/backend/src/controllers/api.controller.js" \
  -o backend/src/controllers/api.controller.js

# 3. Docker Compose (added DNS configuration)
echo "  → docker-compose.yml"
curl -fsSL "${BASE_URL}/docker-compose.yml" \
  -o docker-compose.yml

echo "  → docker-compose.light.yml"
curl -fsSL "${BASE_URL}/docker-compose.light.yml" \
  -o docker-compose.light.yml

echo "✅ All files updated!"
echo ""

# Stop backend
echo "⏸️  Stopping backend container..."
docker compose stop backend

# Rebuild backend with --no-cache to force fresh build
echo "🔨 Rebuilding backend (no cache)..."
docker compose build --no-cache backend

# Start backend
echo "▶️  Starting backend..."
docker compose up -d backend

# Wait for startup
echo "⏳ Waiting for backend to start..."
sleep 5

# Show logs
echo ""
echo "✅ Backend fixed and restarted!"
echo ""
echo "📋 Viewing logs (Ctrl+C to exit):"
echo "===================================="
echo ""
docker logs emergency_backend -f
