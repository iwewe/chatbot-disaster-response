#!/bin/bash
set -e

echo "🔧 Memperbaiki Baileys Import Error..."
echo ""

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Error: docker-compose.yml tidak ditemukan!"
    echo "Pastikan Anda berada di directory emergency-chatbot-dev"
    exit 1
fi

# Pull latest changes
echo "📥 Pulling latest changes from repository..."
git pull origin claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf || {
    echo "⚠️  Warning: Git pull failed, continuing with local changes..."
}

# Stop backend
echo "⏸️  Stopping backend container..."
docker compose stop backend

# Rebuild backend
echo "🔨 Rebuilding backend with fix..."
docker compose build backend

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
