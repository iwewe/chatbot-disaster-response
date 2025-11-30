#!/bin/bash

# ============================================
# DEVELOPMENT SETUP SCRIPT
# ============================================
# Quick setup for development with Baileys + Ollama
# No git required - uses curl/wget
#
# Features:
# - Baileys WhatsApp (scan QR, no Meta account)
# - Ollama AI (full AI extraction)
# - Development mode enabled
# - Auto-configured for local testing

set -e

REPO_URL="https://github.com/iwewe/chatbot-disaster-response"
REPO_BRANCH="claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf"
REPO_ARCHIVE="https://github.com/iwewe/chatbot-disaster-response/archive/refs/heads/${REPO_BRANCH}.zip"
INSTALL_DIR="$HOME/emergency-chatbot-dev"

echo "🚀 Emergency Chatbot - Development Setup"
echo "=========================================="
echo ""
echo "📦 Mode: Baileys (WhatsApp Web) + Ollama (AI)"
echo "📊 Requirements: 16GB RAM, 8 cores, 50GB disk"
echo "🎯 Purpose: Development & Testing"
echo ""

# Check prerequisites
echo "🔍 Checking prerequisites..."
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found!"
    echo ""
    echo "Please install Docker first:"
    echo "  curl -fsSL https://get.docker.com | sudo sh"
    echo ""
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
echo "📥 Downloading project from GitHub..."
echo ""

if [ -d "$INSTALL_DIR" ]; then
    echo "⚠️  Directory $INSTALL_DIR already exists"
    read -t 5 -p "Remove and reinstall? (Y/n) " -n 1 -r || true
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
    echo "▶️  Removing existing installation..."
    rm -rf "$INSTALL_DIR"
fi

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Download using curl or wget
echo "📦 Downloading archive..."
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

# Auto-detect extracted directory name
EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "chatbot-disaster-response-*" | head -n 1)

if [ -z "$EXTRACTED_DIR" ]; then
    echo "❌ Failed to find extracted directory"
    exit 1
fi

echo "📂 Found: $EXTRACTED_DIR"

# Move files
mv "$EXTRACTED_DIR"/* . 2>/dev/null || true

# Explicitly copy .env.example
if [ -f "$EXTRACTED_DIR/.env.example" ]; then
    cp "$EXTRACTED_DIR/.env.example" .env.example
fi

# Try to move other hidden files
mv "$EXTRACTED_DIR"/.* . 2>/dev/null || true

# Cleanup
rm -rf "$EXTRACTED_DIR" archive.zip

echo "✅ Project downloaded to: $INSTALL_DIR"
echo ""

# Setup environment
echo "⚙️  Setting up development environment..."
echo ""

# Copy .env.example to .env
cp .env.example .env

# Generate secure secrets
JWT_SECRET=$(openssl rand -hex 32)
DB_PASSWORD=$(openssl rand -hex 16)

echo "🔐 Generated secure credentials"
echo ""

# Interactive configuration (minimal for development)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Development Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "ℹ️  For development, you need minimal configuration"
echo ""
echo "💡 TIP: You can set environment variables to skip prompts:"
echo "   export DEV_TELEGRAM_BOT_TOKEN=your_token"
echo "   export DEV_TELEGRAM_ADMIN_CHAT_ID=your_chat_id"
echo "   export DEV_API_BASE_URL=http://localhost:3000"
echo ""

# Telegram credentials (check env var first)
if [ -z "$DEV_TELEGRAM_BOT_TOKEN" ]; then
    echo "📬 Telegram Bot Configuration (for admin notifications):"
    echo ""

    while true; do
        read -p "Telegram Bot Token (from @BotFather): " TELEGRAM_BOT_TOKEN
        if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
            break
        fi
        echo "❌ This field is required!"
    done
else
    TELEGRAM_BOT_TOKEN="$DEV_TELEGRAM_BOT_TOKEN"
    echo "✅ Using Telegram Bot Token from environment"
fi

if [ -z "$DEV_TELEGRAM_ADMIN_CHAT_ID" ]; then
    if [ -z "$DEV_TELEGRAM_BOT_TOKEN" ]; then
        echo ""
    fi

    while true; do
        read -p "Telegram Admin Chat ID: " TELEGRAM_ADMIN_CHAT_ID
        if [ -n "$TELEGRAM_ADMIN_CHAT_ID" ]; then
            break
        fi
        echo "❌ This field is required!"
    done
else
    TELEGRAM_ADMIN_CHAT_ID="$DEV_TELEGRAM_ADMIN_CHAT_ID"
    echo "✅ Using Telegram Admin Chat ID from environment"
fi

echo ""
echo "✅ Telegram configured"
echo ""

# API Base URL (check env var or use default)
if [ -n "$DEV_API_BASE_URL" ]; then
    API_BASE_URL="$DEV_API_BASE_URL"
    echo "✅ API Base URL: $API_BASE_URL (from environment)"
else
    echo "🌐 API Configuration:"
    echo ""
    echo "Select API Base URL:"
    echo "  1) Localhost (http://localhost:3000) - Default for development"
    echo "  2) Custom URL"
    echo ""

    read -p "Select option (1-2) [1]: " API_OPTION
    API_OPTION=${API_OPTION:-1}

    case $API_OPTION in
        2)
            read -p "Enter custom URL: " API_BASE_URL
            ;;
        *)
            API_BASE_URL="http://localhost:3000"
            ;;
    esac

    echo "✅ API Base URL: $API_BASE_URL"
fi
echo ""

# Update .env file
echo "💾 Writing configuration..."

# Development mode settings
sed -i "s|NODE_ENV=.*|NODE_ENV=development|" .env
sed -i "s|DEBUG_MODE=.*|DEBUG_MODE=true|" .env
sed -i "s|LOG_LEVEL=.*|LOG_LEVEL=debug|" .env

# WhatsApp: Baileys mode (no Meta credentials needed)
sed -i "s|WHATSAPP_MODE=.*|WHATSAPP_MODE=baileys|" .env
sed -i "s|WHATSAPP_PHONE_NUMBER_ID=.*|WHATSAPP_PHONE_NUMBER_ID=baileys_dev|" .env
sed -i "s|WHATSAPP_ACCESS_TOKEN=.*|WHATSAPP_ACCESS_TOKEN=baileys_dev|" .env
sed -i "s|WHATSAPP_VERIFY_TOKEN=.*|WHATSAPP_VERIFY_TOKEN=baileys_dev|" .env
sed -i "s|WHATSAPP_BUSINESS_ACCOUNT_ID=.*|WHATSAPP_BUSINESS_ACCOUNT_ID=baileys_dev|" .env

# Telegram
sed -i "s|TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN|" .env
sed -i "s|TELEGRAM_ADMIN_CHAT_ID=.*|TELEGRAM_ADMIN_CHAT_ID=$TELEGRAM_ADMIN_CHAT_ID|" .env

# API
sed -i "s|API_BASE_URL=.*|API_BASE_URL=$API_BASE_URL|" .env

# Security
sed -i "s|JWT_SECRET=.*|JWT_SECRET=$JWT_SECRET|" .env
sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$DB_PASSWORD|" .env
sed -i "s|DATABASE_URL=.*|DATABASE_URL=postgresql://postgres:$DB_PASSWORD@postgres:5432/emergency_chatbot|" .env

# Ollama (FULL mode - AI enabled)
sed -i "s|OLLAMA_BASE_URL=.*|OLLAMA_BASE_URL=http://emergency_ollama:11434|" .env
sed -i "s|OLLAMA_MODEL=.*|OLLAMA_MODEL=qwen2.5:7b|" .env
sed -i "s|OLLAMA_TIMEOUT=.*|OLLAMA_TIMEOUT=30000|" .env
sed -i "s|OLLAMA_FALLBACK_ENABLED=.*|OLLAMA_FALLBACK_ENABLED=true|" .env

echo "✅ Configuration saved"
echo ""

# Make scripts executable
chmod +x scripts/*.sh 2>/dev/null || true

# Display configuration summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Development Configuration Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Environment: DEVELOPMENT"
echo "WhatsApp Mode: BAILEYS (WhatsApp Web - scan QR)"
echo "AI Mode: OLLAMA (Full AI extraction)"
echo "API Base URL: $API_BASE_URL"
echo "Telegram Bot: ${TELEGRAM_BOT_TOKEN:0:20}..."
echo "Debug Mode: ENABLED"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Ask to deploy now
echo "🚀 Ready to deploy!"
echo ""
read -t 5 -p "Start deployment now? (Y/n) " -n 1 -r || true
echo

if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo ""
    echo "▶️  Starting deployment..."
    echo ""

    # Deploy using docker-compose (full version with Ollama)
    echo "📥 Pulling Docker images..."
    docker compose pull

    echo ""
    echo "🏗️  Building backend..."
    docker compose build backend

    echo ""
    echo "🚀 Starting services..."
    docker compose up -d

    echo ""
    echo "⏳ Waiting for services to start..."
    sleep 15

    # Check service health
    echo ""
    echo "🔍 Checking service status..."
    docker compose ps

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ DEVELOPMENT DEPLOYMENT COMPLETE!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📱 WhatsApp: Baileys (scan QR code below)"
    echo "🤖 AI: Ollama (downloading model...)"
    echo "📍 API: $API_BASE_URL"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📝 NEXT STEPS:"
    echo ""
    echo "1️⃣  SCAN QR CODE untuk WhatsApp:"
    echo "   docker logs emergency_backend -f"
    echo "   (Scan dengan WhatsApp Anda)"
    echo ""
    echo "2️⃣  WAIT for Ollama to download model (~5GB, takes 5-15 minutes):"
    echo "   docker logs emergency_ollama -f"
    echo ""
    echo "3️⃣  CHECK health:"
    echo "   curl http://localhost:3000/health"
    echo ""
    echo "4️⃣  VIEW logs:"
    echo "   docker compose logs -f"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🔧 DEVELOPMENT COMMANDS:"
    echo ""
    echo "# View backend logs (for QR code)"
    echo "docker logs emergency_backend -f"
    echo ""
    echo "# View Ollama logs (model download progress)"
    echo "docker logs emergency_ollama -f"
    echo ""
    echo "# Restart services"
    echo "docker compose restart"
    echo ""
    echo "# Stop services"
    echo "docker compose down"
    echo ""
    echo "# Start services"
    echo "docker compose up -d"
    echo ""
    echo "# View all logs"
    echo "docker compose logs -f"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📚 DOCUMENTATION:"
    echo "   - Baileys Setup: docs/BAILEYS_SETUP.md"
    echo "   - Deployment: docs/DEPLOYMENT.md"
    echo "   - Operator Manual: docs/OPERATOR_MANUAL.md"
    echo ""
    echo "🎉 Happy developing! Scan the QR code to start testing!"
    echo ""

    # Show QR code immediately
    echo "⏳ Waiting for QR code (10 seconds)..."
    sleep 10
    echo ""
    echo "📱 QR CODE:"
    docker logs emergency_backend 2>&1 | tail -50

else
    echo ""
    echo "⏸️  Deployment skipped"
    echo ""
    echo "To deploy later, run:"
    echo "  cd $INSTALL_DIR"
    echo "  docker compose up -d"
    echo ""
fi

echo ""
echo "📍 Project location: $INSTALL_DIR"
echo ""
