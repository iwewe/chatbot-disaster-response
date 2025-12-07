# Emergency Response System - Deployment Guide

Panduan lengkap untuk deployment sistem Emergency Response Chatbot di server.

## 📋 Prerequisites

Sebelum memulai deployment, pastikan server Anda memiliki:

- **Operating System**: Ubuntu 20.04+ / Debian 11+ / CentOS 8+
- **RAM**: Minimum 4GB (Recommended 8GB+)
- **Storage**: Minimum 20GB free space
- **Docker**: Version 20.10+
- **Docker Compose**: Version 2.0+
- **Network**: Port 3000, 5432, 6379, 11434, 80/8080 available

### Install Docker (jika belum terinstall)

```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Logout dan login kembali untuk apply group changes
```

## 🚀 Deployment Methods

### Method 1: Git Deployment (Recommended)

Untuk server dengan Git installed dan akses ke GitHub.

```bash
# Download dan jalankan deployment script
curl -fsSL https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf/scripts/deploy-git.sh -o deploy-git.sh

chmod +x deploy-git.sh
./deploy-git.sh
```

Script akan:
- Clone repository dari GitHub
- Backup .env file yang ada
- Build Docker containers
- Start semua services
- Run database migrations
- Check admin user

### Method 2: Curl Deployment

Untuk server tanpa Git, download langsung dari GitHub.

```bash
# Download dan jalankan deployment script
curl -fsSL https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf/scripts/deploy-curl.sh -o deploy-curl.sh

chmod +x deploy-curl.sh
./deploy-curl.sh
```

Script akan:
- Download semua file yang diperlukan menggunakan curl
- Setup directory structure
- Build dan start containers
- Run migrations

## ⚙️ Konfigurasi

### 1. Environment Variables

Edit file `.env` di directory installation:

```bash
cd ~/chatbot-disaster-response
nano .env
```

**Configuration penting:**

```env
# Node Environment
NODE_ENV=production

# WhatsApp Configuration
WHATSAPP_MODE=meta                          # meta, baileys, atau hybrid
WHATSAPP_PHONE_NUMBER_ID=your_phone_id      # Dari Meta Developer Console
WHATSAPP_ACCESS_TOKEN=your_access_token     # System User Token (permanent)
WHATSAPP_VERIFY_TOKEN=your_verify_token     # Custom verify token
WHATSAPP_BUSINESS_ACCOUNT_ID=your_business_id

# Telegram (optional)
TELEGRAM_BOT_TOKEN=your_telegram_token

# Ollama AI
OLLAMA_MODEL=qwen2.5:1.5b                   # Atau qwen2.5:7b untuk accuracy lebih baik

# Database
DATABASE_URL=postgresql://emergency:emergency123@postgres:5432/emergency_db

# Redis
REDIS_URL=redis://redis:6379

# API Configuration
API_BASE_URL=https://emresc.iwewe.web.id    # Domain produksi Anda

# Admin Password (untuk dashboard login)
ADMIN_PASSWORD=your_secure_password         # Ganti dengan password yang kuat

# JWT Secret
JWT_SECRET=your_random_secret_string        # Generate: openssl rand -base64 32

# Logging
LOG_LEVEL=info
```

### 2. WhatsApp Meta API Setup

1. Buka [Meta for Developers](https://developers.facebook.com/)
2. Create atau select existing Business App
3. Add WhatsApp product
4. Get:
   - **Phone Number ID**: Business Settings > WhatsApp Accounts
   - **Access Token**: System Users > Generate Token (permanent)
   - **Verify Token**: Custom string (gunakan yang sama di .env)
   - **Business Account ID**: Business Settings

5. Setup Webhook:
   - URL: `https://your-domain.com/webhook`
   - Verify Token: (sama dengan di .env)
   - Subscribe to: `messages`

6. Add test phone numbers (Development mode):
   - WhatsApp > API Setup > Phone numbers
   - Verify dengan OTP

### 3. Ollama Model Setup

Pull model AI untuk extraction:

```bash
# Model kecil (1.5B - cepat, RAM rendah)
docker exec emergency_ollama ollama pull qwen2.5:1.5b

# Atau model besar (7B - lebih akurat, butuh RAM lebih)
docker exec emergency_ollama ollama pull qwen2.5:7b
```

Update `.env` sesuai model yang dipilih.

## 📊 Dashboard Deployment

Deploy web dashboard menggunakan script:

```bash
cd ~/chatbot-disaster-response/scripts
chmod +x deploy-dashboard.sh
./deploy-dashboard.sh
```

**Pilih deployment method:**

1. **Nginx (Production)**: Deploy menggunakan Nginx web server
   - Konfigurasi SSL/HTTPS support
   - Proxy API requests ke backend
   - Caching dan compression
   - Recommended untuk production

2. **Docker Nginx**: Deploy dashboard sebagai Docker container
   - Mudah di-manage
   - Isolated environment
   - Port 8080 default

3. **Simple HTTP Server**: Development only
   - Python HTTP server
   - Jangan gunakan untuk production

### Dashboard URLs

- **Nginx**: `http://your-domain` atau `http://localhost`
- **Docker**: `http://localhost:8080`

## 👤 Setup Admin User

Create admin user untuk dashboard access:

```bash
cd ~/chatbot-disaster-response/scripts
chmod +x setup-admin.sh
./setup-admin.sh
```

Enter:
- **Phone Number**: Nomor WhatsApp (contoh: 628123456789)
- **Full Name**: Nama lengkap admin

Set password di `.env`:
```env
ADMIN_PASSWORD=your_secure_password
```

Restart backend:
```bash
docker compose restart backend
```

**Login Dashboard:**
- **Username**: Phone number yang diinput
- **Password**: ADMIN_PASSWORD dari .env

## 🔄 Management Scripts

Semua script ada di directory `scripts/`. Make executable:

```bash
cd ~/chatbot-disaster-response/scripts
chmod +x *.sh
```

### Available Scripts

| Script | Fungsi |
|--------|--------|
| `deploy-git.sh` | Deploy/update menggunakan Git |
| `deploy-curl.sh` | Deploy/update menggunakan Curl |
| `deploy-dashboard.sh` | Deploy web dashboard |
| `update-dashboard.sh` | Update dashboard saja |
| `restart-services.sh` | Restart services (interactive menu) |
| `setup-admin.sh` | Create/update admin user |
| `monitor.sh` | Monitor system health |

### Restart Services

```bash
./restart-services.sh
```

Menu options:
1. All services
2. Backend only
3. Database
4. Redis
5. Ollama
6. Dashboard
7. Rebuild backend (no cache)
8. Full rebuild
9. View logs

### Monitor System

```bash
./monitor.sh
```

Atau continuous monitoring:
```bash
watch -n 5 ./monitor.sh
```

## 🌐 Production Setup dengan Cloudflared

Jika menggunakan Cloudflared tunnel:

```bash
# Install cloudflared
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# Login dan create tunnel
cloudflared tunnel login
cloudflared tunnel create emergency-response

# Configure tunnel
nano ~/.cloudflared/config.yml
```

Config example:
```yaml
tunnel: <tunnel-id>
credentials-file: /home/user/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: emresc.iwewe.web.id
    service: http://localhost:80
  - service: http_status:404
```

```bash
# Run tunnel as service
cloudflared tunnel run emergency-response
```

## 🔒 Security Checklist

- [ ] Change default passwords in `.env`
- [ ] Generate strong JWT_SECRET
- [ ] Use permanent WhatsApp access token (not temporary)
- [ ] Enable firewall (UFW):
  ```bash
  sudo ufw allow 22/tcp   # SSH
  sudo ufw allow 80/tcp   # HTTP
  sudo ufw allow 443/tcp  # HTTPS
  sudo ufw enable
  ```
- [ ] Setup SSL/HTTPS with Let's Encrypt:
  ```bash
  sudo apt install certbot python3-certbot-nginx
  sudo certbot --nginx -d your-domain.com
  ```
- [ ] Regular backups of database:
  ```bash
  docker exec emergency_db pg_dump -U emergency emergency_db > backup.sql
  ```
- [ ] Limit WhatsApp test numbers in production
- [ ] Enable rate limiting in Nginx

## 📝 Update Procedure

### Update Full System (Git method)

```bash
cd ~/chatbot-disaster-response
git pull origin claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf
docker compose down
docker compose build --no-cache
docker compose up -d
```

### Update Dashboard Only

```bash
./scripts/update-dashboard.sh
```

### Update Backend Only

```bash
./scripts/restart-services.sh
# Choose option 7: Rebuild backend (no cache)
```

## 🐛 Troubleshooting

### Backend tidak start

```bash
# Check logs
docker logs emergency_backend

# Common issues:
# 1. Database not ready - wait 30 seconds and restart
docker compose restart backend

# 2. Migration failed - run manually
docker exec emergency_backend npx prisma db push
```

### Dashboard tidak load

```bash
# Check Nginx logs (if using Nginx)
sudo tail -f /var/log/nginx/emergency-dashboard-error.log

# Check Docker dashboard (if using Docker)
docker logs emergency_dashboard

# Clear browser cache: Ctrl+Shift+R
```

### Ollama 404 Error

```bash
# Check if Ollama is running
docker ps | grep ollama

# Pull model if not exists
docker exec emergency_ollama ollama pull qwen2.5:1.5b

# Check model list
docker exec emergency_ollama ollama list
```

### WhatsApp webhook tidak terima message

```bash
# Check webhook verification
curl http://localhost:3000/webhook?hub.mode=subscribe&hub.challenge=test&hub.verify_token=YOUR_VERIFY_TOKEN

# Check backend logs
docker logs -f emergency_backend

# Verify Meta webhook configuration
# - URL must be HTTPS (use cloudflared)
# - Verify token must match .env
# - Subscribe to 'messages' field
```

### Database connection failed

```bash
# Check PostgreSQL
docker logs emergency_db

# Restart database
docker compose restart postgres

# Wait 10 seconds then restart backend
sleep 10
docker compose restart backend
```

## 📊 Monitoring & Logs

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f backend
docker compose logs -f postgres
docker compose logs -f ollama

# Last 100 lines
docker compose logs --tail=100 backend
```

### Check Health

```bash
# API health endpoint
curl http://localhost:3000/health | jq '.'

# Monitor script
./scripts/monitor.sh
```

### Database Backup

```bash
# Create backup
docker exec emergency_db pg_dump -U emergency emergency_db > backup-$(date +%Y%m%d).sql

# Restore backup
docker exec -i emergency_db psql -U emergency emergency_db < backup.sql
```

## 📞 Support & Resources

- **GitHub Repository**: https://github.com/iwewe/chatbot-disaster-response
- **Documentation**: README.md di repository
- **Meta WhatsApp Docs**: https://developers.facebook.com/docs/whatsapp
- **Ollama Docs**: https://ollama.ai/

## 🎯 Quick Start Checklist

- [ ] Server setup dengan Docker installed
- [ ] Clone/download repository
- [ ] Configure `.env` file
- [ ] Run deployment script
- [ ] Setup WhatsApp Meta API webhook
- [ ] Pull Ollama model
- [ ] Deploy dashboard
- [ ] Create admin user
- [ ] Test WhatsApp message flow
- [ ] Test dashboard login
- [ ] Setup SSL/HTTPS
- [ ] Configure backups

---

**Last Updated**: 2025-12-07
**Version**: 1.0.0
