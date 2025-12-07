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
# Download from current active branch (change this to 'main' after merge)
REPO_BRANCH="claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf"
REPO_ARCHIVE="https://github.com/iwewe/chatbot-disaster-response/archive/refs/heads/${REPO_BRANCH}.zip"
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

# Make setup script executable
chmod +x scripts/setup-env.sh

# Run interactive setup with LIGHT mode pre-selected
export DEPLOY_MODE_DEFAULT=1
bash scripts/setup-env.sh

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
