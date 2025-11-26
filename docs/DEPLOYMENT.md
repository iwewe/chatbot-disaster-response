# 🚀 Emergency Chatbot Deployment Guide

**UNTUK SITUASI DARURAT - Panduan Deploy Cepat**

Sistem ini dirancang untuk deployment yang cepat dan mudah menggunakan Docker. Tidak diperlukan pengetahuan programming untuk deployment.

---

## 📋 Prerequisites (Yang Harus Ada)

### 1. Server / Komputer

**Spesifikasi Minimum:**
- CPU: 8 cores (untuk Ollama CPU mode)
- RAM: 16GB minimum, 32GB recommended
- Storage: 50GB free space minimum
- OS: Ubuntu 20.04+ / Debian 11+ / CentOS 8+ (Linux recommended)
- Koneksi internet stabil untuk download model pertama kali (~5GB)

**Spesifikasi Recommended (dengan GPU):**
- CPU: 8+ cores
- RAM: 16GB+
- GPU: NVIDIA RTX 3060 12GB atau lebih tinggi
- Storage: 100GB free space
- OS: Ubuntu 22.04 LTS

### 2. Software Yang Harus Diinstall

1. **Docker & Docker Compose**
   ```bash
   # Install Docker (Ubuntu/Debian)
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh

   # Add user to docker group (agar tidak perlu sudo)
   sudo usermod -aG docker $USER

   # Logout dan login lagi untuk apply

   # Verify
   docker --version
   docker compose version
   ```

2. **Git** (untuk clone repository)
   ```bash
   sudo apt update
   sudo apt install git -y
   ```

3. **curl** (untuk testing API)
   ```bash
   sudo apt install curl -y
   ```

### 3. Akun Yang Diperlukan

#### A. WhatsApp Business Account (Meta)

**Langkah-langkah Setup WhatsApp Cloud API:**

1. **Buat Facebook Business Account**
   - Buka: https://business.facebook.com
   - Klik "Create Account"
   - Isi nama bisnis: "Emergency Response [Organization Name]"
   - Verifikasi dengan nomor telepon dan email

2. **Buat App di Meta for Developers**
   - Buka: https://developers.facebook.com/apps
   - Klik "Create App"
   - Pilih tipe: "Business"
   - Nama app: "Emergency Chatbot"
   - Business Account: pilih yang sudah dibuat di step 1

3. **Setup WhatsApp**
   - Di dashboard app, klik "Add Product"
   - Pilih "WhatsApp" → "Set Up"
   - Di bagian "API Setup":
     - **Phone Number ID**: Catat ini (akan dipakai di .env)
     - **Access Token**: Klik "Generate Token" → Catat (temporary, kita akan buat permanent token nanti)
     - **Business Account ID**: Catat ini

4. **Buat Permanent Access Token**
   - Buka: https://business.facebook.com/settings/system-users
   - Klik "Add" → Buat system user dengan role "Admin"
   - Klik system user → "Generate New Token"
   - Pilih app yang sudah dibuat
   - Permissions: centang "whatsapp_business_messaging" dan "whatsapp_business_management"
   - **PENTING**: SIMPAN token ini dengan aman (tidak bisa dilihat lagi)

5. **Verifikasi Nomor WhatsApp**
   - Di WhatsApp setup page, klik "Add Phone Number"
   - Pilih negara: Indonesia (+62)
   - Masukkan nomor WhatsApp bisnis (harus nomor baru atau nomor yang belum terdaftar di WA pribadi)
   - Verifikasi dengan kode SMS atau call
   - ✅ Setelah verified, nomor siap digunakan!

6. **Catat Semua Credential:**
   ```
   WHATSAPP_PHONE_NUMBER_ID=xxxxxxxxxxxx
   WHATSAPP_ACCESS_TOKEN=EAAxxxxxxxxxxxxxxxxx (permanent token dari step 4)
   WHATSAPP_BUSINESS_ACCOUNT_ID=xxxxxxxxxxxx
   WHATSAPP_VERIFY_TOKEN=buat_sendiri_string_random_ini (untuk verify webhook nanti)
   ```

#### B. Telegram Bot (untuk notifikasi admin)

**Langkah-langkah Setup Telegram Bot:**

1. **Buat Bot**
   - Buka Telegram, search: `@BotFather`
   - Kirim: `/newbot`
   - Ikuti instruksi:
     - Bot name: "Emergency Response Alerts"
     - Bot username: "emergency_response_bot" (harus unik, tambahkan angka jika sudah dipakai)
   - **Catat Token**: Akan muncul seperti: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`

2. **Dapatkan Chat ID untuk grup admin**
   - Buat Telegram Group baru: "Emergency Response Admin"
   - Invite bot ke group (search username bot, lalu add)
   - Buat bot jadi admin (optional, tapi recommended)
   - Untuk dapatkan Chat ID, kirim pesan di grup, lalu:
   ```bash
   curl "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates"
   ```
   - Cari `"chat":{"id":-xxxxxxxxxxxx` → Catat angka ini (negative number untuk group)

3. **Catat Credential:**
   ```
   TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
   TELEGRAM_ADMIN_CHAT_ID=-xxxxxxxxxxxx
   ```

---

## 🚀 Deployment Steps

### Step 1: Clone Repository

```bash
cd /home/user  # atau direktori mana saja
git clone <repository-url> emergency-chatbot
cd emergency-chatbot
```

### Step 2: Setup Environment Variables

```bash
# Copy template
cp .env.example .env

# Edit dengan text editor
nano .env
```

**Fill in these values** (sesuaikan dengan credential yang sudah dicatat):

```env
# API Base URL (domain atau IP public server)
API_BASE_URL=https://your-domain.com  # atau http://IP_SERVER:3000 jika belum ada domain

# WhatsApp Cloud API
WHATSAPP_PHONE_NUMBER_ID=xxxxxxxxxxxx
WHATSAPP_ACCESS_TOKEN=EAAxxxxxxxxxxxxxxxxx
WHATSAPP_VERIFY_TOKEN=random_string_buatan_sendiri_123
WHATSAPP_BUSINESS_ACCOUNT_ID=xxxxxxxxxxxx

# Telegram Bot
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
TELEGRAM_ADMIN_CHAT_ID=-xxxxxxxxxxxx

# JWT Secret (generate random string, minimal 32 karakter)
# Bisa pakai: openssl rand -hex 32
JWT_SECRET=paste_hasil_openssl_rand_hex_32_di_sini

# Admin password (untuk login dashboard nanti)
ADMIN_PASSWORD=buat_password_kuat_di_sini
```

**Save dan exit** (Ctrl+X, tekan Y, Enter)

### Step 3: Run Deployment Script

```bash
# Pastikan script executable
chmod +x scripts/*.sh

# Run deployment
sudo bash scripts/deploy.sh
```

**Proses ini akan:**
1. Pull Docker images (~2GB download)
2. Build backend application
3. Start all services (PostgreSQL, Redis, Ollama, Backend)
4. Download AI model (~4-5GB, hanya pertama kali)
5. Setup database schema
6. Menampilkan instruksi next steps

**⏳ Estimasi waktu:** 15-30 menit (tergantung koneksi internet)

### Step 4: Create Admin User

Setelah deployment selesai, buat admin user:

```bash
curl -X POST http://localhost:3000/auth/setup-admin \
  -H 'Content-Type: application/json' \
  -d '{
    "phoneNumber": "+6281234567890",
    "name": "Admin Emergency",
    "password": "your-secure-password"
  }'
```

**Response sukses:**
```json
{
  "success": true,
  "message": "Admin created successfully",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": { ... }
  }
}
```

**Simpan token ini** untuk akses API/dashboard.

### Step 5: Setup WhatsApp Webhook

**Jika server di localhost** (untuk testing):
- Gunakan ngrok atau serveo untuk expose port 3000:
  ```bash
  # Install ngrok
  wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
  tar xvzf ngrok-v3-stable-linux-amd64.tgz
  ./ngrok http 3000
  ```
- Catat URL yang muncul (misal: `https://abc123.ngrok.io`)

**Jika server di cloud dengan domain/IP public:**
- Setup SSL dengan Let's Encrypt (recommended)
- Atau gunakan IP public (http://IP:3000)

**Configure di Meta Developer Console:**

1. Buka: https://developers.facebook.com/apps
2. Pilih app "Emergency Chatbot"
3. WhatsApp → Configuration
4. **Edit Webhook:**
   - Callback URL: `https://your-domain.com/webhook` (atau ngrok URL)
   - Verify Token: sama dengan `WHATSAPP_VERIFY_TOKEN` di .env
   - Klik "Verify and Save"
   - ✅ Jika sukses, akan muncul "Webhook verified"

5. **Subscribe to messages:**
   - Di bagian "Webhook fields"
   - Centang: `messages`
   - Klik "Subscribe"

### Step 6: Test System

**Test 1: Health Check**
```bash
curl http://localhost:3000/health
```

**Expected response:**
```json
{
  "success": true,
  "status": "healthy",
  "services": {
    "ollama": { "status": "healthy" },
    "whatsapp": { "status": "healthy" },
    "telegram": { "status": "healthy" },
    "database": { "status": "healthy" }
  }
}
```

**Test 2: Send WhatsApp Message**
- Kirim pesan ke nomor WhatsApp yang sudah dikonfigurasi:
  ```
  Ada 3 orang terluka di Dusun Kali RT 02, butuh evakuasi segera
  ```
- Bot harus reply dengan konfirmasi laporan
- Admin harus dapat notifikasi di Telegram group

**Test 3: Check Logs**
```bash
# Backend logs
docker logs -f emergency_backend

# All services
docker-compose logs -f
```

---

## 🔧 Troubleshooting

### Problem: Ollama model download gagal

**Solution:**
```bash
# Manual download
docker exec -it emergency_ollama ollama pull qwen2.5:7b

# Jika masih gagal, coba model lebih kecil:
docker exec -it emergency_ollama ollama pull llama3.2:3b

# Update .env:
OLLAMA_MODEL=llama3.2:3b

# Restart backend
docker-compose restart backend
```

### Problem: WhatsApp webhook verification failed

**Check:**
1. URL accessible dari internet? Test: `curl https://your-domain.com/webhook`
2. WHATSAPP_VERIFY_TOKEN di .env sama dengan yang di Meta console?
3. Backend running? Check: `docker ps | grep emergency_backend`

**Debug:**
```bash
# Check backend logs
docker logs emergency_backend | grep webhook

# Test webhook manually
curl "http://localhost:3000/webhook?hub.mode=subscribe&hub.verify_token=YOUR_VERIFY_TOKEN&hub.challenge=test"
# Should return: "test"
```

### Problem: Telegram notification tidak terkirim

**Check:**
```bash
# Test Telegram bot
curl "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getMe"

# Should return bot info

# Test send message
curl -X POST "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/sendMessage" \
  -H 'Content-Type: application/json' \
  -d '{
    "chat_id": "YOUR_CHAT_ID",
    "text": "Test notification"
  }'
```

### Problem: Database migration failed

**Solution:**
```bash
# Enter backend container
docker exec -it emergency_backend sh

# Run migration manually
cd /app
npx prisma migrate deploy

# If still failing, reset database (⚠️ deletes all data!)
npx prisma migrate reset --force
```

### Problem: Out of memory / Ollama crash

**Solution:**
```bash
# Check memory usage
free -h

# If low, reduce Ollama model size or use fallback mode
# Edit .env:
OLLAMA_FALLBACK_ENABLED=true

# Restart
docker-compose restart backend
```

---

## 🔄 Maintenance Commands

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker logs -f emergency_backend
docker logs -f emergency_ollama
```

### Restart Services
```bash
# All
docker-compose restart

# Specific
docker-compose restart backend
```

### Stop System
```bash
# Stop (data tetap ada)
docker-compose down

# Stop dan hapus semua data (⚠️ HATI-HATI!)
docker-compose down -v
```

### Backup Database
```bash
# Export database
docker exec emergency_db pg_dump -U postgres emergency_chatbot > backup_$(date +%Y%m%d).sql

# Restore
cat backup_20240101.sql | docker exec -i emergency_db psql -U postgres emergency_chatbot
```

### Update System
```bash
# Pull latest code
git pull

# Rebuild
docker-compose build backend

# Restart
docker-compose up -d backend
```

---

## 📊 Monitoring

### Check Service Status
```bash
docker-compose ps
```

### Resource Usage
```bash
docker stats
```

### Database Size
```bash
docker exec emergency_db psql -U postgres emergency_chatbot -c "
  SELECT
    pg_size_pretty(pg_database_size('emergency_chatbot')) as size;
"
```

---

## 🆘 Emergency Contacts

Jika ada masalah kritis yang tidak bisa diselesaikan:

1. **Check GitHub Issues**: [repository-url]/issues
2. **Contact Tech Lead**: [insert contact]
3. **Fallback Mode**: Jika AI tidak jalan, sistem tetap bisa terima laporan (akan diproses manual via dashboard)

---

## 📚 Next Steps

Setelah deployment berhasil:

1. ✅ Baca **OPERATOR_MANUAL.md** untuk panduan pengoperasian sehari-hari
2. ✅ Daftarkan nomor relawan terverifikasi via dashboard
3. ✅ Lakukan drill/simulasi untuk test sistem
4. ✅ Setup monitoring & alerting tambahan jika diperlukan

---

**Last Updated:** 2024-11-26
**Version:** 1.0.0
