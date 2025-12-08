# 🚀 Emergency Response Chatbot - Installation Guide

Panduan instalasi lengkap untuk **Emergency Response Chatbot** - sistem manajemen bencana berbasis WhatsApp dengan AI.

## 📋 Sistem Requirements

### Minimum:
- **OS**: Ubuntu 20.04+ / Debian 11+
- **RAM**: 4GB (8GB recommended untuk Ollama)
- **Disk**: 20GB free space
- **CPU**: 2 cores (4 cores recommended)

### Software (akan diinstall otomatis):
- Docker & Docker Compose
- Git
- Curl & Wget

## 🎯 Instalasi Cepat

### Untuk Server Baru (Fresh Install)

```bash
# 1. Download script instalasi
wget https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/main/install.sh

# 2. Jalankan sebagai root
sudo bash install.sh
```

Script akan menanyakan:
- 📁 Direktori instalasi (default: `/opt/emergency-chatbot`)
- 🗄️ Konfigurasi database (username, password, nama database)
- 👤 Admin credentials untuk dashboard
- 📱 Mode WhatsApp (Baileys gratis atau Meta Cloud API)
- 🔌 Port untuk Backend API (default: 3000) dan Dashboard (default: 8080)

**Durasi instalasi**: ~10-15 menit (tergantung koneksi internet untuk download Ollama model)

### What the Installer Does:

1. ✅ Check sistem requirements
2. ✅ Install Docker & dependencies
3. ✅ Download aplikasi dari GitHub
4. ✅ Generate configuration files (.env)
5. ✅ Build & start semua services (PostgreSQL, Redis, Ollama, Backend, Dashboard)
6. ✅ Setup database & migrations
7. ✅ Create admin user
8. ✅ Download Ollama AI model
9. ✅ Verify semua services running
10. ✅ Save credentials ke file

## 🔧 Manual Installation (Advanced)

Jika ingin install manual atau customize lebih lanjut:

### 1. Clone Repository

```bash
git clone https://github.com/iwewe/chatbot-disaster-response.git
cd chatbot-disaster-response
```

### 2. Create .env File

```bash
cp .env.example .env
nano .env
```

Edit konfigurasi sesuai kebutuhan:
- `DATABASE_URL` - PostgreSQL connection string
- `ADMIN_PASSWORD` - Password untuk dashboard
- `WHATSAPP_MODE` - Mode WhatsApp (baileys/meta)
- Dll.

### 3. Start Services

```bash
# Build & start all services
docker compose up -d --build

# Check status
docker compose ps

# View logs
docker logs -f emergency_backend
```

### 4. Initialize Database

```bash
# Run migrations
docker exec emergency_backend npx prisma db push

# Create admin user
docker exec emergency_backend node scripts/create-admin.js
```

### 5. Pull Ollama Model

```bash
docker exec emergency_ollama ollama pull qwen2.5:7b
```

## 📱 WhatsApp Integration

### Option 1: Baileys (FREE - Recommended untuk Development)

Set di `.env`:
```
WHATSAPP_MODE=baileys
```

Setelah backend start, ambil QR code:
```bash
docker logs emergency_backend | grep -A 30 "QR"
```

Scan QR code dengan WhatsApp di HP Anda.

### Option 2: Meta WhatsApp Cloud API (Official - untuk Production)

1. Buat Meta Business Account: https://business.facebook.com
2. Setup WhatsApp Business API: https://developers.facebook.com/apps
3. Dapatkan credentials:
   - Phone Number ID
   - Access Token (permanent)
   - Verify Token (custom string)

Set di `.env`:
```
WHATSAPP_MODE=meta
WHATSAPP_PHONE_NUMBER_ID=your_phone_id
WHATSAPP_ACCESS_TOKEN=your_token
WHATSAPP_VERIFY_TOKEN=your_verify_token
```

## 🌐 Accessing the System

### Web Dashboard
```
URL: http://localhost:8080
Username: admin (atau sesuai konfigurasi)
Password: [from CREDENTIALS.txt]
```

### Backend API
```
URL: http://localhost:3000
Health Check: http://localhost:3000/health
```

### Database (PostgreSQL)
```
Host: localhost:5432
Username: postgres (atau sesuai konfigurasi)
Password: [from CREDENTIALS.txt]
Database: emergency_chatbot
```

## 🔍 Troubleshooting

### Container tidak start

```bash
# Check logs
docker logs emergency_backend
docker logs emergency_db

# Restart services
docker compose restart

# Rebuild if needed
docker compose up -d --build --force-recreate
```

### Backend error "Database connection failed"

```bash
# Check PostgreSQL is running
docker exec emergency_db pg_isready

# Check .env DATABASE_URL
cat .env | grep DATABASE_URL

# Restart backend
docker compose restart backend
```

### Dashboard tidak bisa login

```bash
# Check backend API
curl http://localhost:3000/health

# Check admin user exists
docker exec emergency_backend npx prisma studio

# Reset admin password
docker exec emergency_backend node -e "
const { PrismaClient } = require('@prisma/client');
// Script to reset password
"
```

### WhatsApp QR tidak muncul (Baileys mode)

```bash
# Check backend logs
docker logs -f emergency_backend

# Pastikan WHATSAPP_MODE=baileys di .env
grep WHATSAPP_MODE .env

# Restart backend
docker compose restart backend
```

### Ollama model tidak ada

```bash
# Pull model manually
docker exec emergency_ollama ollama pull qwen2.5:7b

# Check available models
docker exec emergency_ollama ollama list
```

## 📊 Useful Commands

### Service Management

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# Restart specific service
docker compose restart backend

# View all services status
docker compose ps

# Remove all and start fresh
docker compose down -v
docker compose up -d --build
```

### Logs

```bash
# Follow backend logs
docker logs -f emergency_backend

# Follow dashboard logs
docker logs -f emergency_dashboard

# Follow database logs
docker logs -f emergency_db

# All logs together
docker compose logs -f
```

### Database

```bash
# Access PostgreSQL shell
docker exec -it emergency_db psql -U postgres -d emergency_chatbot

# Run Prisma Studio (database GUI)
docker exec -it emergency_backend npx prisma studio

# Backup database
docker exec emergency_db pg_dump -U postgres emergency_chatbot > backup.sql

# Restore database
cat backup.sql | docker exec -i emergency_db psql -U postgres emergency_chatbot
```

### Updates

```bash
# Pull latest code
cd /opt/emergency-chatbot
git pull

# Rebuild and restart
docker compose up -d --build

# Run new migrations
docker exec emergency_backend npx prisma db push
```

## 🔒 Security Recommendations

### For Production Deployment:

1. **Change default passwords** in `.env`:
   - `POSTGRES_PASSWORD`
   - `ADMIN_PASSWORD`
   - `JWT_SECRET`

2. **Use HTTPS** with reverse proxy (Nginx/Caddy):
   ```bash
   # Install Caddy
   apt install caddy

   # Configure /etc/caddy/Caddyfile
   your-domain.com {
       reverse_proxy localhost:8080
   }
   ```

3. **Firewall** - only expose necessary ports:
   ```bash
   ufw allow 80/tcp
   ufw allow 443/tcp
   ufw enable
   ```

4. **Backup** - setup automatic daily backups:
   ```bash
   # Add to crontab
   0 2 * * * /opt/emergency-chatbot/scripts/backup.sh
   ```

5. **Monitoring** - setup monitoring & alerts

6. **Rate Limiting** - configure in `.env`:
   ```
   RATE_LIMIT_PER_MINUTE=10
   ```

## 📚 Next Steps

Setelah instalasi berhasil:

1. ✅ Login ke dashboard di http://localhost:8080
2. ✅ Connect WhatsApp (scan QR jika Baileys mode)
3. ✅ Test kirim pesan WhatsApp ke nomor yang terconnect
4. ✅ Baca dokumentasi lengkap di README.md
5. ✅ Setup webhook jika pakai Meta Cloud API

## 🆘 Support

Jika ada masalah:

- 📖 Baca [README.md](README.md) untuk dokumentasi lengkap
- 🐛 Report issues: https://github.com/iwewe/chatbot-disaster-response/issues
- 💬 Discussions: https://github.com/iwewe/chatbot-disaster-response/discussions

## 📄 License

MIT License - see [LICENSE](LICENSE) file

---

**Happy Disaster Response Management! 🚨**
