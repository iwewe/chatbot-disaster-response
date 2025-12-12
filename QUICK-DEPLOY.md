# 🚀 Quick Deployment Guide

Panduan cepat untuk deploy Emergency Response System.

## ⚡ Quick Start (One Command)

```bash
curl -fsSL https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf/deploy.sh | bash
```

## 📦 What Gets Deployed

✅ **Dashboard** (Frontend)
- home.html - Landing page
- dashboard.html - Admin dashboard dengan form terintegrasi
- public-form.html - Public form page
- Semua assets (logo, CSS, JS)

✅ **Backend** (API)
- api.controller.js - Termasuk createReport endpoint
- routes/index.js - POST /api/reports endpoint
- Automatic user creation
- Report number generation

✅ **Backup**
- Backup otomatis sebelum deploy
- Tersimpan di `backups/YYYYMMDD_HHMMSS/`

## 🔄 Rollback Jika Ada Masalah

```bash
curl -fsSL https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf/rollback.sh -o rollback.sh
chmod +x rollback.sh
./rollback.sh
```

## 📊 Access URLs

Setelah deployment berhasil:

| Service | URL | Deskripsi |
|---------|-----|-----------|
| Homepage | http://localhost:8080 | Landing page publik |
| Public Form | http://localhost:8080/public-form.html | Form laporan publik |
| Admin Dashboard | http://localhost:8080/index.html | Dashboard admin |
| Backend API | http://localhost:3000 | REST API |
| Health Check | http://localhost:3000/health | Status services |

## 🔐 Default Credentials

```
Username: admin
Password: Admin123!Staging
```

⚠️ **PENTING:** Ganti password ini setelah login pertama kali!

## 🧪 Test Form Submission

Setelah deploy, test form berfungsi:

### 1. Posko Pengungsian
```bash
curl -X POST http://localhost:3000/api/reports \
  -H "Content-Type: application/json" \
  -d '{
    "type": "PENGUNGSIAN",
    "urgency": "MEDIUM",
    "reportSource": "web",
    "reporterPhone": "+628123456789",
    "location": "SDN 01 Jakarta",
    "latitude": -6.2088,
    "longitude": 106.8456,
    "shelter": {
      "name": "SDN 01 Jakarta",
      "type": "Gedung Sekolah",
      "address": "Jl. Sudirman No. 1",
      "picName": "John Doe",
      "picPhone": "+628123456789",
      "maleCount": 10,
      "femaleCount": 15,
      "childCount": 5
    }
  }'
```

### 2. Pencarian Orang Hilang
```bash
curl -X POST http://localhost:3000/api/reports \
  -H "Content-Type: application/json" \
  -d '{
    "type": "KORBAN",
    "urgency": "HIGH",
    "reportSource": "web",
    "reporterPhone": "+628123456789",
    "location": "Jl. Gatot Subroto",
    "missingPerson": {
      "personName": "Jane Doe",
      "age": 25,
      "gender": "PEREMPUAN",
      "idNumber": "3201234567890123",
      "physicalDescription": "Tinggi 160cm, berambut panjang",
      "lastSeenLocation": "Jl. Gatot Subroto",
      "familyName": "John Doe",
      "familyPhone": "+628123456789"
    }
  }'
```

### 3. Request Bantuan
```bash
curl -X POST http://localhost:3000/api/reports \
  -H "Content-Type: application/json" \
  -d '{
    "type": "KEBUTUHAN",
    "urgency": "HIGH",
    "reportSource": "web",
    "reporterPhone": "+628123456789",
    "location": "Desa Sukamaju",
    "latitude": -6.2088,
    "longitude": 106.8456,
    "needs": {
      "category": "PANGAN",
      "description": "Membutuhkan makanan untuk 50 orang",
      "peopleAffected": 50
    }
  }'
```

## 🐛 Troubleshooting

### "Endpoint not found"
Backend belum siap atau route tidak ada.

**Solusi:**
```bash
# Check backend logs
docker compose logs backend

# Restart backend
docker compose restart backend
```

### Dashboard tidak load
Nginx/dashboard service bermasalah.

**Solusi:**
```bash
# Check dashboard logs
docker compose logs dashboard

# Restart dashboard
docker compose restart dashboard
```

### Form submit gagal terus
Check browser console untuk error message.

**Solusi:**
```bash
# Check backend health
curl http://localhost:3000/health

# Verify backend is running
docker compose ps backend

# Check API endpoint exists
curl http://localhost:3000/api/reports -X POST -H "Content-Type: application/json" -d '{}'
```

## 📝 Useful Commands

```bash
# View all services status
docker compose ps

# View logs (real-time)
docker compose logs -f backend
docker compose logs -f dashboard

# Restart specific service
docker compose restart backend
docker compose restart dashboard

# Rebuild backend
docker compose build backend
docker compose up -d backend

# Stop all services
docker compose down

# Start all services
docker compose up -d
```

## 📚 Full Documentation

Untuk dokumentasi lengkap, lihat:
- [DEPLOYMENT.md](./DEPLOYMENT.md) - Panduan deployment lengkap
- [README.md](./README.md) - Project documentation

## 🆘 Need Help?

1. Check logs: `docker compose logs -f`
2. Verify services: `docker compose ps`
3. Test health: `curl http://localhost:3000/health`
4. Review DEPLOYMENT.md untuk troubleshooting detail

---

**Last Updated:** 2023-12-11
**Branch:** claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf
