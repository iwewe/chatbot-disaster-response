#!/bin/bash

# ============================================
# CURL-BASED INSTALLER (LIGHT VERSION)
# ============================================
# Download and deploy Emergency Chatbot (Light version - No AI)
# No git required - uses curl/wget
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/[repo]/main/scripts/install-light.sh | bash

set -e

REPO_URL="https://github.com/iwewe/chatbot-disaster-response"
REPO_ARCHIVE="https://github.com/iwewe/chatbot-disaster-response/archive/refs/heads/main.zip"
INSTALL_DIR="$HOME/emergency-chatbot"

echo "🚀 Emergency Chatbot - One-Click Installer (LIGHT)"
echo "===================================================="
echo ""
echo "⚡ Mode: Rule-Based Extraction (No AI)"
echo "📊 Requirements: 4GB RAM, 2 cores, 20GB disk"
echo ""

# Check prerequisites
echo "🔍 Checking prerequisites..."

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found!"
    echo ""
    echo "Please install Docker first:"
    echo "  curl -fsSL https://get.docker.com | sudo sh"
    echo ""
    echo "Or run the Ubuntu setup script:"
    echo "  curl -fsSL https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/main/scripts/setup-ubuntu.sh | sudo bash"
    exit 1
fi

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose not found!"
    exit 1
fi

echo "✅ Docker: $(docker --version)"
echo "✅ Docker Compose: $(docker compose version)"

# Check if unzip is available
if ! command -v unzip &> /dev/null; then
    echo "📦 Installing unzip..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y unzip
    elif command -v yum &> /dev/null; then
        sudo yum install -y unzip
    else
        echo "❌ Please install 'unzip' manually"
        exit 1
    fi
fi

# Download project
echo ""
echo "📥 Downloading project..."

if [ -d "$INSTALL_DIR" ]; then
    echo "⚠️  Directory $INSTALL_DIR already exists"
    read -p "Remove and reinstall? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$INSTALL_DIR"
    else
        echo "Installation cancelled"
        exit 0
    fi
fi

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Download using curl or wget
if command -v curl &> /dev/null; then
    curl -L "$REPO_ARCHIVE" -o main.zip
elif command -v wget &> /dev/null; then
    wget "$REPO_ARCHIVE" -O main.zip
else
    echo "❌ curl or wget required"
    exit 1
fi

echo "📦 Extracting..."
unzip -q main.zip
# Move regular files
mv chatbot-disaster-response-main/* . 2>/dev/null || true
# Explicitly copy .env.example (important hidden file)
if [ -f chatbot-disaster-response-main/.env.example ]; then
    cp chatbot-disaster-response-main/.env.example .env.example
fi
# Try to move other hidden files (ignore errors for . and ..)
mv chatbot-disaster-response-main/.* . 2>/dev/null || true
rm -rf chatbot-disaster-response-main main.zip

echo "✅ Project downloaded to: $INSTALL_DIR"

# Setup environment
echo ""
echo "⚙️  Setting up configuration..."

if [ ! -f .env ]; then
    cp .env.example .env
    echo "✅ Created .env file"
fi

# Interactive configuration
echo ""
echo "📝 Configuration Setup"
echo "======================="
echo ""
echo "Please provide the following information:"
echo ""

read -p "WhatsApp Phone Number ID: " WHATSAPP_PHONE_NUMBER_ID
read -p "WhatsApp Access Token: " WHATSAPP_ACCESS_TOKEN
read -p "WhatsApp Verify Token (create a random string): " WHATSAPP_VERIFY_TOKEN
read -p "WhatsApp Business Account ID: " WHATSAPP_BUSINESS_ACCOUNT_ID
read -p "Telegram Bot Token: " TELEGRAM_BOT_TOKEN
read -p "Telegram Admin Chat ID: " TELEGRAM_ADMIN_CHAT_ID
read -p "Your Domain or IP (e.g., https://chatbot.yourdomain.com or http://YOUR_IP:3000): " API_BASE_URL

# Generate JWT secret
JWT_SECRET=$(openssl rand -hex 32)

# Update .env
sed -i "s|WHATSAPP_PHONE_NUMBER_ID=.*|WHATSAPP_PHONE_NUMBER_ID=$WHATSAPP_PHONE_NUMBER_ID|" .env
sed -i "s|WHATSAPP_ACCESS_TOKEN=.*|WHATSAPP_ACCESS_TOKEN=$WHATSAPP_ACCESS_TOKEN|" .env
sed -i "s|WHATSAPP_VERIFY_TOKEN=.*|WHATSAPP_VERIFY_TOKEN=$WHATSAPP_VERIFY_TOKEN|" .env
sed -i "s|WHATSAPP_BUSINESS_ACCOUNT_ID=.*|WHATSAPP_BUSINESS_ACCOUNT_ID=$WHATSAPP_BUSINESS_ACCOUNT_ID|" .env
sed -i "s|TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN|" .env
sed -i "s|TELEGRAM_ADMIN_CHAT_ID=.*|TELEGRAM_ADMIN_CHAT_ID=$TELEGRAM_ADMIN_CHAT_ID|" .env
sed -i "s|API_BASE_URL=.*|API_BASE_URL=$API_BASE_URL|" .env
sed -i "s|JWT_SECRET=.*|JWT_SECRET=$JWT_SECRET|" .env

# Set light mode
echo "" >> .env
echo "# Light deployment mode" >> .env
echo "OLLAMA_BASE_URL=http://disabled:11434" >> .env
echo "OLLAMA_FALLBACK_ENABLED=true" >> .env

echo "✅ Configuration saved (Light mode enabled)"

# Make scripts executable
chmod +x scripts/*.sh

# Deploy
echo ""
echo "🚀 Starting deployment (Light version)..."
echo ""

bash scripts/deploy-light.sh

echo ""
echo "✅ Installation complete!"
echo ""
echo "📍 Project location: $INSTALL_DIR"
echo ""
echo "📝 Important files:"
echo "   - Configuration: $INSTALL_DIR/.env"
echo "   - Documentation: $INSTALL_DIR/docs/"
echo "   - Logs: docker compose -f docker-compose.light.yml logs -f"
echo ""
echo "💡 LIGHT MODE: Using rule-based extraction"
echo "   For best results, ask users to format reports clearly:"
echo "   'Ada X orang [status] di [lokasi], butuh [kebutuhan]'"
echo ""
echo "🎉 Your Emergency Chatbot (Light) is now running!"
