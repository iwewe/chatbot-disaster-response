# 🚀 Quick Start Guide - Emergency Response System

Panduan singkat untuk deployment dan penggunaan sistem.

## 📦 Installation (Pilih Salah Satu)

### Option 1: Git Method (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf/scripts/deploy-git.sh | bash
```

### Option 2: Curl Method (No Git Required)

```bash
curl -fsSL https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf/scripts/deploy-curl.sh | bash
```

## ⚙️ Konfigurasi Awal

### 1. Edit .env File

```bash
cd ~/chatbot-disaster-response
nano .env
```

**Minimal Configuration:**

```env
# WhatsApp Meta API
WHATSAPP_MODE=meta
WHATSAPP_PHONE_NUMBER_ID=your_phone_id
WHATSAPP_ACCESS_TOKEN=your_access_token
WHATSAPP_VERIFY_TOKEN=D1s4ster2025

# Admin Password
ADMIN_PASSWORD=your_secure_password

# Ollama Model
OLLAMA_MODEL=qwen2.5:1.5b
```

### 2. Pull Ollama Model

```bash
docker exec emergency_ollama ollama pull qwen2.5:1.5b
```

### 3. Setup Admin User

```bash
cd ~/chatbot-disaster-response/scripts
./setup-admin.sh
```

### 4. Deploy Dashboard

```bash
./deploy-dashboard.sh
# Pilih: 1 untuk Nginx, 2 untuk Docker
```

## 🎯 Quick Commands

### Check System Status

```bash
cd ~/chatbot-disaster-response/scripts
./monitor.sh
```

### Restart Services

```bash
./restart-services.sh
# Interactive menu - pilih service yang mau di-restart
```

### Update Dashboard

```bash
./update-dashboard.sh
```

### View Logs

```bash
# Backend logs
docker logs -f emergency_backend

# All services
docker compose logs -f
```

## 🌐 Access URLs

- **Backend API**: http://localhost:3000
- **Dashboard (Docker)**: http://localhost:8080
- **Dashboard (Nginx)**: http://localhost atau http://your-domain
- **Ollama API**: http://localhost:11434

## 🔧 Common Tasks

### Update System

```bash
cd ~/chatbot-disaster-response
git pull
docker compose down
docker compose build --no-cache
docker compose up -d
```

### Backup Database

```bash
docker exec emergency_db pg_dump -U emergency emergency_db > backup.sql
```

### Restart Specific Service

```bash
docker compose restart backend
# atau
./scripts/restart-services.sh
```

## 🐛 Troubleshooting

### Backend Not Starting

```bash
docker logs emergency_backend
docker compose restart backend
```

### Dashboard Not Loading

```bash
# Clear browser cache: Ctrl+Shift+R
# Check Nginx logs
sudo tail -f /var/log/nginx/emergency-dashboard-error.log
```

### Ollama 404

```bash
docker exec emergency_ollama ollama pull qwen2.5:1.5b
docker compose restart backend
```

## 📚 Full Documentation

Lihat [DEPLOYMENT.md](./DEPLOYMENT.md) untuk panduan lengkap.

## 🆘 Need Help?

1. Check logs: `docker compose logs -f`
2. Run monitor: `./scripts/monitor.sh`
3. Check DEPLOYMENT.md untuk troubleshooting detail
