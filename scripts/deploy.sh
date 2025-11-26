#!/bin/bash

# Master deployment script for Emergency Chatbot System
# This script deploys the entire system with one command

set -e

echo "🚀 Emergency Chatbot Deployment Script"
echo "========================================"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
  echo "⚠️  .env file not found!"
  echo "   Copying from .env.example..."
  cp .env.example .env
  echo ""
  echo "❗ IMPORTANT: Please edit .env and fill in the required values:"
  echo "   - WHATSAPP_PHONE_NUMBER_ID"
  echo "   - WHATSAPP_ACCESS_TOKEN"
  echo "   - WHATSAPP_VERIFY_TOKEN"
  echo "   - TELEGRAM_BOT_TOKEN"
  echo "   - TELEGRAM_ADMIN_CHAT_ID"
  echo "   - API_BASE_URL (your domain or IP)"
  echo "   - JWT_SECRET (generate a random string)"
  echo ""
  read -p "Press Enter after you've updated .env file..."
fi

# Check Docker
if ! command -v docker &> /dev/null; then
  echo "❌ Docker is not installed. Please install Docker first."
  echo "   https://docs.docker.com/get-docker/"
  exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
  echo "❌ Docker Compose is not installed. Please install Docker Compose first."
  echo "   https://docs.docker.com/compose/install/"
  exit 1
fi

echo "✅ Docker is installed"
echo ""

# Pull images
echo "📥 Pulling Docker images..."
docker-compose pull

echo ""
echo "🏗️  Building backend..."
docker-compose build backend

echo ""
echo "🚀 Starting services..."
docker-compose up -d

echo ""
echo "⏳ Waiting for services to be healthy..."
sleep 10

# Check service health
echo ""
echo "🔍 Checking service health..."

services=("emergency_db" "emergency_redis" "emergency_ollama" "emergency_backend")
for service in "${services[@]}"; do
  if docker ps --filter "name=$service" --filter "status=running" | grep -q $service; then
    echo "✅ $service is running"
  else
    echo "❌ $service is not running"
    echo "   Check logs: docker logs $service"
  fi
done

echo ""
echo "📊 Service Status:"
docker-compose ps

echo ""
echo "🤖 Initializing Ollama..."
bash scripts/init-ollama.sh

echo ""
echo "🗄️  Initializing database..."
bash scripts/init-database.sh

echo ""
echo "============================================"
echo "✅ DEPLOYMENT COMPLETE!"
echo "============================================"
echo ""
echo "📍 Services running at:"
echo "   - Backend API: http://localhost:3000"
echo "   - Health Check: http://localhost:3000/health"
echo "   - Webhook: http://localhost:3000/webhook"
echo ""
echo "📝 Next Steps:"
echo ""
echo "1. Setup admin user (one-time):"
echo "   curl -X POST http://localhost:3000/auth/setup-admin \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"phoneNumber\":\"+6281234567890\",\"name\":\"Admin Name\",\"password\":\"your-secure-password\"}'"
echo ""
echo "2. Configure WhatsApp Webhook:"
echo "   - Go to Meta Developer Console"
echo "   - Set webhook URL to: https://your-domain.com/webhook"
echo "   - Use WHATSAPP_VERIFY_TOKEN from .env for verification"
echo ""
echo "3. Test the system:"
echo "   - Send a WhatsApp message to your configured number"
echo "   - Check Telegram for admin notifications"
echo "   - Monitor logs: docker-compose logs -f backend"
echo ""
echo "📖 For detailed documentation, see:"
echo "   - docs/DEPLOYMENT.md"
echo "   - docs/OPERATOR_MANUAL.md"
echo ""
echo "🆘 Troubleshooting:"
echo "   - Check all logs: docker-compose logs"
echo "   - Restart services: docker-compose restart"
echo "   - Stop all: docker-compose down"
echo "   - Full reset: docker-compose down -v (⚠️  deletes all data!)"
echo ""
