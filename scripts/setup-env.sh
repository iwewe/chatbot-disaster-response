#!/bin/bash

# ============================================
# INTERACTIVE .ENV SETUP SCRIPT
# ============================================
# Setup environment variables interactively with validation

set -e

echo "🔧 Emergency Chatbot - Environment Setup"
echo "=========================================="
echo ""

# Check if .env.example exists
if [ ! -f .env.example ]; then
    echo "❌ .env.example not found!"
    echo "   Please run this script from the project root directory."
    exit 1
fi

# Backup existing .env if exists
if [ -f .env ]; then
    echo "⚠️  Existing .env file found"
    read -p "Backup and recreate? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
        echo "✅ Backup created"
    else
        echo "Setup cancelled"
        exit 0
    fi
fi

# Copy from example
cp .env.example .env

echo ""
echo "📝 Please provide the following configuration:"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📱 WhatsApp Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# WhatsApp Phone Number ID
while true; do
    read -p "WhatsApp Phone Number ID: " WHATSAPP_PHONE_NUMBER_ID
    if [ -n "$WHATSAPP_PHONE_NUMBER_ID" ]; then
        break
    else
        echo "❌ This field is required!"
    fi
done

# WhatsApp Access Token
while true; do
    read -p "WhatsApp Access Token: " WHATSAPP_ACCESS_TOKEN
    if [ -n "$WHATSAPP_ACCESS_TOKEN" ]; then
        break
    else
        echo "❌ This field is required!"
    fi
done

# WhatsApp Verify Token
while true; do
    read -p "WhatsApp Verify Token (create a random string): " WHATSAPP_VERIFY_TOKEN
    if [ -z "$WHATSAPP_VERIFY_TOKEN" ]; then
        WHATSAPP_VERIFY_TOKEN=$(openssl rand -hex 16)
        echo "✅ Auto-generated: $WHATSAPP_VERIFY_TOKEN"
    fi
    break
done

# WhatsApp Business Account ID
while true; do
    read -p "WhatsApp Business Account ID: " WHATSAPP_BUSINESS_ACCOUNT_ID
    if [ -n "$WHATSAPP_BUSINESS_ACCOUNT_ID" ]; then
        break
    else
        echo "❌ This field is required!"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📬 Telegram Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Telegram Bot Token
while true; do
    read -p "Telegram Bot Token: " TELEGRAM_BOT_TOKEN
    if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
        break
    else
        echo "❌ This field is required!"
    fi
done

# Telegram Admin Chat ID
while true; do
    read -p "Telegram Admin Chat ID: " TELEGRAM_ADMIN_CHAT_ID
    if [ -n "$TELEGRAM_ADMIN_CHAT_ID" ]; then
        break
    else
        echo "❌ This field is required!"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 API Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Choose API Base URL option:"
echo "  1) Local development (http://localhost:3000)"
echo "  2) Server IP address (http://YOUR_IP:3000)"
echo "  3) Domain with HTTP (http://yourdomain.com)"
echo "  4) Domain with HTTPS (https://yourdomain.com)"
echo "  5) Custom URL"
echo ""

while true; do
    read -p "Select option (1-5): " API_OPTION
    case $API_OPTION in
        1)
            API_BASE_URL="http://localhost:3000"
            break
            ;;
        2)
            read -p "Enter your server IP address: " SERVER_IP
            API_BASE_URL="http://${SERVER_IP}:3000"
            break
            ;;
        3)
            read -p "Enter your domain (without http://): " DOMAIN
            API_BASE_URL="http://${DOMAIN}"
            break
            ;;
        4)
            read -p "Enter your domain (without https://): " DOMAIN
            API_BASE_URL="https://${DOMAIN}"
            break
            ;;
        5)
            read -p "Enter full URL (with http:// or https://): " API_BASE_URL
            break
            ;;
        *)
            echo "❌ Invalid option. Please choose 1-5."
            ;;
    esac
done

echo "✅ API Base URL: $API_BASE_URL"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 Security Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Generate JWT Secret
JWT_SECRET=$(openssl rand -hex 32)
echo "✅ JWT Secret auto-generated (64 characters)"

# Generate Database Password
DB_PASSWORD=$(openssl rand -hex 16)
echo "✅ Database password auto-generated (32 characters)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚙️  Deployment Mode"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if mode is pre-selected via environment variable
if [ -n "$DEPLOY_MODE_DEFAULT" ]; then
    DEPLOY_MODE=$DEPLOY_MODE_DEFAULT
    case $DEPLOY_MODE in
        1)
            OLLAMA_BASE_URL="http://disabled:11434"
            OLLAMA_FALLBACK_ENABLED="true"
            echo "✅ LIGHT mode auto-selected (rule-based extraction)"
            ;;
        2)
            OLLAMA_BASE_URL="http://emergency_ollama:11434"
            OLLAMA_FALLBACK_ENABLED="true"
            echo "✅ FULL mode auto-selected (AI-powered)"
            ;;
    esac
else
    echo "Select deployment mode:"
    echo "  1) LIGHT - Rule-based extraction (4GB RAM, no AI)"
    echo "  2) FULL  - AI-powered with Ollama (16GB RAM required)"
    echo ""

    while true; do
        read -p "Select mode (1-2): " DEPLOY_MODE
        case $DEPLOY_MODE in
            1)
                OLLAMA_BASE_URL="http://disabled:11434"
                OLLAMA_FALLBACK_ENABLED="true"
                echo "✅ LIGHT mode selected (rule-based extraction)"
                break
                ;;
            2)
                OLLAMA_BASE_URL="http://emergency_ollama:11434"
                OLLAMA_FALLBACK_ENABLED="true"
                echo "✅ FULL mode selected (AI-powered)"
                break
                ;;
            *)
                echo "❌ Invalid option. Please choose 1 or 2."
                ;;
        esac
    done
fi

echo ""
echo "💾 Writing configuration to .env..."
echo ""

# Update .env file
sed -i "s|WHATSAPP_PHONE_NUMBER_ID=.*|WHATSAPP_PHONE_NUMBER_ID=$WHATSAPP_PHONE_NUMBER_ID|" .env
sed -i "s|WHATSAPP_ACCESS_TOKEN=.*|WHATSAPP_ACCESS_TOKEN=$WHATSAPP_ACCESS_TOKEN|" .env
sed -i "s|WHATSAPP_VERIFY_TOKEN=.*|WHATSAPP_VERIFY_TOKEN=$WHATSAPP_VERIFY_TOKEN|" .env
sed -i "s|WHATSAPP_BUSINESS_ACCOUNT_ID=.*|WHATSAPP_BUSINESS_ACCOUNT_ID=$WHATSAPP_BUSINESS_ACCOUNT_ID|" .env
sed -i "s|TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN|" .env
sed -i "s|TELEGRAM_ADMIN_CHAT_ID=.*|TELEGRAM_ADMIN_CHAT_ID=$TELEGRAM_ADMIN_CHAT_ID|" .env
sed -i "s|API_BASE_URL=.*|API_BASE_URL=$API_BASE_URL|" .env
sed -i "s|JWT_SECRET=.*|JWT_SECRET=$JWT_SECRET|" .env
sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$DB_PASSWORD|" .env
sed -i "s|DATABASE_URL=.*|DATABASE_URL=postgresql://emergency_user:$DB_PASSWORD@emergency_db:5432/emergency_chatbot|" .env
sed -i "s|OLLAMA_BASE_URL=.*|OLLAMA_BASE_URL=$OLLAMA_BASE_URL|" .env
sed -i "s|OLLAMA_FALLBACK_ENABLED=.*|OLLAMA_FALLBACK_ENABLED=$OLLAMA_FALLBACK_ENABLED|" .env

echo "✅ Configuration saved to .env"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Configuration Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "WhatsApp Phone ID: $WHATSAPP_PHONE_NUMBER_ID"
echo "WhatsApp Business Account: $WHATSAPP_BUSINESS_ACCOUNT_ID"
echo "Telegram Bot Token: ${TELEGRAM_BOT_TOKEN:0:20}..."
echo "Telegram Admin Chat: $TELEGRAM_ADMIN_CHAT_ID"
echo "API Base URL: $API_BASE_URL"
echo "JWT Secret: ${JWT_SECRET:0:16}... (64 chars)"
echo "DB Password: ${DB_PASSWORD:0:8}... (32 chars)"
echo "Deployment Mode: $([ "$OLLAMA_BASE_URL" = "http://disabled:11434" ] && echo "LIGHT (Rule-based)" || echo "FULL (AI-powered)")"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Environment setup complete!"
echo ""
echo "📝 Next steps:"
if [ "$OLLAMA_BASE_URL" = "http://disabled:11434" ]; then
    echo "   bash scripts/deploy-light.sh"
else
    echo "   bash scripts/deploy.sh"
fi
echo ""
