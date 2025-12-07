# 📱 WhatsApp Cloud API Setup Guide

**Panduan Step-by-Step Setup WhatsApp Business Cloud API**

---

## 🎯 Overview

WhatsApp Cloud API adalah layanan resmi dari Meta (Facebook) yang memungkinkan bisnis/organisasi mengirim dan menerima pesan WhatsApp via API.

**Keuntungan:**
- ✅ Gratis untuk 1000 konversasi pertama per bulan
- ✅ Reliable & officially supported
- ✅ No third-party dependency
- ✅ Scalable

**Yang dibutuhkan:**
- Facebook account
- Nomor telepon untuk bisnis (bisa beli baru khusus untuk ini)
- Verifikasi identitas (KTP/Passport)

---

## 📝 Step-by-Step Setup

### Step 1: Create Facebook Business Account

1. Buka: https://business.facebook.com

2. Klik **"Create Account"**

3. Isi form:
   - Business Name: `Emergency Response - [Organization Name]`
   - Your Name: Nama Anda
   - Business Email: Email organisasi

4. Klik **"Submit"**

5. Verifikasi email (check inbox dan klik link verifikasi)

✅ Facebook Business Account ready!

---

### Step 2: Create App di Meta for Developers

1. Buka: https://developers.facebook.com/apps

2. Klik **"Create App"**

3. Pilih App Type: **"Business"**

4. Isi App Information:
   - App Name: `Emergency Chatbot`
   - App Contact Email: Email Anda
   - Business Account: Pilih account yang dibuat di Step 1

5. Klik **"Create App"**

6. Jika diminta verifikasi security (Captcha), selesaikan

✅ App created!

---

### Step 3: Add WhatsApp Product

1. Di App Dashboard, scroll ke bagian **"Add Products to Your App"**

2. Cari **"WhatsApp"** → Klik **"Set Up"**

3. Pilih Business Portfolio (biasanya auto-select)

4. Klik **"Continue"**

✅ WhatsApp product added!

---

### Step 4: Get API Credentials (Temporary)

Setelah WhatsApp setup selesai, Anda akan melihat halaman **"API Setup"**.

Di sini akan ada:

1. **Test Phone Number** (nomor test dari Meta)
   - Bisa dipakai untuk testing
   - Ada limit 5 nomor penerima
   - Untuk production, kita akan setup nomor sendiri (Step 6)

2. **Phone Number ID**
   ```
   Contoh: 123456789012345
   ```
   📝 **CATAT INI** → akan dipakai di `.env` sebagai `WHATSAPP_PHONE_NUMBER_ID`

3. **Temporary Access Token**
   ```
   Contoh: EAABsbCS1iHgBOxxxxxxxxxxxxxx
   ```
   ⚠️ Ini token **temporary** (expired 24 jam)
   - Untuk testing OK
   - Untuk production, kita perlu buat **permanent token** (Step 5)

4. **Business Account ID**
   ```
   Contoh: 987654321098765
   ```
   📝 **CATAT INI** → akan dipakai di `.env` sebagai `WHATSAPP_BUSINESS_ACCOUNT_ID`

---

### Step 5: Create Permanent Access Token ⭐

**PENTING:** Temporary token akan expired! Untuk production, harus buat permanent token.

#### A. Create System User

1. Buka: https://business.facebook.com/settings/system-users

2. Klik **"Add"**

3. Isi:
   - System User Name: `Emergency Chatbot System`
   - System User Role: **Admin**

4. Klik **"Create System User"**

#### B. Assign App to System User

1. Di list System Users, klik user yang baru dibuat

2. Klik **"Assign Assets"**

3. Tab **"Apps"**

4. Pilih app "Emergency Chatbot" yang dibuat di Step 2

5. Toggle **Full Control**

6. Klik **"Save Changes"**

#### C. Generate Permanent Token

1. Masih di System User page, klik **"Generate New Token"**

2. Pilih App: **Emergency Chatbot**

3. Pilih Token Expiration: **Never** (permanent)

4. Permissions: Centang:
   - `whatsapp_business_messaging`
   - `whatsapp_business_management`

5. Klik **"Generate Token"**

6. **COPY TOKEN SEKARANG!**
   ```
   Contoh: EAABsbCS1iHgBOyJ9rxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

   ⚠️ **PENTING:** Token ini HANYA muncul SEKALI! Simpan dengan aman!

   📝 **CATAT INI** → akan dipakai di `.env` sebagai `WHATSAPP_ACCESS_TOKEN`

✅ Permanent token created!

---

### Step 6: Add Your Own Phone Number

**Default test number hanya untuk testing.** Untuk production, tambahkan nomor sendiri:

1. Di WhatsApp product page, bagian **"Phone Numbers"**

2. Klik **"Add Phone Number"**

3. Pilih salah satu:
   - **Register a New Phone Number** (beli nomor baru)
   - **Use Your Own Phone Number** (pakai nomor yang sudah ada)

4. Isi form:
   - Country: **Indonesia (+62)**
   - Phone Number: Nomor tanpa +62 (misal: 81234567890)
   - Display Name: `Emergency Response Hotline`

5. Klik **"Next"**

6. **Verifikasi Nomor:**
   - Pilih metode: SMS atau Voice Call
   - Masukkan kode OTP yang diterima
   - Klik **"Verify"**

⚠️ **CATATAN:**
- Nomor TIDAK BOLEH sudah terdaftar di WhatsApp pribadi
- Jika sudah terdaftar, hapus dulu dari device
- Nomor akan jadi "Business Account" setelah verified

✅ Phone number verified!

---

### Step 7: Get New Phone Number ID

Setelah nomor verified:

1. Di WhatsApp product page → **"Phone Numbers"**

2. Klik nomor yang baru ditambahkan

3. Copy **Phone Number ID** (berbeda dari test number)
   ```
   Contoh: 234567890123456
   ```

4. **UPDATE `.env`:**
   ```env
   WHATSAPP_PHONE_NUMBER_ID=234567890123456  # NOMOR BARU INI!
   ```

---

### Step 8: Setup Webhook

**Webhook adalah endpoint yang akan menerima pesan masuk dari WhatsApp.**

#### A. Setup Server (Prerequisites)

**Webhook harus:**
- ✅ Accessible dari internet (public URL)
- ✅ HTTPS (Meta require SSL)
- ✅ Response dalam <5 detik

**Options:**

**Option 1: Ngrok (untuk testing)**
```bash
# Install ngrok
wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
tar xvzf ngrok-v3-stable-linux-amd64.tgz

# Run (di terminal terpisah)
./ngrok http 3000

# Copy URL yang muncul
# Contoh: https://abc123.ngrok.io
```

**Option 2: Cloud Server dengan Domain**
```bash
# Jika pakai cloud (AWS, GCP, DigitalOcean)
# Setup SSL dengan Let's Encrypt

# 1. Point domain ke IP server
# A record: chatbot.yourdomain.com → IP_SERVER

# 2. Install Certbot
sudo apt install certbot python3-certbot-nginx

# 3. Get SSL certificate
sudo certbot --nginx -d chatbot.yourdomain.com

# Your webhook URL: https://chatbot.yourdomain.com/webhook
```

#### B. Create Verify Token

Buat random string untuk verify token (simpan di `.env`):

```bash
# Generate random string
openssl rand -hex 16

# Output: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6

# Simpan di .env:
WHATSAPP_VERIFY_TOKEN=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
```

#### C. Configure Webhook di Meta

1. Di WhatsApp product page → **"Configuration"**

2. Section **"Webhook"** → Klik **"Edit"**

3. Isi form:
   - **Callback URL**: `https://your-domain.com/webhook` (atau ngrok URL)
   - **Verify Token**: Token yang dibuat di step B (dari `.env`)

4. Klik **"Verify and Save"**

**Meta akan hit endpoint:**
```
GET https://your-domain.com/webhook?hub.mode=subscribe&hub.verify_token=YOUR_TOKEN&hub.challenge=123456
```

**Server harus return:** `123456` (challenge value)

✅ Jika sukses: "Webhook verified successfully"

❌ Jika gagal: Check logs dan pastikan server running:
```bash
docker logs -f emergency_backend
```

#### D. Subscribe to Webhook Fields

1. Di Webhook configuration, scroll ke **"Webhook fields"**

2. Centang: **"messages"**

3. Klik **"Subscribe"**

✅ Webhook setup complete!

---

### Step 9: Test End-to-End

**Sekarang test kirim pesan:**

1. **Dari nomor WA lain**, kirim pesan ke nomor bisnis yang sudah disetup:
   ```
   Halo, ini test
   ```

2. **Check logs backend:**
   ```bash
   docker logs -f emergency_backend
   ```

   Harus muncul:
   ```
   Incoming message received from: 6281234567890
   Processing message...
   ```

3. **Bot harus reply** dengan welcome message atau konfirmasi

4. **Telegram admin group** harus dapat notifikasi

✅ **Jika semua OK** → System fully operational!

---

## 📝 Summary: Credential Yang Dibutuhkan

Setelah semua step selesai, Anda harus punya:

```env
# WhatsApp Cloud API
WHATSAPP_PHONE_NUMBER_ID=234567890123456  # From Step 7
WHATSAPP_ACCESS_TOKEN=EAABsbCS1iHgBOyJ9rxxxxxxxxxxxxxx  # From Step 5 (permanent token)
WHATSAPP_VERIFY_TOKEN=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6  # From Step 8B (self-generated)
WHATSAPP_BUSINESS_ACCOUNT_ID=987654321098765  # From Step 4
```

**Save semua ini di `.env` file!**

---

## 🚨 Troubleshooting

### Webhook Verification Failed

**Error:** "The callback URL or verify token couldn't be validated"

**Solutions:**

1. **Check URL accessible:**
   ```bash
   curl https://your-domain.com/webhook
   ```
   Harus return response (tidak timeout/error)

2. **Check verify token:**
   - Token di Meta console HARUS SAMA dengan `WHATSAPP_VERIFY_TOKEN` di `.env`
   - Case-sensitive!

3. **Check server logs:**
   ```bash
   docker logs emergency_backend | grep webhook
   ```

4. **Test manual:**
   ```bash
   curl "http://localhost:3000/webhook?hub.mode=subscribe&hub.verify_token=YOUR_TOKEN&hub.challenge=test123"
   ```
   Harus return: `test123`

### Message Not Received

**Bot tidak reply saat kirim pesan:**

1. **Check webhook subscribed:**
   - Meta console → WhatsApp → Configuration
   - "messages" field harus checked

2. **Check backend running:**
   ```bash
   docker ps | grep emergency_backend
   ```

3. **Check logs:**
   ```bash
   docker logs -f emergency_backend
   ```

4. **Test webhook manually:**
   - Kirim test message dari Meta console "Send Message" tool

### Token Expired

**Error:** "Invalid OAuth access token"

**Solution:** Token temporary sudah expired (Step 4). Pakai permanent token (Step 5).

---

## 💰 Pricing

**Free Tier:**
- 1000 service conversations per month (FREE)
- Service conversation = 24-hour window setelah user kirim pesan
- Gratis forever untuk volume kecil

**After Free Tier:**
- ~$0.005 - $0.03 per conversation (tergantung negara)
- Indonesia: ~Rp 75 - Rp 450 per conversation

**Estimasi untuk emergency response:**
- 100 laporan/hari = 3000 conversations/month
- Cost: ~$100-150/month (setelah 1000 free)

---

## 📚 Resources

- **Official Docs:** https://developers.facebook.com/docs/whatsapp/cloud-api
- **API Reference:** https://developers.facebook.com/docs/whatsapp/cloud-api/reference
- **Pricing:** https://developers.facebook.com/docs/whatsapp/pricing
- **Support:** https://developers.facebook.com/support/bugs/

---

## 🆘 Need Help?

- **Meta Developer Community:** https://developers.facebook.com/community/
- **WhatsApp Business API Support:** Via Meta Business Suite
- **Technical Issues:** Raise issue di GitHub repository

---

**Last Updated:** 2024-11-26
