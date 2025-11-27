# 📸 Media Feature (Foto/Video Verification)

**Fitur upload foto dan video untuk verifikasi laporan**

---

## 🎯 Tujuan

Fitur ini memungkinkan pelapor mengirim **foto dan video** via WhatsApp untuk:
- ✅ **Verifikasi kondisi lapangan** (kerusakan, situasi terkini)
- ✅ **Identifikasi korban** (foto wajah untuk missing person)
- ✅ **Dokumentasi kerusakan** infrastruktur
- ✅ **Evidence untuk alokasi bantuan**

---

## 📋 Jenis Media yang Didukung

| Jenis | Format | Max Size | Contoh Use Case |
|-------|--------|----------|-----------------|
| **Foto** | JPEG, PNG, GIF, WebP | 16MB | Foto korban, kerusakan, kondisi lapangan |
| **Video** | MP4, 3GP, MOV | 64MB | Video situasi evakuasi, kondisi banjir |
| **Audio** | OGG, MP3, M4A, AMR | 16MB | Voice note laporan |
| **Dokumen** | PDF, DOC, DOCX, XLS, XLSX | 100MB | Dokumen pendukung, list nama |

---

## 🚀 Cara Penggunaan

### Option 1: Foto/Video dengan Caption

User kirim foto/video via WhatsApp dengan caption:

```
[Kirim foto]
Caption: Ada 3 orang terluka di Dusun Kali RT 02, butuh evakuasi segera
```

**Bot akan:**
1. Download foto/video otomatis
2. Ekstrak info dari caption
3. Link media ke laporan
4. Kirim konfirmasi

### Option 2: Foto/Video Tanpa Caption

User kirim foto/video saja tanpa teks:

```
[Kirim foto tanpa caption]
```

**Bot akan:**
1. Download media
2. Reply: "Laporan dengan media terlampir. Bisa tambahkan deskripsi lokasi dan situasi?"
3. Wait for follow-up text

### Option 3: Text Dulu, Foto Kemudian

```
User: Ada 3 orang terluka di Dusun Kali
Bot: Terima kasih. Ada foto kondisi saat ini?
User: [Kirim foto]
Bot: ✅ Laporan dengan media diterima
```

---

## 💾 Storage & Organization

### Struktur Folder

```
/app/media/
├── images/
│   ├── 1700123456_abc123.jpg
│   ├── 1700123457_def456.png
│   └── ...
├── videos/
│   ├── 1700123458_ghi789.mp4
│   └── ...
├── audio/
│   └── 1700123459_jkl012.ogg
└── documents/
    └── 1700123460_mno345.pdf
```

### Database Schema

```sql
ReportMedia {
  id: cuid
  reportId: Report ID yang terkait
  mediaType: IMAGE | VIDEO | AUDIO | DOCUMENT
  fileName: "1700123456_abc123.jpg"
  filePath: "images/1700123456_abc123.jpg"
  fileSize: 1234567 (bytes)
  mimeType: "image/jpeg"
  whatsappMediaId: Media ID dari WA
  caption: "Ada 3 orang terluka..."
  uploadedBy: User ID
  uploadedAt: DateTime
}
```

---

## 📡 API Endpoints

### Get Media File

```bash
GET /api/media/:id
Authorization: Bearer <token>
```

**Response:** Binary file (foto/video)

**Example:**
```html
<img src="https://your-domain.com/api/media/cm3abc123def" />
<video src="https://your-domain.com/api/media/cm3ghi456jkl" />
```

### Get All Media for Report

```bash
GET /api/reports/:reportId/media
Authorization: Bearer <token>
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "cm3abc123def",
      "reportId": "cm2xyz789",
      "mediaType": "IMAGE",
      "fileName": "1700123456_abc123.jpg",
      "filePath": "images/1700123456_abc123.jpg",
      "fileSize": 1234567,
      "mimeType": "image/jpeg",
      "caption": "Ada 3 orang terluka...",
      "uploadedAt": "2024-11-26T10:30:00Z"
    }
  ]
}
```

### Delete Media (Admin Only)

```bash
DELETE /api/media/:id
Authorization: Bearer <token>
```

### Storage Statistics (Admin Only)

```bash
GET /api/media/stats/storage
Authorization: Bearer <token>
```

**Response:**
```json
{
  "success": true,
  "data": {
    "storage": {
      "total": "1.25 GB",
      "byType": {
        "images": "800 MB",
        "videos": "400 MB",
        "audio": "30 MB",
        "documents": "20 MB"
      }
    },
    "mediaCount": {
      "IMAGE": 450,
      "VIDEO": 120,
      "AUDIO": 80,
      "DOCUMENT": 15
    }
  }
}
```

---

## 👥 Operator Workflow

### Scenario 1: Laporan dengan Foto

**Notifikasi Telegram:**
```
🆘 LAPORAN BARU 🔴

ID: VR-K-0123
Jenis: Korban
Urgensi: TINGGI

Pelapor: Ahmad (Relawan)
✅ Relawan terverifikasi

Lokasi: Desa Sukamaju RT 02

Ringkasan:
3 orang luka berat di lokasi longsor

📸 Media: 2 foto terlampir

Status: Terverifikasi
```

**Admin Action:**
1. Buka dashboard → View report #VR-K-0123
2. See media tab showing 2 photos
3. Click to view photos (opens in browser)
4. Verify kondisi sesuai laporan
5. If verified → Assign to SAR team

### Scenario 2: Foto untuk Identifikasi Orang Hilang

**User kirim:**
```
Orang hilang: Pak Budi, 45 tahun
Terakhir terlihat di Dusun Kali
[Foto wajah Pak Budi]
```

**Admin:**
1. View foto di dashboard
2. Broadcast foto ke relawan lapangan
3. Update status jika ditemukan

---

## 🔐 Security & Privacy

### WhatsApp Media Handling

1. **Download Process:**
   - WhatsApp Media ID → Get Media URL → Download file
   - Requires WhatsApp Access Token
   - Media URL expires after ~1 hour (download immediately)

2. **Storage Security:**
   - Files stored in Docker volume (not public)
   - Access only via authenticated API
   - Can delete after retention period

3. **Privacy:**
   - Media linked to report (inherit report permissions)
   - Only authorized users can view
   - Can redact sensitive content (future feature)

### Data Retention

Media files follow same retention policy as reports (6 months default):
- After 6 months: Auto-delete resolved reports + media
- Unresolved reports: Keep media until resolved

---

## 💡 Best Practices

### For Users/Pelapor

**✅ DO:**
- Kirim foto yang jelas dan fokus
- Include caption dengan info penting (lokasi, kondisi)
- Compress video jika terlalu besar (keep under 64MB)
- Kirim multiple angles jika perlu

**❌ DON'T:**
- Kirim foto yang blur atau gelap
- Upload video terlalu panjang (> 2-3 menit)
- Kirim media yang tidak relevan

### For Operators/Admin

**✅ DO:**
- Always view media before verifying laporan
- Cross-check media dengan deskripsi text
- Use media untuk brief SAR team
- Archive important media before deletion period

**❌ DON'T:**
- Auto-verify laporan tanpa cek media
- Share media publicly (privacy!)
- Delete media before proper archiving

---

## 🛠️ Troubleshooting

### Media tidak ke-download

**Cek:**
1. WhatsApp Access Token masih valid?
2. Network connection OK?
3. Disk space cukup?
4. Check logs: `docker logs -f emergency_backend | grep media`

**Fix:**
- Restart backend: `docker restart emergency_backend`
- Re-send media dari user

### File size terlalu besar

**Error:** "File too large. Max size for IMAGE: 16MB"

**Fix:**
- Minta user compress foto/video
- Or: Update limit di `backend/src/services/media.service.js`

### Storage penuh

**Check storage:**
```bash
curl http://localhost:3000/api/media/stats/storage \
  -H 'Authorization: Bearer YOUR_TOKEN'
```

**Fix:**
- Delete old media via API
- Increase disk space
- Adjust retention period (shorter)

---

## 📊 Storage Planning

### Estimasi per Laporan

```
Average report with media:
- 2 photos @ 2MB each = 4MB
- 1 video @ 10MB = 10MB
Total: ~14MB per report
```

### Monthly Storage Needs

```
100 reports/day with media:
- 100 × 14MB = 1.4GB/day
- 1.4GB × 30 days = 42GB/month

6-month retention:
- 42GB × 6 = ~250GB needed
```

**Recommendation:**
- Small scale (< 50 reports/day): 100GB disk
- Medium scale (50-200 reports/day): 500GB disk
- Large scale (200+ reports/day): 1TB+ disk

---

## 🔮 Future Enhancements (Phase 2+)

- [ ] **AI Vision**: Auto-generate description from photos
- [ ] **OCR**: Extract text from document photos
- [ ] **Face recognition**: Match missing person photos
- [ ] **Geo-tagging**: Extract GPS from photo EXIF
- [ ] **Cloud storage**: Offload to S3/GCS for cheaper long-term storage
- [ ] **Image compression**: Auto-compress to save space
- [ ] **Thumbnail generation**: Fast preview loading
- [ ] **Watermark**: Auto-add organization watermark

---

## 📚 Technical Implementation

### Key Files

- **Database**: `backend/prisma/schema.prisma` (ReportMedia model)
- **Service**: `backend/src/services/media.service.js`
- **WhatsApp**: `backend/src/services/whatsapp.service.js` (parseIncomingMessage)
- **Message Processor**: `backend/src/services/message-processor.service.js` (media handling)
- **API**: `backend/src/controllers/media.controller.js`
- **Routes**: `backend/src/routes/index.js` (media endpoints)

### Docker Volumes

```yaml
volumes:
  media_data:
    driver: local

services:
  backend:
    volumes:
      - media_data:/app/media  # Persistent media storage
```

---

**Last Updated:** 2024-11-26
**Version:** 1.1.0 (Media Feature)
