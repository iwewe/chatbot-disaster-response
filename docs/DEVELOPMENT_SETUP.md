# Development Setup Guide

## 🚀 Quick Start (No Git Required!)

One-liner untuk setup development environment dengan **Baileys + Ollama**:

```bash
curl -fsSL https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/refs/heads/claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf/scripts/dev-setup.sh | bash
```

**What it does:**
- ✅ Downloads project (no git needed)
- ✅ Configures for development (Baileys + Ollama)
- ✅ Sets up environment variables
- ✅ Deploys with Docker Compose
- ✅ Auto-configures debug mode

**You'll need to provide:**
- Telegram Bot Token (dari @BotFather)
- Telegram Admin Chat ID
- Optional: API Base URL (default: localhost:3000)

**After deployment:**
- Scan QR code untuk WhatsApp (Baileys)
- Wait ~10 minutes untuk Ollama download model
- Start testing!

---

## 📋 What You Get

### Development Configuration

| Component | Mode | Details |
|-----------|------|---------|
| **WhatsApp** | Baileys | Scan QR code, no Meta account needed |
| **AI** | Ollama (qwen2.5:7b) | Full AI extraction capabilities |
| **Environment** | Development | Debug mode, verbose logging |
| **API** | http://localhost:3000 | Local development server |
| **Database** | PostgreSQL 15 | Auto-configured |
| **Cache** | Redis 7 | Auto-configured |

### Resource Requirements

- **RAM:** 16GB minimum (32GB recommended)
- **CPU:** 8+ cores
- **Disk:** 50GB free space (for Ollama model)
- **OS:** Ubuntu 20.04+, macOS, Windows WSL2

---

## 🎯 Step-by-Step Manual Setup

If you prefer manual setup or want to understand what's happening:

### Step 1: Download Project

```bash
# Create directory
mkdir -p ~/emergency-chatbot-dev
cd ~/emergency-chatbot-dev

# Download from GitHub
BRANCH="claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf"
curl -L "https://github.com/iwewe/chatbot-disaster-response/archive/refs/heads/${BRANCH}.zip" -o archive.zip

# Extract
unzip -q archive.zip
mv chatbot-disaster-response-*/* .
mv chatbot-disaster-response-*/.* . 2>/dev/null || true
rm -rf chatbot-disaster-response-* archive.zip
```

### Step 2: Configure Environment

```bash
# Copy example
cp .env.example .env

# Edit configuration
nano .env
```

**Minimal development .env:**
```bash
# Environment
NODE_ENV=development
DEBUG_MODE=true
LOG_LEVEL=debug
API_BASE_URL=http://localhost:3000

# WhatsApp: Baileys mode
WHATSAPP_MODE=baileys
WHATSAPP_PHONE_NUMBER_ID=baileys_dev
WHATSAPP_ACCESS_TOKEN=baileys_dev
WHATSAPP_VERIFY_TOKEN=baileys_dev
WHATSAPP_BUSINESS_ACCOUNT_ID=baileys_dev

# Telegram (REQUIRED - get from @BotFather)
TELEGRAM_BOT_TOKEN=your_telegram_bot_token
TELEGRAM_ADMIN_CHAT_ID=your_chat_id

# Database
DATABASE_URL=postgresql://postgres:postgres@postgres:5432/emergency_chatbot
POSTGRES_PASSWORD=postgres

# Redis
REDIS_HOST=redis
REDIS_PORT=6379

# JWT
JWT_SECRET=$(openssl rand -hex 32)
JWT_EXPIRES_IN=7d

# Ollama (AI enabled)
OLLAMA_BASE_URL=http://emergency_ollama:11434
OLLAMA_MODEL=qwen2.5:7b
OLLAMA_TIMEOUT=30000
OLLAMA_FALLBACK_ENABLED=true

# System
AUTO_VERIFY_TRUST_LEVEL=3
RATE_LIMIT_PER_MINUTE=10
DATA_RETENTION_DAYS=180
```

### Step 3: Deploy

```bash
# Pull images
docker compose pull

# Build backend
docker compose build backend

# Start all services
docker compose up -d

# View logs
docker compose logs -f
```

---

## 📱 WhatsApp Setup (Baileys)

### Getting QR Code

```bash
# View backend logs
docker logs emergency_backend -f
```

**QR code will appear in console:**
```
📱 Scan QR Code dengan WhatsApp Anda:

████ ▄▄▄▄▄ █▀█ █▄▀▀▀▄█ ▄▄▄▄▄ ████
████ █   █ █▀▀▀█ ▀ ▀▀█ █   █ ████
████ █▄▄▄█ █▀ █▀▀ ▀ ▄█ █▄▄▄█ ████
...
```

### Scan Steps

1. Open WhatsApp di phone Anda
2. Go to **Settings** → **Linked Devices**
3. Tap **Link a Device**
4. Scan QR code from console
5. ✅ Connected!

**Session persists:** Setelah scan pertama kali, tidak perlu scan lagi saat restart.

---

## 🤖 Ollama Setup (AI)

### Model Download

First time startup, Ollama akan download model (~5GB):

```bash
# Watch download progress
docker logs emergency_ollama -f
```

**Expected output:**
```
pulling manifest
pulling 8934d96d3f08... 100% ▕████████████████▏ 4.7 GB
pulling 8c17c2ebb0ea... 100% ▕████████████████▏  7.0 kB
pulling 7c23fb36d801... 100% ▕████████████████▏  4.8 kB
pulling 2e0493f67d0c... 100% ▕████████████████▏   59 B
pulling fa8235e5b48f... 100% ▕████████████████▏  485 B
verifying sha256 digest
writing manifest
success
```

**Download time:**
- Fast internet (100 Mbps): ~5-10 minutes
- Medium (50 Mbps): ~10-15 minutes
- Slow (10 Mbps): ~30-60 minutes

### Testing AI

After model download completes:

```bash
# Test Ollama
curl http://localhost:11434/api/generate -d '{
  "model": "qwen2.5:7b",
  "prompt": "Hello!",
  "stream": false
}'
```

---

## 🔧 Development Workflow

### Daily Development

```bash
# Start services
cd ~/emergency-chatbot-dev
docker compose up -d

# Watch logs
docker compose logs -f backend

# Test API
curl http://localhost:3000/health
```

### Making Code Changes

```bash
# Stop backend
docker compose stop backend

# Edit code
nano backend/src/services/message-processor.service.js

# Rebuild and restart
docker compose build backend
docker compose up -d backend

# Watch logs
docker logs emergency_backend -f
```

### Database Management

```bash
# Access database
docker exec -it emergency_db psql -U postgres -d emergency_chatbot

# Run migrations
docker exec emergency_backend npx prisma migrate dev

# View data with Prisma Studio
docker exec -it emergency_backend npx prisma studio
# Open http://localhost:5555
```

### Testing Messages

```bash
# Send test message via WhatsApp
# (Scan QR code first, then send message from your phone)

# Check logs
docker logs emergency_backend -f

# Check Telegram notifications
# (Should receive notification in your Telegram chat)
```

---

## 🐛 Debugging

### View All Logs

```bash
# All services
docker compose logs -f

# Specific service
docker logs emergency_backend -f
docker logs emergency_db -f
docker logs emergency_redis -f
docker logs emergency_ollama -f
```

### Check Service Health

```bash
# API health
curl http://localhost:3000/health

# Database
docker exec emergency_db pg_isready -U postgres

# Redis
docker exec emergency_redis redis-cli ping

# Ollama
curl http://localhost:11434/api/tags
```

### Common Issues

#### 1. Baileys Not Connecting

**Problem:** QR code tidak muncul

**Solutions:**
```bash
# Restart backend
docker restart emergency_backend

# Check logs
docker logs emergency_backend --tail 100

# Clear session (force re-scan)
docker exec emergency_backend rm -rf /app/baileys-session/*
docker restart emergency_backend
```

#### 2. Ollama Model Not Downloading

**Problem:** Model stuck downloading

**Solutions:**
```bash
# Check disk space
df -h

# Restart Ollama
docker restart emergency_ollama

# Manual pull
docker exec emergency_ollama ollama pull qwen2.5:7b
```

#### 3. Database Connection Error

**Problem:** Backend can't connect to database

**Solutions:**
```bash
# Check if DB is running
docker ps | grep emergency_db

# Check DB logs
docker logs emergency_db

# Restart DB
docker restart emergency_db

# Wait and restart backend
sleep 10
docker restart emergency_backend
```

#### 4. Port Already in Use

**Problem:** Port 3000/5432/6379 already used

**Solutions:**
```bash
# Find process using port
sudo lsof -i :3000
sudo lsof -i :5432
sudo lsof -i :6379

# Kill process or change port in docker-compose.yml
```

---

## 📊 Testing Features

### 1. Test WhatsApp Message Reception

Send message dari WhatsApp Anda (setelah scan QR):

```
Ada 3 orang terluka di Desa Sukamaju RT 02
```

**Expected:**
- ✅ Message received in logs
- ✅ AI extracts data (via Ollama)
- ✅ Report created in database
- ✅ Confirmation sent back via WhatsApp
- ✅ Telegram notification sent

### 2. Test Media Upload

Send foto/video via WhatsApp with caption:

```
Foto korban di Posko Desa Sukamaju
```

**Expected:**
- ✅ Media downloaded
- ✅ Saved to Docker volume
- ✅ Database record created

### 3. Test AI Extraction

Send complex natural language:

```
Saya melihat ada sekitar 5 orang yang terluka parah di daerah
Sukamaju dekat masjid, mereka butuh bantuan medis segera dan
juga makanan untuk sekitar 20 orang pengungsi
```

**Expected:**
- ✅ Ollama processes message
- ✅ Extracts: 5 korban, lokasi Sukamaju, urgency HIGH
- ✅ Extracts: kebutuhan medis + makanan
- ✅ Creates proper report structure

### 4. Test API Endpoints

```bash
# Health check
curl http://localhost:3000/health

# Create admin user
curl -X POST http://localhost:3000/auth/setup-admin \
  -H 'Content-Type: application/json' \
  -d '{
    "phoneNumber": "+6281234567890",
    "name": "Admin Dev",
    "password": "dev123456"
  }'

# Login
curl -X POST http://localhost:3000/auth/login \
  -H 'Content-Type: application/json' \
  -d '{
    "phoneNumber": "+6281234567890",
    "password": "dev123456"
  }'

# Get reports (use token from login)
curl http://localhost:3000/api/reports \
  -H 'Authorization: Bearer YOUR_TOKEN_HERE'
```

---

## 🧹 Cleanup

### Stop Services

```bash
cd ~/emergency-chatbot-dev
docker compose down
```

### Remove Everything

```bash
# Stop and remove containers + volumes
docker compose down -v

# Remove project directory
cd ~
rm -rf emergency-chatbot-dev
```

### Keep Data, Remove Containers Only

```bash
# Stop and remove containers (keep volumes)
docker compose down

# Restart later
docker compose up -d
```

---

## 🚀 Production Deployment

When ready to move to production:

```bash
# Switch to production config
cp .env .env.development
nano .env

# Change:
NODE_ENV=production
DEBUG_MODE=false
LOG_LEVEL=info

# Optional: Switch to Meta API
WHATSAPP_MODE=meta  # or hybrid
# Add Meta credentials

# Redeploy
docker compose down
docker compose up -d
```

---

## 📚 Additional Resources

- **Main Documentation:** [README.md](../README.md)
- **Baileys Guide:** [BAILEYS_SETUP.md](BAILEYS_SETUP.md)
- **Deployment Guide:** [DEPLOYMENT.md](DEPLOYMENT.md)
- **Operator Manual:** [OPERATOR_MANUAL.md](OPERATOR_MANUAL.md)

---

## 🆘 Getting Help

### Check Logs First

```bash
# Comprehensive log check
docker compose logs --tail=100

# Service-specific
docker logs emergency_backend --tail=100
docker logs emergency_ollama --tail=100
```

### Common Commands Reference

```bash
# Status
docker compose ps

# Restart all
docker compose restart

# Restart specific service
docker restart emergency_backend

# View resource usage
docker stats

# Enter container shell
docker exec -it emergency_backend sh
```

### GitHub Issues

If you encounter bugs:
1. Check logs
2. Search existing issues
3. Create new issue with:
   - Error message
   - Steps to reproduce
   - Environment details (OS, Docker version)

---

## 🎉 Happy Developing!

Your development environment includes:

- ✅ **WhatsApp Web (Baileys)** - No Meta account needed
- ✅ **Ollama AI** - Full natural language processing
- ✅ **PostgreSQL** - Complete database
- ✅ **Redis** - Caching and queues
- ✅ **Debug mode** - Verbose logging
- ✅ **Hot reload** - Fast iteration

**Start coding and test with real WhatsApp messages!** 🚀
