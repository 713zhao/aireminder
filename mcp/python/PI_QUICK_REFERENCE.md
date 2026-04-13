# AI Reminder - Pi Deployment Quick Reference

## 🚀 Quick Start (TL;DR)

```bash
# 1. SSH to Pi
ssh pi@192.168.1.X

# 2. Clone project
cd ~ && git clone <repo> aireminder && cd aireminder/mcp/python

# 3. Setup
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 4. Configure
cp .env.example .env
nano .env  # Fill in Firebase, Telegram, WhatsApp credentials

# 5. Test
python mcp_server_lite.py          # Terminal 1: Should show "Uvicorn running on..."
python notification_scheduler.py    # Terminal 2: Should show "✓ Telegram notifier ready"

# 6. Auto-start (copy-paste these)
sudo nano /etc/systemd/system/aireminder-mcp.service
# Paste content from PI_DEPLOYMENT_GUIDE.md
sudo nano /etc/systemd/system/aireminder-notifications.service
# Paste content from PI_DEPLOYMENT_GUIDE.md

# 7. Enable & Start
sudo systemctl daemon-reload
sudo systemctl enable aireminder-mcp.service aireminder-notifications.service
sudo systemctl start aireminder-mcp.service aireminder-notifications.service

# 8. Verify
sudo systemctl status aireminder-mcp.service
sudo systemctl status aireminder-notifications.service

# Done! Your Pi is now running 24/7 with notifications 🎉
```

---

## 📋 Required Credentials

You'll need these before starting:

| Service | What to Get | Where |
|---------|------------|-------|
| **Firebase** | Project ID, Private Key, Client Email | [Firebase Console](https://console.firebase.google.com) → Settings → Service Accounts |
| **Telegram** | Bot Token, Chat ID | [@BotFather](https://t.me/botfather) + [@userinfobot](https://t.me/userinfobot) |
| **WhatsApp (Twilio)** | Account SID, Auth Token, Twilio Number | [Twilio Console](https://www.twilio.com/console) |

---

## 📁 Key Files

```
mcp/python/
├── mcp_server_lite.py              # Starts HTTP API on :8000
├── notification_scheduler.py        # Runs scheduled notifications
├── telegram_notifier.py             # Telegram integration
├── whatsapp_notifier.py             # WhatsApp integration
├── reminders_service.py             # Firebase queries
├── requirements.txt                 # Python dependencies
├── .env.example                     # Template (copy to .env)
├── PI_DEPLOYMENT_GUIDE.md           # Full setup guide
├── NOTIFICATION_SCHEDULER_SETUP.md  # Telegram/WhatsApp setup
└── OPENCLAW_SETUP.md                # OpenClaw integration
```

---

## 🔄 Common Commands

### Check Service Status
```bash
sudo systemctl status aireminder-mcp.service
sudo systemctl status aireminder-notifications.service
```

### View Logs (Real-time)
```bash
sudo journalctl -u aireminder-mcp.service -f
sudo journalctl -u aireminder-notifications.service -f
```

### Restart Services
```bash
sudo systemctl restart aireminder-mcp.service
sudo systemctl restart aireminder-notifications.service
```

### Stop Services
```bash
sudo systemctl stop aireminder-mcp.service
sudo systemctl stop aireminder-notifications.service
```

### Test MCP Server
```bash
# Health check
curl http://localhost:8000/health

# Get today's reminders
curl "http://localhost:8000/api/reminders/today?userId=YOUR_EMAIL"

# Interactive docs
# Visit: http://192.168.1.X:8000/docs (replace X with Pi's IP)
```

### View Recent Logs
```bash
sudo journalctl -u aireminder-notifications.service -n 50 --no-pager
```

---

## 📱 What Happens

### 7:00 AM Every Day
Telegram & WhatsApp message:
```
📅 Good Morning! Today's Reminders:
1. Team Meeting
   ⏰ 2026-04-12T14:00:00
2. Lunch meeting
   ⏰ 2026-04-12T12:30:00
```

### 15 Minutes Before Event
Telegram & WhatsApp message:
```
⏰ Upcoming Reminder (15 min)
📌 Team Meeting
⏱️ Starts at: 2026-04-12T14:00:00
🔔 Don't miss it!
```

---

## 🐛 Troubleshooting

| Issue | Fix |
|-------|-----|
| **Services won't start** | Check logs: `sudo journalctl -u aireminder-mcp.service` |
| **Can't import firebase_config** | Ensure venv is activated and pip install -r requirements.txt ran |
| **Telegram not working** | Check TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID in .env |
| **WhatsApp not working** | Verify Twilio credentials and ensure you joined sandbox |
| **MCP Server not accessible** | Check port: `sudo lsof -i :8000` and firewall: `sudo ufw allow 8000/tcp` |
| **Notifications not sending** | Check email logs: `sudo journalctl -u aireminder-notifications.service -f` |

---

## 🔐 Security Checklist

- [ ] `.env` file has `chmod 600` (only pi can read)
- [ ] `.env` NOT committed to git
- [ ] Firebase private key is complete and correct
- [ ] Telegram bot token is secret
- [ ] Twilio auth token is secret
- [ ] Using strong Pi password (or disable password login)

---

## 🔧 Configuration Tweaks

### Change Morning Time
```bash
nano .env
MORNING_SUMMARY_HOUR=8      # 8 AM instead of 7 AM
MORNING_SUMMARY_MINUTE=30   # 30 minutes
```

### Change Pre-Event Reminder Time
```bash
PRE_EVENT_REMINDER_MINUTES=30  # 30 min before (instead of 15)
```

### Disable Telegram
```bash
ENABLE_TELEGRAM=false
```

### Disable WhatsApp
```bash
ENABLE_WHATSAPP=false
```

Then restart:
```bash
sudo systemctl restart aireminder-notifications.service
```

---

## 📊 System Requirements

- **CPU**: Raspberry Pi 4+ (or Pi 3B+ if patient)
- **RAM**: 2GB minimum, 4GB+ recommended
- **Storage**: 500MB+ free
- **Network**: Wired Ethernet recommended
- **Operating System**: Raspberry Pi OS (Bullseye or later)

---

## 🎯 Deployment Checklist

- [ ] Pi has Python 3.9+
- [ ] Project cloned to ~/aireminder
- [ ] Virtual environment created and activated
- [ ] requirements.txt installed
- [ ] .env configured with all credentials
- [ ] MCP Server tested (runs on :8000)
- [ ] Notification Scheduler tested (shows "ready")
- [ ] Both services created as systemd services
- [ ] Services enabled with `systemctl enable`
- [ ] Services started with `systemctl start`
- [ ] Status verified with `systemctl status`
- [ ] Logs checked for errors with `journalctl`
- [ ] Test reminder created and notifications received
- [ ] Services survived a reboot test

---

## 📚 Full Documentation

For detailed setup, see:
- **Telegram/WhatsApp**: [NOTIFICATION_SCHEDULER_SETUP.md](NOTIFICATION_SCHEDULER_SETUP.md)
- **Complete Deployment**: [PI_DEPLOYMENT_GUIDE.md](PI_DEPLOYMENT_GUIDE.md)
- **OpenClaw**: [OPENCLAW_SETUP.md](OPENCLAW_SETUP.md)
- **MCP Server API**: [README.md](README.md)

---

## 💬 Support

**Issue**: Services not starting after reboot  
**Solution**: Check logs - `sudo journalctl -u aireminder-mcp.service | tail -20`

**Issue**: Notifications not being sent  
**Solution**: Verify credentials in .env and check scheduler logs

**Issue**: Out of disk space  
**Solution**: `df -h` to check, cleanup logs: `sudo journalctl --vacuum=time=7d`

---

## 🎉 What's Next?

1. Set up OpenClaw to access your MCP Server
2. Add reminders via your Flutter app
3. Receive automatic notifications
4. Access reminders via OpenClaw (WhatsApp, Telegram, etc.)

Happy reminding! 🚀
