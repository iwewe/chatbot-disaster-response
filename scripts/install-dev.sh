#!/bin/bash

# ============================================
# DEVELOPMENT INSTALLER (WRAPPER)
# ============================================
# Downloads dev-setup.sh and runs it with proper stdin
# Safe for curl | bash usage

set -e

REPO_BRANCH="claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf"
SCRIPT_URL="https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/refs/heads/${REPO_BRANCH}/scripts/dev-setup.sh"

echo "🚀 Emergency Chatbot - Development Installer"
echo "=============================================="
echo ""

# Check if running via pipe
if [ -t 0 ]; then
    IS_INTERACTIVE=true
else
    IS_INTERACTIVE=false
fi

# Download setup script
echo "📥 Downloading development setup script..."
if command -v curl &> /dev/null; then
    curl -fsSL "$SCRIPT_URL" -o /tmp/emergency-dev-setup.sh
elif command -v wget &> /dev/null; then
    wget -q "$SCRIPT_URL" -O /tmp/emergency-dev-setup.sh
else
    echo "❌ curl or wget required"
    exit 1
fi

chmod +x /tmp/emergency-dev-setup.sh

echo "✅ Script downloaded"
echo ""

# Run with proper stdin
if [ "$IS_INTERACTIVE" = true ]; then
    # Has stdin, can run interactively
    bash /tmp/emergency-dev-setup.sh
else
    # No stdin (piped), run in terminal
    echo "⚠️  Running via pipe detected"
    echo ""
    echo "Please run the downloaded script manually for interactive setup:"
    echo ""
    echo "  bash /tmp/emergency-dev-setup.sh"
    echo ""
    echo "Or run directly without pipe:"
    echo ""
    echo "  curl -fsSL $SCRIPT_URL | bash -s"
    echo ""

    # Clean up
    rm -f /tmp/emergency-dev-setup.sh

    exit 0
fi

# Clean up
rm -f /tmp/emergency-dev-setup.sh
