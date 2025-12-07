#!/bin/bash

# ============================================
# Ubuntu Server Setup Script
# ============================================
# Automatically installs all dependencies for Emergency Chatbot
# Tested on: Ubuntu 20.04, 22.04, 24.04
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/[repo]/main/scripts/setup-ubuntu.sh | sudo bash
#   OR
#   sudo bash setup-ubuntu.sh

set -e

echo "🚀 Emergency Chatbot - Ubuntu Server Setup"
echo "==========================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

# Detect Ubuntu version
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    echo "❌ Cannot detect OS version"
    exit 1
fi

echo "✅ Detected: $OS $VER"

if [ "$OS" != "ubuntu" ]; then
    echo "⚠️  This script is optimized for Ubuntu"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "📦 Step 1/5: Update system packages"
echo "-----------------------------------"
apt-get update
apt-get upgrade -y

echo ""
echo "🐳 Step 2/5: Install Docker"
echo "-----------------------------------"

# Check if Docker already installed
if command -v docker &> /dev/null; then
    echo "✅ Docker already installed: $(docker --version)"
else
    echo "📥 Installing Docker..."

    # Install prerequisites
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Set up repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Start Docker
    systemctl start docker
    systemctl enable docker

    echo "✅ Docker installed successfully"
fi

# Verify Docker Compose
if docker compose version &> /dev/null; then
    echo "✅ Docker Compose already installed: $(docker compose version)"
else
    echo "❌ Docker Compose plugin not found"
    exit 1
fi

echo ""
echo "👥 Step 3/5: Setup Docker user permissions"
echo "-----------------------------------"

# Get the actual user (not root) if script was run with sudo
if [ -n "$SUDO_USER" ]; then
    ACTUAL_USER=$SUDO_USER
else
    echo "Enter username to add to docker group (leave empty to skip):"
    read ACTUAL_USER
fi

if [ -n "$ACTUAL_USER" ]; then
    usermod -aG docker $ACTUAL_USER
    echo "✅ User $ACTUAL_USER added to docker group"
    echo "⚠️  User needs to log out and back in for group changes to take effect"
else
    echo "⚠️  Skipped user setup"
fi

echo ""
echo "🔧 Step 4/5: Install utilities"
echo "-----------------------------------"

apt-get install -y \
    curl \
    wget \
    git \
    nano \
    htop \
    net-tools \
    ufw

echo "✅ Utilities installed"

echo ""
echo "🔥 Step 5/5: Configure firewall (optional)"
echo "-----------------------------------"

read -p "Do you want to configure UFW firewall? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Allow SSH (important!)
    ufw allow 22/tcp

    # Allow HTTP/HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp

    # Allow custom ports (backend, database)
    ufw allow 3000/tcp  # Backend API

    # Enable firewall
    echo "y" | ufw enable

    ufw status
    echo "✅ Firewall configured"
else
    echo "⏭️  Skipped firewall configuration"
fi

echo ""
echo "🎉 SETUP COMPLETE!"
echo "=================="
echo ""
echo "✅ Docker: $(docker --version)"
echo "✅ Docker Compose: $(docker compose version)"
echo ""
echo "📝 Next Steps:"
echo ""
echo "1. If you added a user to docker group, LOG OUT and LOG IN again"
echo ""
echo "2. Deploy the chatbot with ONE of these options:"
echo ""
echo "   📍 OPTION A: Full Version (with AI - need 16GB+ RAM):"
echo "   curl -fsSL https://raw.githubusercontent.com/[repo]/main/scripts/install.sh | bash"
echo ""
echo "   📍 OPTION B: Light Version (without AI - works on 4GB RAM):"
echo "   curl -fsSL https://raw.githubusercontent.com/[repo]/main/scripts/install-light.sh | bash"
echo ""
echo "   📍 OPTION C: Manual deployment with git:"
echo "   git clone https://github.com/[repo]/emergency-chatbot.git"
echo "   cd emergency-chatbot"
echo "   bash scripts/deploy.sh     # Full version"
echo "   # OR"
echo "   bash scripts/deploy-light.sh  # Light version"
echo ""
echo "🆘 For help: https://github.com/[repo]/issues"
echo ""
