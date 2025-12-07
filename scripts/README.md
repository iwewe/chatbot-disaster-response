# 🛠️ Deployment & Management Scripts

Kumpulan script untuk deployment dan management Emergency Response System.

## 📋 Script List

### 🚀 Deployment Scripts

| Script | Fungsi | Penggunaan |
|--------|--------|------------|
| **deploy-git.sh** | Deploy/update sistem menggunakan Git | `./deploy-git.sh` |
| **deploy-curl.sh** | Deploy/update sistem menggunakan Curl (tanpa Git) | `./deploy-curl.sh` |
| **deploy-dashboard.sh** | Deploy web dashboard (Nginx/Docker/HTTP) | `./deploy-dashboard.sh` |

### 🔄 Update Scripts

| Script | Fungsi | Penggunaan |
|--------|--------|------------|
| **update-dashboard.sh** | Update dashboard saja tanpa rebuild backend | `./update-dashboard.sh` |

### 🎛️ Management Scripts

| Script | Fungsi | Penggunaan |
|--------|--------|------------|
| **restart-services.sh** | Interactive menu untuk restart services | `./restart-services.sh` |
| **setup-admin.sh** | Create/update admin user untuk dashboard | `./setup-admin.sh` |
| **monitor.sh** | Monitor health dan status semua services | `./monitor.sh` |

### 🗄️ Legacy Scripts

| Script | Fungsi | Status |
|--------|--------|--------|
| deploy.sh | Old deployment script | Replaced by deploy-git.sh |
| dev-setup.sh | Development setup | Use for development only |
| install.sh | Old install script | Replaced by deploy-curl.sh |

---

## 📖 Detailed Usage

### 1. deploy-git.sh

**Deployment menggunakan Git**

```bash
./deploy-git.sh
```

**Apa yang dilakukan:**
- Clone atau pull repository dari GitHub
- Backup .env file yang existing
- Build Docker containers
- Start semua services
- Run database migrations
- Check admin user

**Kapan digunakan:**
- First-time installation dengan Git
- Update system dari repository
- Server dengan Git installed

---

### 2. deploy-curl.sh

**Deployment menggunakan Curl (tanpa Git)**

```bash
./deploy-curl.sh
```

**Apa yang dilakukan:**
- Download semua file dari GitHub menggunakan curl
- Setup directory structure
- Build Docker containers
- Start services
- Run migrations

**Kapan digunakan:**
- Server tanpa Git
- Restricted network environment
- Direct download preferred

---

### 3. deploy-dashboard.sh

**Deploy web dashboard**

```bash
./deploy-dashboard.sh
```

**Options:**
1. **Nginx** (Production)
   - Full web server setup
   - SSL/HTTPS support
   - Proxy API requests
   - Caching & compression

2. **Docker Nginx** (Containerized)
   - Run as Docker container
   - Port 8080 default
   - Easy management

3. **Simple HTTP Server** (Development)
   - Python HTTP server
   - Quick testing
   - NOT for production

**Apa yang dilakukan:**
- Setup web server (Nginx atau Docker)
- Configure proxy untuk API
- Deploy dashboard files
- Start web server

**Kapan digunakan:**
- Setelah backend deployed
- First dashboard deployment
- Change deployment method

---

### 4. update-dashboard.sh

**Update dashboard files saja**

```bash
./update-dashboard.sh
```

**Methods:**
1. Git pull (jika installed via git)
2. Curl download (direct download)

**Apa yang dilakukan:**
- Backup current dashboard
- Download/pull latest dashboard files
- Update deployed files (Nginx/Docker)
- Restart if needed

**Kapan digunakan:**
- Dashboard code updates
- UI/UX changes
- Tidak ada perubahan backend

---

### 5. restart-services.sh

**Interactive service management**

```bash
./restart-services.sh
```

**Menu Options:**
1. All services - Restart semua
2. Backend only - Restart backend
3. Database (PostgreSQL) - Restart DB
4. Redis - Restart cache
5. Ollama - Restart AI service
6. Dashboard - Restart web server
7. Rebuild backend (no cache) - Full rebuild backend
8. Full rebuild (all services) - Rebuild semua
9. View logs - Lihat logs service

**Apa yang dilakukan:**
- Interactive menu
- Selective service restart
- Rebuild options
- Log viewing

**Kapan digunakan:**
- Service troubleshooting
- Apply configuration changes
- Performance issues
- After code updates

---

### 6. setup-admin.sh

**Create atau update admin user**

```bash
./setup-admin.sh
```

**Input Required:**
- Phone number (WhatsApp format)
- Full name
- Admin password (optional - bisa via .env)

**Apa yang dilakukan:**
- Create admin user di database
- Set role sebagai ADMIN
- Trust level 5
- Active status

**Kapan digunakan:**
- First-time setup
- Create additional admin
- Reset admin access
- Change admin details

---

### 7. monitor.sh

**System health monitoring**

```bash
./monitor.sh

# Continuous monitoring
watch -n 5 ./monitor.sh
```

**Information Displayed:**
- Docker services status
- Container uptime
- Network ports status
- API health checks
- Service health details (Ollama, WhatsApp, DB)
- Ollama models installed
- Resource usage (CPU, Memory)
- Recent errors
- Database statistics
- Disk usage

**Apa yang dilakukan:**
- Check all service status
- Health endpoint tests
- Resource monitoring
- Error detection
- Database stats

**Kapan digunakan:**
- Daily monitoring
- Troubleshooting
- Performance check
- System overview
- Before/after deployment

---

## 🎯 Common Workflows

### First-Time Deployment

```bash
# 1. Deploy system
./deploy-git.sh
# atau
./deploy-curl.sh

# 2. Setup admin user
./setup-admin.sh

# 3. Deploy dashboard
./deploy-dashboard.sh

# 4. Monitor system
./monitor.sh
```

### Regular Updates

```bash
# Update full system
./deploy-git.sh

# Or update dashboard only
./update-dashboard.sh

# Check system health
./monitor.sh
```

### Troubleshooting

```bash
# 1. Check status
./monitor.sh

# 2. View logs
./restart-services.sh
# Choose option 9: View logs

# 3. Restart problematic service
./restart-services.sh
# Choose specific service

# 4. Full rebuild if needed
./restart-services.sh
# Choose option 8: Full rebuild
```

---

## 📝 Notes

- Semua script sudah executable (`chmod +x`)
- Color-coded output untuk readability
- Error handling included
- Backup otomatis sebelum update
- Support docker compose dan docker-compose
- Interactive menus untuk ease of use

---

## 🆘 Troubleshooting Scripts

### Script Permission Denied

```bash
chmod +x scripts/*.sh
```

### Script Not Found

```bash
cd ~/chatbot-disaster-response/scripts
ls -la
```

### Docker Command Not Found

```bash
# Install Docker
curl -fsSL https://get.docker.com | bash
```

---

## 📚 Documentation

- [DEPLOYMENT.md](../DEPLOYMENT.md) - Full deployment guide
- [QUICK-START.md](../QUICK-START.md) - Quick reference
- [README.md](../README.md) - Project overview

---

**Last Updated**: 2025-12-07
