# 🆘 Emergency Disaster Response Chatbot

**Sistem Chatbot WhatsApp untuk Tanggap Darurat Bencana**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Node.js](https://img.shields.io/badge/Node.js-20.x-green.svg)](https://nodejs.org/)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)

---

## 🎯 Tujuan

Sistem ini dirancang untuk **situasi emergency aktif** dimana:
- ✅ Pengumpulan data korban dan kebutuhan harus CEPAT
- ✅ Tim operasional minimal (2 orang, non-technical)
- ✅ Deployment harus MUDAH (one-command setup)
- ✅ Sistem harus RELIABLE (auto-recovery, graceful degradation)

---

## ⚡ Quick Start - Pilih Deployment Mode

Sistem ini punya **2 mode** tergantung resource server:

### 📍 FULL VERSION (AI-Powered) - Recommended
**Untuk:** Server dengan 16GB+ RAM, 8+ cores
```bash
curl -fsSL https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/main/scripts/install.sh | bash
```

### 📍 LIGHT VERSION (Rule-Based) - Emergency Mode
**Untuk:** Server minimal 4GB RAM, 2 cores - **Deploy dalam 10 menit!**
```bash
curl -fsSL https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/main/scripts/install-light.sh | bash
```

**👉 Baca lengkap:** [Deployment Options Guide](docs/DEPLOYMENT_OPTIONS.md)

---

## 🌟 Fitur Utama

### 1. WhatsApp Chatbot dengan AI
- Menerima laporan dalam bahasa natural (tidak perlu format kaku)
- AI extraction menggunakan Ollama (local LLM) - **offline-capable**
- Fallback ke rule-based jika AI timeout
- Follow-up questions otomatis untuk data yang kurang

### 2. Jenis Laporan
- 🆘 **Korban**: Meninggal, hilang, luka (berat/sedang/ringan), sakit
- 📦 **Kebutuhan**: Pangan, air, medis, shelter, evakuasi, sanitasi, dll

### 3. Verifikasi & Tracking
- Trust level system (relawan verified vs public)
- Status tracking: Pending → Verified → Assigned → In Progress → Resolved
- Deduplication detection (laporan serupa)
- Audit trail lengkap

### 4. Notifikasi Real-time
- Telegram alerts untuk admin (dengan urgency level)
- WhatsApp konfirmasi otomatis ke pelapor
- Update status via WA

### 5. Dashboard API
- RESTful API untuk semua operasi
- Filter & search canggih
- Export data (raw & aggregated)
- Role-based access control

### 6. Compliance
- Data retention (6 bulan, configurable)
- Sesuai standar: Sphere Handbook, BNPB, Indonesia One Disaster Data
- Data disaggregation (gender, age, disability)

---

## 🏗️ Arsitektur Sistem

```
┌─────────────────────────────────────────────────────────┐
│                     USER INTERFACE                       │
│  WhatsApp (Pelapor) ←→ Telegram (Admin/Koordinator)    │
└─────────────────────────────────────────────────────────┘
                          ↓ ↑
┌─────────────────────────────────────────────────────────┐
│                   BACKEND API (Node.js)                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   WhatsApp   │  │   Message    │  │   Telegram   │  │
│  │   Service    │→ │  Processor   │→ │   Service    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│                          ↓ ↑                             │
│                  ┌──────────────┐                        │
│                  │    Ollama    │                        │
│                  │  AI Service  │                        │
│                  └──────────────┘                        │
└─────────────────────────────────────────────────────────┘
                          ↓ ↑
┌─────────────────────────────────────────────────────────┐
│                      DATA LAYER                          │
│  ┌──────────────┐  ┌──────────────┐                     │
│  │  PostgreSQL  │  │    Redis     │                     │
│  │   Database   │  │ Queue & Cache│                     │
│  └──────────────┘  └──────────────┘                     │
└─────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- 16GB+ RAM (32GB recommended)
- 50GB+ disk space
- WhatsApp Business Account (Meta)
- Telegram Bot Token

### 1-Command Deployment

```bash
# Clone repository
git clone <repo-url> emergency-chatbot
cd emergency-chatbot

# Setup environment
cp .env.example .env
nano .env  # Edit with your credentials

# Deploy!
bash scripts/deploy.sh
```

**That's it!** 🎉 Sistem akan running dalam 15-30 menit (termasuk download AI model).

### Detailed Setup

Lihat dokumentasi lengkap:
- 📖 **[Deployment Guide](docs/DEPLOYMENT.md)** - Setup dari nol
- 📖 **[Operator Manual](docs/OPERATOR_MANUAL.md)** - Panduan operasional sehari-hari

---

## 📁 Struktur Project

```
emergency-chatbot/
├── backend/                # Node.js backend
│   ├── src/
│   │   ├── config/        # Configuration
│   │   ├── services/      # Business logic
│   │   │   ├── ollama.service.js       # AI extraction
│   │   │   ├── whatsapp.service.js     # WhatsApp messaging
│   │   │   ├── telegram.service.js     # Telegram alerts
│   │   │   └── message-processor.service.js  # Core logic
│   │   ├── controllers/   # API controllers
│   │   ├── routes/        # API routes
│   │   ├── middleware/    # Auth, error handling
│   │   └── utils/         # Helpers
│   ├── prisma/
│   │   └── schema.prisma  # Database schema
│   └── Dockerfile
├── scripts/               # Deployment scripts
│   ├── deploy.sh         # Master deployment
│   ├── init-ollama.sh    # Ollama setup
│   └── init-database.sh  # Database setup
├── docs/                  # Documentation
│   ├── DEPLOYMENT.md     # Deployment guide
│   └── OPERATOR_MANUAL.md # Operator guide
├── docker-compose.yml    # Docker orchestration
├── .env.example          # Environment template
└── README.md            # This file
```

---

## 🔧 Technology Stack

### Backend
- **Runtime**: Node.js 20 LTS
- **Framework**: Express.js
- **Database**: PostgreSQL 15 (with Prisma ORM)
- **Cache/Queue**: Redis 7
- **AI**: Ollama (Qwen 2.5 7B / Llama 3.1 8B)
- **Auth**: JWT
- **Validation**: Zod

### Infrastructure
- **Containerization**: Docker & Docker Compose
- **Reverse Proxy**: Nginx (optional, for production)
- **Monitoring**: Docker healthchecks
- **Logging**: Winston

### Integrations
- **WhatsApp**: Meta Cloud API
- **Telegram**: Telegram Bot API
- **AI**: Ollama (self-hosted LLM)

---

## 📊 Database Schema

**Core Entities:**
- `User` - Admin, relawan, koordinator
- `Report` - Laporan utama (korban / kebutuhan)
- `ReportPerson` - Detail korban (nama, status, kondisi)
- `ReportNeed` - Detail kebutuhan (kategori, quantity)
- `ReportAction` - Tracking tindak lanjut
- `ChatState` - Conversation state management
- `AuditLog` - Audit trail semua perubahan

**Enums:**
- Status: PENDING_VERIFICATION → VERIFIED → ASSIGNED → IN_PROGRESS → RESOLVED
- Urgency: CRITICAL, HIGH, MEDIUM, LOW
- Person Status: MENINGGAL, HILANG, LUKA_BERAT, LUKA_SEDANG, LUKA_RINGAN, SAKIT
- Need Category: PANGAN, AIR, MEDIS, SHELTER, EVAKUASI, SANITASI, dll

Lihat: `backend/prisma/schema.prisma`

---

## 🔐 Security

- JWT authentication untuk API access
- Role-based authorization (ADMIN, PMI, BNPB, BPBD COORDINATOR, VOLUNTEER)
- Data encryption at rest (PostgreSQL SSL)
- Rate limiting (100 req/min per IP)
- Audit logging untuk semua aksi penting
- Data retention policy (6 bulan, configurable)

---

## 📞 API Endpoints

### Authentication
- `POST /auth/login` - Login
- `POST /auth/setup-admin` - Create admin (one-time)
- `GET /auth/me` - Get current user

### Reports
- `GET /api/reports` - List reports (with filters)
- `GET /api/reports/:id` - Get report detail
- `PATCH /api/reports/:id/status` - Update status

### Dashboard
- `GET /api/dashboard/stats` - Statistics

### Users
- `GET /api/users` - List users (admin only)
- `PATCH /api/users/:id` - Update user (admin only)

### Export
- `GET /api/reports/export` - Export data

### Webhook
- `GET /webhook` - Verify webhook (WhatsApp)
- `POST /webhook` - Receive messages (WhatsApp)

### Health
- `GET /health` - System health check

---

## 🧪 Testing

### Health Check
```bash
curl http://localhost:3000/health
```

### Test Report Submission
Kirim pesan WhatsApp ke nomor yang dikonfigurasi:
```
Ada 3 orang terluka di Dusun Kali RT 02, butuh evakuasi segera
```

Bot akan reply dengan konfirmasi + report ID.

### Check Logs
```bash
# All services
docker-compose logs -f

# Backend only
docker logs -f emergency_backend

# Ollama (AI)
docker logs -f emergency_ollama
```

---

## 🔄 Maintenance

### Backup Database
```bash
docker exec emergency_db pg_dump -U postgres emergency_chatbot > backup.sql
```

### Restore Database
```bash
cat backup.sql | docker exec -i emergency_db psql -U postgres emergency_chatbot
```

### Update Ollama Model
```bash
docker exec -it emergency_ollama ollama pull qwen2.5:7b
docker-compose restart backend
```

### View Metrics
```bash
docker stats
```

---

## 🐛 Troubleshooting

Lihat: **[Deployment Guide - Troubleshooting Section](docs/DEPLOYMENT.md#-troubleshooting)**

Common issues:
- Ollama download timeout → Use smaller model (llama3.2:3b)
- WhatsApp webhook failed → Check VERIFY_TOKEN, URL accessibility
- Database migration failed → Run `docker exec emergency_backend npx prisma migrate deploy`

---

## 🚧 Roadmap (Future Development)

### Phase 1 (MVP) ✅
- [x] WhatsApp bot with AI extraction
- [x] Korban & Kebutuhan reports
- [x] Telegram notifications
- [x] Basic dashboard API
- [x] Docker deployment

### Phase 2 (Next 1-2 months)
- [ ] Web dashboard UI (React)
- [ ] Penyaluran bantuan (5W tracking)
- [ ] Registrasi pengungsi/keluarga
- [ ] Map visualization (Leaflet)
- [ ] Export to Indonesia One Disaster Data

### Phase 3 (2-3 months)
- [ ] Multi-language support (bahasa daerah)
- [ ] Mobile app untuk relawan
- [ ] Advanced analytics
- [ ] Integration with ODK/KoboToolbox
- [ ] SMS fallback (via Twilio)

---

## 🤝 Contributing

Ini adalah sistem emergency, tapi contribution tetap welcome:

1. Fork repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

**Prioritas contribution:**
- 🐛 Bug fixes (highest priority)
- 📖 Documentation improvements
- ✨ UI/UX enhancements
- 🔧 Performance optimizations

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file

---

## 👥 Credits

**Developed by:** Combine Resources Institution

**Based on international standards:**
- [Sphere Handbook](https://spherestandards.org/)
- [Indonesia One Disaster Data](https://inarisk.bnpb.go.id/)
- [OCHA Humanitarian Response](https://www.unocha.org/)

**Technology credits:**
- [Ollama](https://ollama.ai/) - Local LLM
- [Prisma](https://www.prisma.io/) - Database ORM
- [WhatsApp Cloud API](https://developers.facebook.com/docs/whatsapp) - Messaging
- [Telegram Bot API](https://core.telegram.org/bots) - Notifications

---

## 📞 Support

**For technical issues:**
- GitHub Issues: [repository]/issues
- Email: maksum@combine.id

**For emergency deployment assistance:**
- Contact: maksum@combine.id
- Available: 24/7 during disaster response

---

## ⚠️ Disclaimer

> Sistem ini adalah ALAT BANTU untuk koordinasi tanggap darurat.
> Keputusan akhir SELALU ada di tangan operator dan koordinator manusia.
> AI dapat salah, data dapat tidak akurat, sistem dapat down.
> **ALWAYS VERIFY CRITICAL INFORMATION** sebelum mengambil keputusan yang menyangkut nyawa.

---

**Built with ❤️ for humanity**

_Last Updated: 2024-11-26_
