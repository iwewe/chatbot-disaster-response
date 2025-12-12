# Rekomendasi dan Rencana Aksi

*Tanggal dan waktu penyusunan: Tue Dec 09 10:44:57 UTC 2025*

## Analisis Singkat
- Backend Express sudah dilengkapi middleware dasar (Helmet, CORS, body parser, logging, rate limiting) serta penanganan error dan hook shutdown, menunjukkan fondasi ops/keamanan sudah dipikirkan.
- Konfigurasi environment sudah divalidasi dengan Zod sehingga variabel penting (JWT, database, mode WhatsApp, dsb.) diverifikasi saat startup.

## Area yang Masih Kurang / Risiko
- Keamanan autentikasi masih “MVP”: login hanya membandingkan `password === process.env.ADMIN_PASSWORD` tanpa hash, pengguna non-admin tetap bisa login tanpa validasi kata sandi kuat. Import `bcrypt` belum dipakai, dan password admin hanya di `.env` via log peringatan, bukan disimpan/di-hash di DB.
- Belum ada validasi payload per endpoint: controller menerima `req.body` langsung (mis. login, setupAdmin) tanpa skema per-request; error DB saja yang ditangkap. Ini membuka risiko 400/500 tak terkendali atau data tidak konsisten.
- Rate limiting hanya global per IP: limiter 100 req/menit untuk seluruh prefix `/api` tanpa diferensiasi endpoint/kredensial, sehingga dapat dibypass via banyak token atau memblokir pengguna sah saat lonjakan webhook.
- Observability kurang detail di layer domain: logging hanya di middleware/error global; controller/service belum log event penting (mis. perubahan status laporan, aksi pengguna) sehingga audit insiden sulit.
- Belum ada pengujian otomatis: tidak tampak pengaturan test/CI sehingga regresi mudah lolos dan integrasi WhatsApp/Telegram/Prisma tidak terverifikasi.

## Rekomendasi Perbaikan
- **Perkuat autentikasi**
  - Simpan hash password di database dengan `bcrypt` dan verifikasi hash saat login.
  - Hapus fallback login tanpa password untuk non-admin, dan ganti mekanisme `ADMIN_PASSWORD` dengan seeding user admin di migration.
- **Tambahkan validasi request per endpoint**
  - Gunakan `zod`/`joi`/`express-validator` sebagai middleware untuk memvalidasi body/query/params (contoh: login mewajibkan `phoneNumber`, password dengan panjang minimum; `setupAdmin` mengecek role).
- **Rate limiting berbasis konteks**
  - Terapkan limiter berbeda untuk webhook vs dashboard API; pertimbangkan limiter berbasis token/akun di endpoint sensitif (login, media upload).
- **Audit & observability**
  - Tambahkan logging terstruktur di controller/service untuk event bisnis (pembuatan laporan, perubahan status, unduhan media). Integrasikan metrik (Prometheus/OpenTelemetry) untuk request rate, error rate, dan latency di endpoint kritis.
- **Automated testing & QA**
  - Tambahkan unit test untuk controller/middleware (mock Prisma/WhatsApp); siapkan integration test minimal untuk flow login dan CRUD laporan.
  - Siapkan workflow CI (GitHub Actions) untuk lint, test, dan pengecekan format.
- **Hardening konfigurasi**
  - Tetapkan default aman: `API_BASE_URL` optional di dev dengan fallback localhost; parameter sensitif (WhatsApp tokens, JWT secret) divalidasi keberadaannya ketika mode terkait diaktifkan.
