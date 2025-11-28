#!/bin/bash

# ============================================
# QUICK FIX - Download and run setup-env.sh
# ============================================
# For users with existing installation but broken .env

set -e

BRANCH="claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf"
SCRIPT_URL="https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/refs/heads/${BRANCH}/scripts/setup-env.sh"

echo "🔧 Quick Fix - Environment Configuration"
echo "=========================================="
echo ""

# Check if we're in the right directory
if [ ! -f docker-compose.light.yml ] && [ ! -f docker-compose.yml ]; then
    echo "❌ Error: Not in emergency-chatbot directory"
    echo "   Please run: cd ~/emergency-chatbot"
    exit 1
fi

# Check if .env.example exists
if [ ! -f .env.example ]; then
    echo "⚠️  .env.example not found, downloading..."
    curl -fsSL "https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/refs/heads/${BRANCH}/.env.example" \
        -o .env.example
    echo "✅ Downloaded .env.example"
fi

echo "📥 Downloading latest setup script..."
curl -fsSL "$SCRIPT_URL" -o setup-env-temp.sh
chmod +x setup-env-temp.sh

echo "✅ Running interactive setup..."
echo ""

# Run setup with LIGHT mode default (user can change)
export DEPLOY_MODE_DEFAULT=1
bash setup-env-temp.sh

# Cleanup
rm -f setup-env-temp.sh

echo ""
echo "✅ Configuration fixed!"
echo ""
echo "📝 Next step: Restart containers"
echo ""
echo "   # Stop existing containers"
echo "   docker compose -f docker-compose.light.yml down"
echo ""
echo "   # Start with new configuration"
echo "   docker compose -f docker-compose.light.yml up -d"
echo ""
echo "   # Check logs"
echo "   docker logs emergency_backend -f"
echo ""
