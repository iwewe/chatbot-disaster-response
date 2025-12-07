# 📖 Panduan Operator Sistem Tanggap Darurat

**PANDUAN PENGOPERASIAN SEHARI-HARI**
Untuk Tim Operasional (Non-Technical)

---

## 📌 Ringkasan Sistem

Sistem ini adalah chatbot WhatsApp yang:
- ✅ Menerima laporan dari masyarakat via WhatsApp
- ✅ Mengekstrak informasi penting menggunakan AI
- ✅ Mengirim notifikasi ke Telegram admin
- ✅ Menyimpan data ke database untuk tracking
- ✅ Memberikan konfirmasi otomatis ke pelapor

**Tugas Operator:**
1. Monitoring notifikasi Telegram
2. Verifikasi laporan yang masuk
3. Assign laporan ke relawan lapangan
4. Update status laporan
5. Koordinasi tindak lanjut

---

## 🚀 Memulai Hari Operasional

### 1. Check System Health (Pagi Hari)

**Via Browser:**
```
Buka: http://localhost:3000/health
```

**Yang harus terlihat:**
```json
{
  "status": "healthy",
  "services": {
    "ollama": { "status": "healthy" },
    "whatsapp": { "status": "healthy" },
    "telegram": { "status": "healthy" },
    "database": { "status": "healthy" }
  }
}
```

✅ **Semua "healthy"** = Sistem OK
❌ **Ada yang "unhealthy"** = Ikuti panduan troubleshooting atau hubungi tech support

### 2. Check Telegram Group

- Pastikan Telegram group "Emergency Response Admin" terbuka
- Test notifikasi dengan kirim pesan test ke WA bot
- Harus muncul notifikasi di Telegram dalam <10 detik

---

## 📱 Alur Kerja: Laporan Masuk

### Scenario 1: Laporan dari Masyarakat (Nomor Tidak Dikenal)

**1. Notifikasi Telegram Masuk:**
```
🆘 LAPORAN BARU 🔴

ID: PB-K-0001
Jenis: Korban (Meninggal/Hilang/Luka)
Urgensi: TINGGI

Pelapor: +6281234567890
⚠️ Pelapor bukan relawan terverifikasi

Lokasi: Dusun Kali RT 02

Ringkasan:
Ada 3 orang terluka di Dusun Kali RT 02, butuh evakuasi segera

Status: Menunggu Verifikasi

Waktu: 26/11/2024 14:30:15
```

**2. TINDAKAN OPERATOR:**

**a. Call pelapor untuk verifikasi**
- Telepon nomor: +6281234567890
- Konfirmasi:
  - ✅ Apakah benar ada kejadian?
  - ✅ Berapa jumlah korban sebenarnya?
  - ✅ Kondisi terkini?
  - ✅ Lokasi persis?
  - ✅ Apakah sudah ada yang menangani?

**b. Jika VERIFIED:**
1. Buka dashboard (akan dijelaskan di section Dashboard)
2. Cari laporan ID: PB-K-0001
3. Klik "Verify" → Tambahkan catatan hasil verifikasi
4. Status otomatis berubah jadi "Verified"
5. Bot akan kirim update ke pelapor via WA

**c. Jika HOAX/SALAH:**
1. Buka dashboard
2. Cari laporan ID: PB-K-0001
3. Klik "Close" → Alasan: "Hoax" atau "Salah informasi"
4. Laporan ditutup, tidak perlu tindak lanjut

**d. Assign ke Relawan Lapangan:**
1. Di dashboard, klik laporan yang sudah verified
2. Pilih "Assign to" → Pilih relawan terdekat dari dropdown
3. Relawan otomatis dapat notifikasi WA
4. Status jadi "Assigned"

### Scenario 2: Laporan dari Relawan Terverifikasi

**Notifikasi Telegram:**
```
🆘 LAPORAN BARU 🔴

ID: VR-K-0002
Jenis: Korban (Meninggal/Hilang/Luka)
Urgensi: KRITIS

Pelapor: Ahmad (Relawan)
✅ Relawan terverifikasi

Lokasi: Desa Sukamaju

Ringkasan:
2 orang meninggal dunia, 5 orang luka berat di lokasi longsor

Status: Terverifikasi

Waktu: 26/11/2024 15:45:00
```

**TINDAKAN OPERATOR:**

Karena dari relawan verified:
- ✅ Status langsung "Verified" (skip verifikasi call)
- ⚡ Langsung assign ke tim SAR atau koordinator
- 🚨 Jika urgensi KRITIS → alert ke koordinator via telepon juga

---

## 💻 Menggunakan Dashboard (Via API)

### Login

**Untuk sekarang (MVP), gunakan curl atau Postman:**

```bash
curl -X POST http://localhost:3000/auth/login \
  -H 'Content-Type: application/json' \
  -d '{
    "phoneNumber": "+6281234567890",
    "password": "admin-password-dari-env"
  }'
```

**Response:**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": { ... }
  }
}
```

**SIMPAN TOKEN INI** untuk request selanjutnya.

### Lihat Semua Laporan

```bash
curl http://localhost:3000/api/reports \
  -H 'Authorization: Bearer YOUR_TOKEN'
```

**Filter:**
```bash
# Laporan pending verification
curl 'http://localhost:3000/api/reports?status=PENDING_VERIFICATION' \
  -H 'Authorization: Bearer YOUR_TOKEN'

# Laporan kritis
curl 'http://localhost:3000/api/reports?urgency=CRITICAL' \
  -H 'Authorization: Bearer YOUR_TOKEN'

# Search by location
curl 'http://localhost:3000/api/reports?search=Dusun+Kali' \
  -H 'Authorization: Bearer YOUR_TOKEN'
```

### Update Status Laporan

**Verify laporan:**
```bash
curl -X PATCH http://localhost:3000/api/reports/REPORT_ID/status \
  -H 'Authorization: Bearer YOUR_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "status": "VERIFIED",
    "notes": "Sudah dikonfirmasi via telepon dengan pelapor. Kondisi sesuai laporan."
  }'
```

**Assign ke relawan:**
```bash
curl -X PATCH http://localhost:3000/api/reports/REPORT_ID/status \
  -H 'Authorization: Bearer YOUR_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "status": "ASSIGNED",
    "assignedToId": "VOLUNTEER_USER_ID",
    "notes": "Ditugaskan ke Relawan Ahmad untuk penanganan evakuasi"
  }'
```

**Mark as resolved:**
```bash
curl -X PATCH http://localhost:3000/api/reports/REPORT_ID/status \
  -H 'Authorization: Bearer YOUR_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "status": "RESOLVED",
    "notes": "Semua korban sudah dievakuasi ke Puskesmas. Penanganan selesai."
  }'
```

---

## 👥 Manajemen Relawan

### Daftarkan Relawan Baru

**Cara 1: Relawan kirim pesan WA ke bot**
- User otomatis terdaftar di sistem dengan role "VOLUNTEER" dan trust level 0
- Admin perlu upgrade trust level via API

**Cara 2: Admin daftarkan manual (coming soon in dashboard UI)**

### Lihat Daftar Relawan

```bash
curl http://localhost:3000/api/users?role=VOLUNTEER \
  -H 'Authorization: Bearer YOUR_TOKEN'
```

### Upgrade Trust Level Relawan

```bash
curl -X PATCH http://localhost:3000/api/users/USER_ID \
  -H 'Authorization: Bearer YOUR_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "trustLevel": 3,
    "organization": "PMI Kota X"
  }'
```

**Trust Level:**
- 0 = Baru terdaftar, belum dikenal
- 1-2 = Relawan baru, laporan perlu verifikasi ketat
- 3+ = Relawan trusted, laporan bisa auto-verified (setting di .env)
- 5 = Relawan senior / koordinator

---

## 📊 Monitoring & Reporting

### Cek Statistik Dashboard

```bash
curl http://localhost:3000/api/dashboard/stats \
  -H 'Authorization: Bearer YOUR_TOKEN'
```

**Response:**
```json
{
  "success": true,
  "data": {
    "summary": {
      "totalReports": 45,
      "pendingVerification": 5,
      "criticalReports": 2,
      "resolvedToday": 12
    },
    "reportsByType": {
      "KORBAN": 20,
      "KEBUTUHAN": 25
    },
    "reportsByUrgency": {
      "CRITICAL": 2,
      "HIGH": 10,
      "MEDIUM": 8
    },
    "recentReports": [ ... ]
  }
}
```

### Export Data

**Export semua laporan (CSV format):**
```bash
curl 'http://localhost:3000/api/reports/export' \
  -H 'Authorization: Bearer YOUR_TOKEN' \
  > laporan_export.json
```

**Export dengan filter tanggal:**
```bash
curl 'http://localhost:3000/api/reports/export?startDate=2024-11-01&endDate=2024-11-30' \
  -H 'Authorization: Bearer YOUR_TOKEN' \
  > laporan_november.json
```

---

## ⚠️ Situasi Darurat & Troubleshooting

### 1. Sistem Tidak Menerima Laporan WA

**Check:**
```bash
# 1. Cek backend running
docker ps | grep emergency_backend

# 2. Cek logs
docker logs -f emergency_backend

# 3. Test health
curl http://localhost:3000/health
```

**Jika backend down:**
```bash
docker-compose restart backend
```

**Jika webhook bermasalah:**
- Cek di Meta Developer Console: webhook masih active?
- Test manual: kirim pesan WA, cek log backend untuk incoming message

### 2. Notifikasi Telegram Tidak Masuk

**Check:**
```bash
# Test Telegram bot
curl https://api.telegram.org/botYOUR_BOT_TOKEN/getMe
```

**Jika bot OK tapi notif tidak masuk:**
- Check TELEGRAM_ADMIN_CHAT_ID di .env benar?
- Restart backend: `docker-compose restart backend`

### 3. AI Extraction Lambat / Error

**Ini NORMAL jika:**
- Ollama sedang process banyak request sekaligus
- Server load tinggi

**Jika lebih dari 30 detik, system akan auto-fallback ke rule-based extraction**

**Manual restart Ollama:**
```bash
docker-compose restart ollama

# Wait 1 minute, then restart backend
sleep 60
docker-compose restart backend
```

### 4. Database Penuh / Disk Space Habis

**Check disk space:**
```bash
df -h
```

**Jika kurang dari 5GB:**
- Export data penting
- Delete old resolved reports (>6 bulan otomatis terhapus)
- Atau tambah disk space

### 5. EMERGENCY: Sistem Completely Down

**Last resort - restart semua:**
```bash
docker-compose down
docker-compose up -d
```

**Wait 2-3 menit untuk semua service ready**

**Jika masih down:**
- Hubungi tech support SEGERA
- Catat error message dari: `docker-compose logs`

---

## 📞 Alur Eskalasi

**Level 1: Operator (Anda)**
- Verifikasi laporan
- Assign relawan
- Update status

**Level 2: Koordinator**
- Keputusan alokasi sumber daya
- Koordinasi multi-tim
- Eskalasi ke pihak berwenang (BNPB, TNI, dll)

**Level 3: Tech Support**
- Masalah sistem teknis yang tidak bisa diselesaikan operator
- Contact: [insert contact info]

---

## 📝 Checklist Harian

### Pagi (08:00)
- [ ] Check system health
- [ ] Check pending verifications
- [ ] Check critical reports yang belum assigned
- [ ] Brief tim relawan

### Siang (12:00)
- [ ] Update status laporan yang sudah ditindaklanjuti
- [ ] Check disk space & system resources
- [ ] Koordinasi dengan tim lapangan

### Sore (17:00)
- [ ] Export laporan harian
- [ ] Update dashboard stats untuk briefing
- [ ] Resolve pending issues

### Malam (Sebelum Tidur)
- [ ] Check ada laporan kritis yang belum ditangani?
- [ ] Setup on-call (siapa yang standby malam ini?)

---

## 🎓 Tips & Best Practices

### 1. Verifikasi Laporan

**DO:**
- ✅ Selalu call back untuk laporan korban jiwa
- ✅ Cross-check dengan sumber lain (relawan, media lokal)
- ✅ Catat nama lengkap & nomor pelapor yang bisa dihubungi

**DON'T:**
- ❌ Langsung assign tanpa verifikasi (kecuali dari relawan verified)
- ❌ Abaikan laporan yang terlihat "aneh" → tetap verifikasi

### 2. Komunikasi dengan Pelapor

**Template verifikasi call:**
```
"Selamat [pagi/siang/malam], ini dari Tim Tanggap Darurat [Organisasi].
Kami menerima laporan dari nomor ini terkait [ringkasan singkat].
Boleh kami konfirmasi beberapa hal?"

- Lokasi tepatnya di mana?
- Berapa jumlah korban/orang yang terdampak?
- Kondisi saat ini bagaimana?
- Apakah sudah ada tim yang menangani?
- Nomor yang bisa dihubungi untuk update?

"Terima kasih informasinya. Kami akan segera koordinasikan tim untuk tindak lanjut.
Mohon tetap standby di nomor ini untuk update ya."
```

### 3. Prioritas Penanganan

**Urgency Level:**
1. **KRITIS** 🚨 - Segera (<15 menit)
   - Korban meninggal / sekarat
   - Ancaman jiwa (evakuasi darurat)

2. **TINGGI** 🔴 - Cepat (<1 jam)
   - Korban luka berat
   - Kebutuhan medis mendesak

3. **SEDANG** 🟡 - Penting (< 6 jam)
   - Korban luka ringan
   - Kebutuhan pangan/air

4. **RENDAH** 🟢 - Bisa dijadwalkan
   - Kebutuhan non-darurat
   - Laporan informasi umum

---

## 📚 Resources

- **Deployment Guide**: `docs/DEPLOYMENT.md`
- **API Documentation**: (coming soon)
- **Emergency Contacts**: [insert contact list]
- **Sphere Handbook**: https://spherestandards.org/handbook-2018/

---

**Catatan Penting:**

> Sistem ini adalah TOOLS. Keputusan akhir selalu ada di tangan MANUSIA (operator, koordinator).
> AI bisa salah ekstrak data, pelapor bisa salah info, sistem bisa down.
> **ALWAYS VERIFY CRITICAL INFORMATION** sebelum dispatch resources.

---

**Last Updated:** 2024-11-26
**Version:** 1.0.0
**For:** Emergency Response Team - Combine Resources Institution
