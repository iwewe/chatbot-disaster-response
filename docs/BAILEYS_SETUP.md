# Baileys WhatsApp Integration Guide

## 🎯 Overview

Emergency Chatbot mendukung **3 mode WhatsApp**:

1. **Meta Cloud API** - Official WhatsApp Business API (requires Meta business account)
2. **Baileys** - WhatsApp Web implementation (no Meta account needed, scan QR code)
3. **Hybrid** - Meta as primary, Baileys as automatic fallback

---

## 📊 Comparison: Meta vs Baileys vs Hybrid

| Feature | **Meta Cloud API** | **Baileys** | **Hybrid** |
|---------|-------------------|-------------|------------|
| **Setup Complexity** | ⚠️ Complex (business verification) | ✅ Simple (scan QR) | ⚠️ Complex (needs both) |
| **Cost** | 💰 Free 1000/month, then paid | ✅ Free forever | 💰 Same as Meta |
| **Reliability** | ⭐⭐⭐⭐⭐ Official | ⭐⭐⭐⭐ Community | ⭐⭐⭐⭐⭐ Best of both |
| **Phone Number** | Business number only | ✅ Any number | Both |
| **Setup Time** | 2-7 days (verification) | 5 minutes | 2-7 days |
| **Ban Risk** | ❌ Zero (official) | ⚠️ Low (if not spam) | ❌ Zero for Meta |
| **Deployment** | Webhook required | Direct connection | Both |
| **Best For** | Production, large orgs | Emergency, testing, NGOs | Critical systems |

---

## 🚀 Quick Start

### Option 1: Baileys Only (Fastest)

Perfect untuk emergency deployment tanpa Meta account:

```bash
# 1. Clone project
git clone https://github.com/iwewe/chatbot-disaster-response.git
cd chatbot-disaster-response

# 2. Run interactive setup (pilih Baileys mode)
bash scripts/setup-env.sh
# Saat ditanya: Select mode (1-3): ketik 2 (Baileys)

# 3. Deploy
bash scripts/deploy-light.sh  # atau deploy.sh untuk full version

# 4. Scan QR code dari console logs
docker logs emergency_backend -f
# QR code akan muncul, scan dengan WhatsApp Anda
```

✅ **Done!** Your personal WhatsApp number is now a disaster response chatbot.

---

### Option 2: Meta Cloud API Only

For official production deployment:

```bash
# 1. Setup Meta Business
# - Go to https://developers.facebook.com/
# - Create app, add WhatsApp Business
# - Get Phone Number ID, Access Token, etc.

# 2. Run setup and choose Meta mode
bash scripts/setup-env.sh
# Saat ditanya: Select mode (1-3): ketik 1 (Meta)
# Masukkan semua credentials dari Meta

# 3. Deploy
bash scripts/deploy-light.sh

# 4. Configure webhook di Meta Developer Console
# Webhook URL: https://your-domain.com/webhook
# Verify Token: (yang Anda generate di setup)
```

---

### Option 3: Hybrid Mode (Recommended for Critical Systems)

Best of both worlds - Meta as primary, Baileys as automatic fallback:

```bash
# 1. Setup both Meta account AND prepare to scan QR
bash scripts/setup-env.sh
# Saat ditanya: Select mode (1-3): ketik 3 (Hybrid)
# Masukkan Meta credentials

# 2. Deploy
bash scripts/deploy-light.sh

# 3. Configure Meta webhook (same as Option 2)

# 4. Scan QR code for Baileys fallback
docker logs emergency_backend -f
```

**How Hybrid Works:**
- All messages sent via **Meta API first**
- If Meta fails → **automatically switches to Baileys**
- Incoming messages: Meta via webhook, Baileys via WebSocket
- Zero downtime!

---

## 📱 Baileys Mode Details

### Authentication Flow

1. **First Run**: Container starts → generates QR code
2. **Scan**: Open WhatsApp → Settings → Linked Devices → Scan QR
3. **Connected**: Session saved to Docker volume
4. **Restart**: Auto-reconnect using saved session (no re-scan needed)

### Session Management

Sessions are stored in Docker volume `baileys_session`:

```bash
# View session files
docker exec emergency_backend ls -la /app/baileys-session

# Logout (force re-authentication)
docker exec emergency_backend rm -rf /app/baileys-session/*
docker restart emergency_backend

# Backup session
docker cp emergency_backend:/app/baileys-session ./baileys-backup

# Restore session
docker cp ./baileys-backup emergency_backend:/app/baileys-session
docker restart emergency_backend
```

### Viewing QR Code

**Method 1: Console logs (default)**
```bash
docker logs emergency_backend -f
# QR code rendered in ASCII
```

**Method 2: QR Code image file**
```bash
# QR saved as PNG file
docker exec emergency_backend cat /app/baileys-session/qr-code.png > qr.png
# Open qr.png with image viewer and scan
```

**Method 3: API endpoint (coming soon)**
```bash
curl http://localhost:3000/api/baileys/qr
```

---

## 🔧 Configuration

### Environment Variables

```bash
# .env file

# WhatsApp Mode Selection
WHATSAPP_MODE=baileys  # Options: meta, baileys, hybrid

# Meta credentials (required for 'meta' or 'hybrid')
WHATSAPP_PHONE_NUMBER_ID=your_phone_id
WHATSAPP_ACCESS_TOKEN=your_token
WHATSAPP_VERIFY_TOKEN=your_verify_token
WHATSAPP_BUSINESS_ACCOUNT_ID=your_account_id

# Note: For Baileys-only mode, Meta credentials can be left as placeholder
```

### Docker Compose

Baileys session volume automatically mounted:

```yaml
services:
  backend:
    volumes:
      - baileys_session:/app/baileys-session  # Session persistence

volumes:
  baileys_session:
    driver: local
```

---

## 🛠️ Troubleshooting

### QR Code Not Showing

**Problem**: No QR code in logs
```bash
docker logs emergency_backend | grep "QR"
```

**Solutions**:
1. Check WHATSAPP_MODE is set to `baileys` or `hybrid`
2. Wait 10-30 seconds after container starts
3. Restart container: `docker restart emergency_backend`
4. Check logs for errors: `docker logs emergency_backend --tail 100`

---

### Connection Keeps Dropping

**Problem**: Baileys disconnects frequently

**Causes & Solutions**:
1. **Network instability**
   - Ensure stable internet connection
   - Check Docker network: `docker network inspect emergency_network`

2. **WhatsApp Web logout**
   - Someone logged out from WhatsApp Settings → Linked Devices
   - Re-scan QR code

3. **Session corruption**
   ```bash
   # Clear session and re-authenticate
   docker exec emergency_backend rm -rf /app/baileys-session/*
   docker restart emergency_backend
   # Scan new QR code
   ```

---

### "Logged Out" Status

**Problem**: Baileys shows "logged out" message

**Solution**:
```bash
# 1. Clear session
docker exec emergency_backend rm -rf /app/baileys-session/*

# 2. Restart container
docker restart emergency_backend

# 3. Scan new QR code
docker logs emergency_backend -f
```

---

### Multi-Device Issues

**Problem**: "This phone could not be verified"

**Cause**: WhatsApp multi-device limit (max 4 linked devices)

**Solution**:
1. Open WhatsApp → Settings → Linked Devices
2. Remove unused devices
3. Scan QR code again

---

## 🔐 Security Considerations

### Baileys Mode Security

| Aspect | Risk Level | Mitigation |
|--------|-----------|------------|
| Ban Risk | ⚠️ Low | Don't spam, respect rate limits |
| Data Privacy | ✅ Good | All local, no cloud |
| Session Hijacking | ⚠️ Medium | Protect Docker volume access |
| Account Takeover | ⚠️ Low | Use 2FA on WhatsApp account |

### Recommendations

1. **Use dedicated WhatsApp number** for Baileys
2. **Enable 2FA** on WhatsApp account
3. **Restrict Docker volume access**
   ```bash
   # Set proper permissions
   sudo chown -R 1000:1000 /var/lib/docker/volumes/emergency-chatbot_baileys_session
   ```

4. **Regular session rotation**
   ```bash
   # Logout and re-authenticate monthly
   docker exec emergency_backend rm -rf /app/baileys-session/*
   docker restart emergency_backend
   ```

5. **Monitor for suspicious activity**
   ```bash
   # Check WhatsApp → Settings → Linked Devices regularly
   ```

---

## 📈 Production Deployment

### Recommended Setup

For **critical disaster response systems**, use **Hybrid Mode**:

```
┌─────────────────────────────────────────┐
│         Your Emergency Chatbot          │
│                                         │
│  ┌──────────────┐  ┌──────────────┐    │
│  │  Meta API    │  │   Baileys    │    │
│  │  (Primary)   │  │  (Fallback)  │    │
│  └──────┬───────┘  └──────┬───────┘    │
│         │                  │            │
│         ▼                  ▼            │
│    Official API      WhatsApp Web      │
│    (99.9% uptime)    (Backup)          │
└─────────────────────────────────────────┘
```

**Benefits**:
- **Meta fails** (webhook down, API quota) → Baileys handles
- **Baileys fails** (disconnected) → Meta still works
- **Both work** → Meta preferred for official status
- **Zero downtime** in emergencies

### Hybrid Mode Example

```bash
# .env configuration
WHATSAPP_MODE=hybrid

# Meta credentials (primary)
WHATSAPP_PHONE_NUMBER_ID=123456789
WHATSAPP_ACCESS_TOKEN=EAABsbCS...
WHATSAPP_VERIFY_TOKEN=my_verify_token
WHATSAPP_BUSINESS_ACCOUNT_ID=987654321

# Baileys will auto-initialize as fallback
# Scan QR code from logs after deployment
```

**Monitoring**:
```bash
# Check which service is active
docker logs emergency_backend | grep "WhatsApp mode"

# Watch for fallback activations
docker logs emergency_backend | grep "fallback"
```

---

## 🚨 Emergency Scenarios

### Scenario 1: Meta API Down During Disaster

**Problem**: Meta experiencing outage, but disaster happening NOW

**Solution**: Baileys to the rescue!

```bash
# If not already deployed with Baileys:

# 1. Quick switch to Baileys mode
cd ~/emergency-chatbot
nano .env
# Change: WHATSAPP_MODE=meta → WHATSAPP_MODE=baileys

# 2. Restart
docker restart emergency_backend

# 3. Scan QR code immediately
docker logs emergency_backend -f
# System operational in <2 minutes!
```

---

### Scenario 2: Lost Meta Access (Account Suspended)

**Problem**: Meta suspended business account

**Solution**: Full Baileys deployment

```bash
# Deploy with personal WhatsApp number
bash scripts/setup-env.sh
# Choose option 2 (Baileys)
# Provide Telegram credentials only
# Skip Meta credentials

bash scripts/deploy-light.sh
# Scan QR with personal/backup WhatsApp number
# Continue operations while resolving Meta issue
```

---

## 📞 Support

### Getting Help

1. **Check logs first**
   ```bash
   docker logs emergency_backend --tail 100
   ```

2. **Common solutions**
   - Clear Baileys session: `rm -rf baileys-session/*`
   - Restart container: `docker restart emergency_backend`
   - Check WhatsApp Linked Devices

3. **Community support**
   - GitHub Issues: https://github.com/iwewe/chatbot-disaster-response/issues
   - Tag with `baileys` label

---

## 📚 Additional Resources

- **Baileys Library**: https://github.com/WhiskeySockets/Baileys
- **WhatsApp Multi-Device**: https://faq.whatsapp.com/1317564962315842/
- **Meta WhatsApp API**: https://developers.facebook.com/docs/whatsapp

---

## 🎉 Quick Reference

| Task | Command |
|------|---------|
| View QR code | `docker logs emergency_backend -f` |
| Logout Baileys | `docker exec emergency_backend rm -rf /app/baileys-session/*` |
| Restart | `docker restart emergency_backend` |
| Check mode | `docker logs emergency_backend \| grep "WhatsApp mode"` |
| Backup session | `docker cp emergency_backend:/app/baileys-session ./backup` |
| Change mode | Edit `.env` → `WHATSAPP_MODE=meta/baileys/hybrid` → restart |

---

**Recommended for Disaster Response**: 🎯 **Hybrid Mode**

Ensures your system keeps running no matter what happens to Meta API!
