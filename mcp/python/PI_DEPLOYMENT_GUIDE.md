# AI Reminder - Complete Pi Deployment Guide

This guide walks you through deploying the AI Reminder project on your Raspberry Pi with both the **MCP Server** and **Notification Scheduler**.

## 🎯 Architecture Overview

```
Raspberry Pi (24/7)
├── MCP Server (port 8000)
│   └─ Serves reminder data via HTTP API
│
├── Notification Scheduler (background)
│   ├─ 7 AM: Sends daily summary
│   ├─ Continuous: Checks for 15-min pre-event reminders
│   └─ Sends via Telegram & WhatsApp
│
└─ Firestore
   └─ Cloud database (accessed by both services)

OpenClaw (anywhere)
└─ Accesses MCP Server via HTTP
   └─ Gets reminders via natural language
```

---

## 📦 Prerequisites

- Raspberry Pi 4+ (2GB RAM minimum, 4GB+ recommended)
- Raspberry Pi OS (Bullseye or later)
- Internet connection
- Domain/IP accessible from outside (optional)

---

## 🚀 Step 1: Initial Pi Setup

### 1.1 SSH into Pi

```bash
ssh pi@192.168.1.X  # Replace with your Pi's IP
# Default password: raspberry
```

### 1.2 Update System

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-venv git
```

### 1.3 Clone/Download Project

```bash
cd ~
git clone <your-repo-url> aireminder
cd aireminder/mcp/python
```

Or if you prefer to upload manually:
```bash
# On your local PC:
scp -r mcp/python pi@192.168.1.X:~/aireminder/mcp/python
```

---

## 🔧 Step 2: Set Up Python Environment

### 2.1 Create Virtual Environment

```bash
cd ~/aireminder/mcp/python

# Create venv
python3 -m venv venv

# Activate
source venv/bin/activate
```

### 2.2 Install Dependencies

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

This installs all packages including:
- FastAPI (MCP Server)
- APScheduler (Notification Scheduler)
- python-telegram-bot
- twilio (for WhatsApp)
- firebase-admin

---

## 🔐 Step 3: Configure Credentials

### 3.1 Copy Environment Template

```bash
cp .env.example .env
nano .env
```

### 3.2 Fill in Required Fields

**Firebase Configuration** (from your project):
```env
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxx@your-project.iam.gserviceaccount.com
USER_ID=your-email@gmail.com
```

**Telegram** (see NOTIFICATION_SCHEDULER_SETUP.md for details):
```env
ENABLE_TELEGRAM=true
TELEGRAM_BOT_TOKEN=123456789:ABCdefghIJKlmnoPQRstuvWXYzabcdef
TELEGRAM_CHAT_ID=123456789
```

**WhatsApp** (see NOTIFICATION_SCHEDULER_SETUP.md for details):
```env
ENABLE_WHATSAPP=true
WHATSAPP_METHOD=twilio
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_token
TWILIO_WHATSAPP_FROM=whatsapp:+14155238886
WHATSAPP_RECIPIENT_PHONE=+1234567890
```

### 3.3 Protect Credentials

```bash
chmod 600 .env  # Only pi user can read
```

---

## ✅ Step 4: Test Both Services

### 4.1 Test MCP Server

```bash
# Activate venv
source venv/bin/activate

# Run MCP server
python mcp_server_lite.py
```

You should see:
```
INFO:     Uvicorn running on http://0.0.0.0:8000
```

Test in another terminal:
```bash
# Get API docs
curl http://localhost:8000/docs

# Test health
curl http://localhost:8000/health

# Get today's reminders
curl "http://localhost:8000/api/reminders/today?userId=your-email@gmail.com"
```

(Stop with Ctrl+C)

### 4.2 Test Notification Scheduler

```bash
# Activate venv (if not already)
source venv/bin/activate

# Run scheduler
python notification_scheduler.py
```

You should see:
```
2026-04-12 07:00:00 - __main__ - INFO - ✓ Firebase initialized
2026-04-12 07:00:01 - __main__ - INFO - ✓ Telegram notifier ready
2026-04-12 07:00:02 - __main__ - INFO - ✓ WhatsApp notifier ready
2026-04-12 07:00:03 - __main__ - INFO - ✓ Scheduled morning summary at 07:00
2026-04-12 07:00:04 - __main__ - INFO - 💚 Notification scheduler is running.
```

(Stop with Ctrl+C)

---

## 🔄 Step 5: Set Up Auto-Start Services

You'll create two systemd services so both start automatically on Pi reboot.

### 5.1 Create MCP Server Service

```bash
sudo nano /etc/systemd/system/aireminder-mcp.service
```

Paste:
```ini
[Unit]
Description=AI Reminder MCP Server
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/aireminder/mcp/python
Environment="PATH=/home/pi/aireminder/mcp/python/venv/bin"
ExecStart=/home/pi/aireminder/mcp/python/venv/bin/python mcp_server_lite.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### 5.2 Create Notification Scheduler Service

```bash
sudo nano /etc/systemd/system/aireminder-notifications.service
```

Paste:
```ini
[Unit]
Description=AI Reminder Notification Scheduler
After=network.target aireminder-mcp.service
Wants=aireminder-mcp.service

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/aireminder/mcp/python
Environment="PATH=/home/pi/aireminder/mcp/python/venv/bin"
ExecStart=/home/pi/aireminder/mcp/python/venv/bin/python notification_scheduler.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### 5.3 Enable Both Services

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable on boot
sudo systemctl enable aireminder-mcp.service
sudo systemctl enable aireminder-notifications.service

# Start now
sudo systemctl start aireminder-mcp.service
sudo systemctl start aireminder-notifications.service

# Check status
sudo systemctl status aireminder-mcp.service
sudo systemctl status aireminder-notifications.service
```

---

## 📊 Step 6: Monitor Services

### View Service Status

```bash
# Both services
systemctl list-units --type=service | grep aireminder

# Or individually
sudo systemctl status aireminder-mcp.service
sudo systemctl status aireminder-notifications.service
```

### View Logs

```bash
# MCP Server logs (last 50 lines)
sudo journalctl -u aireminder-mcp.service -n 50

# Notification Scheduler logs
sudo journalctl -u aireminder-notifications.service -n 50

# Real-time log stream
sudo journalctl -u aireminder-notifications.service -f
```

### Manage Services

```bash
# Stop a service
sudo systemctl stop aireminder-mcp.service

# Restart a service
sudo systemctl restart aireminder-mcp.service

# Disable on boot
sudo systemctl disable aireminder-mcp.service
```

---

## 🌐 Step 7: Expose Services (Optional)

### Option A: Local Network Only

If your Pi is on `192.168.1.100`:
- MCP Server: `http://192.168.1.100:8000`
- OpenClaw: Configure with this URL

### Option B: Access from Outside (Cloudflare Tunnel)

Make services accessible from anywhere:

#### Install Cloudflare Tunnel

```bash
curl -L --output cloudflared.tgz https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm.tgz
tar -xzf cloudflared.tgz
sudo mv cloudflared /usr/local/bin/
sudo chmod +x /usr/local/bin/cloudflared
```

#### Authenticate & Create Tunnel

```bash
cloudflared tunnel login
cloudflared tunnel create aireminder
```

#### Configure Tunnel

```bash
mkdir -p ~/.cloudflared
nano ~/.cloudflared/config.yml
```

Paste:
```yaml
tunnel: aireminder
credentials-file: /home/pi/.cloudflared/<UUID>.json
ingress:
  - hostname: reminders.yourdomain.com
    service: http://localhost:8000
  - service: http_status:404
```

#### Create DNS CNAME

In Cloudflare Dashboard:
- Create CNAME: `reminders.yourdomain.com` → `<tunnel-url>.cfargotunnel.com`

#### Run Tunnel

```bash
cloudflared tunnel run aireminder
```

Or as a service:
```bash
sudo cloudflared service install
sudo systemctl start cloudflared
```

Now access from anywhere: `https://reminders.yourdomain.com`

---

## 📱 Step 8: Test Notifications

### Create a Test Reminder

```bash
curl -X POST "http://localhost:8000/api/reminders/create" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "your-email@gmail.com",
    "title": "Test Reminder",
    "notes": "Testing notification system",
    "dueAt": "2026-04-12T07:15:00"
  }'
```

### Monitor Notifications

```bash
# Watch scheduler logs
sudo journalctl -u aireminder-notifications.service -f
```

At 7 AM or 15 minutes before your reminder, you should receive:
- Telegram message
- WhatsApp message

---

## 🐛 Troubleshooting

### Services not starting

```bash
# Check service status with detailed error
sudo systemctl status aireminder-mcp.service

# Check logs
sudo journalctl -u aireminder-mcp.service
```

### MCP Server not accessible

```bash
# Check if running
sudo lsof -i :8000

# Check firewall
sudo ufw status
sudo ufw allow 8000/tcp
```

### Notifications not sending

- Check Firebase credentials: `python -c "from firebase_config import test_connection; import asyncio; asyncio.run(test_connection())"`
- Check Telegram: See NOTIFICATION_SCHEDULER_SETUP.md
- Check WhatsApp: See NOTIFICATION_SCHEDULER_SETUP.md
- Check logs: `sudo journalctl -u aireminder-notifications.service -f`

### Service keeps restarting

```bash
# Check logs for errors
sudo journalctl -u aireminder-notifications.service | tail -50

# Test manually
cd ~/aireminder/mcp/python
source venv/bin/activate
python notification_scheduler.py
```

---

## 🔄 Updates & Maintenance

### Pull Latest Code

```bash
cd ~/aireminder
git pull origin main

# If dependencies changed:
cd mcp/python
source venv/bin/activate
pip install -r requirements.txt

# Restart services
sudo systemctl restart aireminder-mcp.service
sudo systemctl restart aireminder-notifications.service
```

### Pi Maintenance

```bash
# Check disk space
df -h

# Check memory
free -h

# Check CPU temp
vcgencmd measure_temp

# Reboot if needed
sudo reboot
```

---

## 📞 Common Tasks

### Tail Logs in Real-Time

```bash
# All AI Reminder services
sudo journalctl -u aireminder-* -f
```

### Test API Endpoint

```bash
# Get reminders for today
curl "http://localhost:8000/api/reminders/today?userId=your@email.com"

# Get all reminders
curl "http://localhost:8000/api/reminders/list?userId=your@email.com"

# View interactive API docs
# Open in browser: http://192.168.1.100:8000/docs
```

### Check Resource Usage

```bash
# Install (if needed)
sudo apt install -y htop

# Run
htop
# Press 'q' to quit
```

---

## 📈 Performance Tips

1. **Pi Storage**: Keep at least 500MB free
2. **Memory**: Upgrade to 4GB+ for better performance
3. **Network**: Use wired Ethernet for reliability
4. **Backups**: Regularly backup `.env` file (not to git!)
5. **Logs**: Periodically clean old logs: `sudo journalctl --vacuum=time=30d`

---

## 🎉 Next Steps

1. ✅ Deploy MCP Server on Pi
2. ✅ Deploy Notification Scheduler on Pi
3. ✅ Set up Telegram/WhatsApp notifications
4. ✅ Configure OpenClaw to use MCP Server
5. ✅ Test end-to-end notification flow
6. ✅ Monitor logs for the week

---

## 📚 Additional Resources

- [NOTIFICATION_SCHEDULER_SETUP.md](NOTIFICATION_SCHEDULER_SETUP.md) - Telegram & WhatsApp setup
- [OPENCLAW_SETUP.md](OPENCLAW_SETUP.md) - OpenClaw integration
- [README.md](README.md) - MCP Server overview
- [Raspberry Pi Docs](https://www.raspberrypi.com/documentation/)
- [systemd Documentation](https://systemd.io/)

---

Happy reminding on your Pi! 🎉
