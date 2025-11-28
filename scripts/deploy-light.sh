#!/bin/bash

# ============================================
# LIGHT DEPLOYMENT SCRIPT
# ============================================
# Deploy Emergency Chatbot without AI (Ollama)
# For servers with limited resources (4GB RAM minimum)
# Uses rule-based extraction only

set -e

echo "🚀 Emergency Chatbot - LIGHT Deployment"
echo "========================================="
echo ""
echo "⚡ Mode: Rule-Based Extraction (No AI)"
echo "📊 Requirements: 4GB RAM, 2 cores, 20GB disk"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
  echo "⚠️  .env file not found!"
  echo "   Copying from .env.example..."
  cp .env.example .env

  # Set light mode defaults
  echo "" >> .env
  echo "# Light deployment mode" >> .env
  echo "OLLAMA_BASE_URL=http://disabled:11434" >> .env
  echo "OLLAMA_FALLBACK_ENABLED=true" >> .env

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
  echo "❌ Docker is not installed. Please run:"
  echo "   curl -fsSL https://get.docker.com | sudo sh"
  exit 1
fi

if ! docker compose version &> /dev/null; then
  echo "❌ Docker Compose is not installed."
  exit 1
fi

echo "✅ Docker is installed"
echo ""

# Confirm light deployment
echo "⚠️  LIGHT DEPLOYMENT MODE"
echo ""
echo "This will deploy WITHOUT Ollama (AI)."
echo "Reports will be processed using rule-based keyword extraction."
echo ""
echo "Advantages:"
echo "  ✅ Low resource usage (4GB RAM OK)"
echo "  ✅ Faster startup (no AI model download)"
echo "  ✅ More stable (no AI timeout issues)"
echo ""
echo "Limitations:"
echo "  ⚠️  Less intelligent extraction (keyword-based only)"
echo "  ⚠️  May miss complex reports"
echo "  ⚠️  Requires clearer message format from users"
echo ""
read -t 5 -p "Continue with light deployment? (Y/n) " -n 1 -r || true
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi
echo "▶️  Proceeding with deployment..."

# Pull images
echo ""
echo "📥 Pulling Docker images (light version)..."
docker compose -f docker-compose.light.yml pull

# Build backend
echo ""
echo "🏗️  Building backend..."
docker compose -f docker-compose.light.yml build backend

# Start services
echo ""
echo "🚀 Starting services..."
docker compose -f docker-compose.light.yml up -d

echo ""
echo "⏳ Waiting for services to be healthy..."
sleep 15

# Check service health
echo ""
echo "🔍 Checking service health..."

services=("emergency_db" "emergency_redis" "emergency_backend")
all_healthy=true

for service in "${services[@]}"; do
  if docker ps --filter "name=$service" --filter "status=running" | grep -q $service; then
    echo "✅ $service is running"
  else
    echo "❌ $service is not running"
    all_healthy=false
  fi
done

if [ "$all_healthy" = false ]; then
  echo ""
  echo "⚠️  Some services failed to start. Check logs:"
  echo "   docker compose -f docker-compose.light.yml logs"
  exit 1
fi

# Initialize database
echo ""
echo "🗄️  Initializing database..."
docker exec emergency_backend sh -c "cd /app && npx prisma migrate deploy" || {
  echo "⚠️  Migration failed, trying to create..."
  docker exec emergency_backend sh -c "cd /app && npx prisma migrate dev --name init"
}

echo ""
echo "============================================"
echo "✅ LIGHT DEPLOYMENT COMPLETE!"
echo "============================================"
echo ""
echo "📍 Services running at:"
echo "   - Backend API: http://localhost:3000"
echo "   - Health Check: http://localhost:3000/health"
echo "   - Webhook: http://localhost:3000/webhook"
echo ""
echo "⚡ Mode: RULE-BASED EXTRACTION (No AI)"
echo ""
echo "📝 Next Steps:"
echo ""
echo "1. Setup admin user (one-time):"
echo "   curl -X POST http://localhost:3000/auth/setup-admin \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"phoneNumber\":\"+6281234567890\",\"name\":\"Admin Name\",\"password\":\"your-secure-password\"}'"
echo ""
echo "2. Configure WhatsApp Webhook:"
echo "   - Set webhook URL to: https://your-domain.com/webhook"
echo "   - Use WHATSAPP_VERIFY_TOKEN from .env"
echo ""
echo "3. Test the system:"
echo "   Send WhatsApp message to your configured number"
echo ""
echo "📊 Service Status:"
docker compose -f docker-compose.light.yml ps
echo ""
echo "📖 Documentation:"
echo "   - Deployment: docs/DEPLOYMENT.md"
echo "   - Operator Manual: docs/OPERATOR_MANUAL.md"
echo "   - WhatsApp Setup: docs/WHATSAPP_SETUP.md"
echo ""
echo "🆘 Troubleshooting:"
echo "   - View logs: docker compose -f docker-compose.light.yml logs -f"
echo "   - Restart: docker compose -f docker-compose.light.yml restart"
echo "   - Stop: docker compose -f docker-compose.light.yml down"
echo ""
echo "💡 TIP: For better extraction accuracy, ask users to format reports like:"
echo "   'Ada 3 orang luka di Desa X RT 02, butuh evakuasi'"
echo ""
