#!/bin/bash

# ============================================
# CURL-BASED INSTALLER (FULL VERSION)
# ============================================
# Download and deploy Emergency Chatbot (Full version with AI)
# No git required - uses curl/wget
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/[repo]/main/scripts/install.sh | bash

set -e

REPO_URL="https://github.com/iwewe/chatbot-disaster-response"
# Download from current active branch (change this to 'main' after merge)
REPO_BRANCH="claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf"
REPO_ARCHIVE="https://github.com/iwewe/chatbot-disaster-response/archive/refs/heads/${REPO_BRANCH}.zip"
INSTALL_DIR="$HOME/emergency-chatbot"

echo "🚀 Emergency Chatbot - One-Click Installer (FULL)"
echo "==================================================="
echo ""
echo "🤖 Mode: AI-Powered Extraction (Ollama)"
echo "📊 Requirements: 16GB RAM, 8 cores, 50GB disk"
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
    curl -L "$REPO_ARCHIVE" -o archive.zip
elif command -v wget &> /dev/null; then
    wget "$REPO_ARCHIVE" -O archive.zip
else
    echo "❌ curl or wget required"
    exit 1
fi

echo "📦 Extracting..."
unzip -q archive.zip

# Auto-detect extracted directory name (GitHub creates: repo-name-branch-name)
EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "chatbot-disaster-response-*" | head -n 1)

if [ -z "$EXTRACTED_DIR" ]; then
    echo "❌ Failed to find extracted directory"
    exit 1
fi

echo "📂 Found: $EXTRACTED_DIR"

# Move regular files
mv "$EXTRACTED_DIR"/* . 2>/dev/null || true

# Explicitly copy .env.example (important hidden file)
if [ -f "$EXTRACTED_DIR/.env.example" ]; then
    cp "$EXTRACTED_DIR/.env.example" .env.example
fi

# Try to move other hidden files (ignore errors for . and ..)
mv "$EXTRACTED_DIR"/.* . 2>/dev/null || true

# Cleanup
rm -rf "$EXTRACTED_DIR" archive.zip

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

echo "✅ Configuration saved"

# Make scripts executable
chmod +x scripts/*.sh

# Deploy
echo ""
echo "🚀 Starting deployment..."
echo ""

bash scripts/deploy.sh

echo ""
echo "✅ Installation complete!"
echo ""
echo "📍 Project location: $INSTALL_DIR"
echo ""
echo "📝 Important files:"
echo "   - Configuration: $INSTALL_DIR/.env"
echo "   - Documentation: $INSTALL_DIR/docs/"
echo "   - Logs: docker compose logs -f"
echo ""
echo "🎉 Your Emergency Chatbot is now running!"
