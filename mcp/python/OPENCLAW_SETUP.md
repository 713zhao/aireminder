# OpenClaw Reminder Skill Setup Guide

## Overview
This guide helps you integrate your AI Reminder MCP Server with OpenClaw on your Raspberry Pi.

## Quick Setup (No Installation Needed!)

### Step 1: Copy the Skill File
```bash
# On your R-Pi or development machine:
cp openclaw_reminder_skill.js ~/.openclaw/skills/reminder.js
```

**Note**: No `npm install` needed! The skill is pure JavaScript with no external dependencies.

### Step 2: Configure Environment Variables
Add to your OpenClaw `.env` file (usually `~/.openclaw/.env`):

```bash
# AI Reminder Configuration
REMINDER_API_URL=http://localhost:8000
REMINDER_USER_ID=0502@hotmail.com
```

**For Remote Access** (if using R-Pi with Cloudflare Tunnel):
```bash
REMINDER_API_URL=https://your-tunnel-domain.com
REMINDER_USER_ID=0502@hotmail.com
```

### Step 3: Restart OpenClaw
```bash
# OpenClaw will auto-load the new skill
claw restart
# or
killall node  # if using Node.js directly
# then restart OpenClaw
```

### Step 4: Verify Installation
Message OpenClaw via your chat app (WhatsApp, Telegram, etc.):
```
You: "What reminders do I have today?"
Claw: [Should respond with your reminders or "no reminders today"]
```

---

## What the Skill Does

The skill exposes these capabilities to OpenClaw:

| Tool | Action |
|------|--------|
| `list_reminders_today` | Get all reminders due today |
| `list_reminders_upcoming` | Get upcoming reminders (next 7 days or custom) |
| `get_reminders_summary` | Get stats (total, pending, completed, overdue) |
| `get_overdue_reminders` | Get all overdue reminders |
| `create_reminder` | Create a new reminder |
| `search_reminders` | Search reminders by keyword |
| `update_reminder` | Edit a reminder |
| `complete_reminder` | Mark a reminder as done |
| `delete_reminder` | Delete a reminder |

---

## Usage Examples

### Natural Language (via WhatsApp/Telegram/Discord)
```
You: "Show me my reminders for today"
Claw: You have 3 reminders today:
      1. Call Mom (Due: 2026-02-22T15:00)
      2. Team meeting (Due: 2026-02-22T14:00)
      3. Grocery shopping (Due: 2026-02-22T18:00)

You: "What do I need to do this week?"
Claw: Upcoming reminders (5 total):
      1. Project deadline (Due: 2026-02-25T17:00)
      2. Dentist appointment (Due: 2026-02-26T10:00)
      ...

You: "Create a reminder to water plants tomorrow at 6 PM"
Claw: ✅ Reminder created: "water plants"
      Due: 2026-02-23T18:00

You: "Mark the dentist appointment as done"
Claw: ✅ Reminder marked as complete: "Dentist appointment"

You: "Delete the grocery reminder"
Claw: ✅ Reminder deleted

You: "Search for reminders about work"
Claw: Found 2 reminders:
      1. Finish project report (Due: 2026-02-25T17:00)
      2. Team standup (Due: 2026-02-24T09:00)
```

---

## Configuration

### Default User ID
The skill uses the user ID from your environment:
```javascript
// From the skill
defaultUserId: process.env.REMINDER_USER_ID || '0502@hotmail.com'
```

You can override per-request:
```
You: "Show reminders for user@example.com"
```

### API Timeout
Default: 10 seconds (adjust in skill if needed)

### Daily Briefing
The skill includes a scheduled task that runs at 8 AM daily:
```
[Cron: 0 8 * * *]
Time: 8:00 AM every day
Action: Sends reminder summary to your chat
```

---

## Troubleshooting

### "API not responding"
1. **Check if MCP server is running:**
   ```bash
   curl http://localhost:8000/health
   ```
   Should return: `{"status":"ok"}`

2. **Check firewall:**
   ```bash
   # Linux/Mac
   netstat -an | grep 8000
   
   # Windows PowerShell
   netstat -ano | findstr :8000
   ```

3. **Check environment variables:**
   ```bash
   echo $REMINDER_API_URL
   # Should output: http://localhost:8000
   ```

### "Reminders return empty"
- **Verify userId is correct:**
  ```bash
  # Your configured user should have reminders:
  curl "http://localhost:8000/api/reminders/summary?userId=YOUR_EMAIL"
  ```
- **Check Firestore has data in `shared_tasks` collection** (not `reminders`)

### "Skill not loading"
1. Check file is in correct location: `~/.openclaw/skills/reminder.js`
2. Restart OpenClaw: `claw restart`
3. Check OpenClaw logs for JavaScript errors

### "Remote access not working"
1. **Verify Cloudflare Tunnel is running:**
   ```bash
   cloudflared tunnel list
   ```

2. **Test tunnel from another device:**
   ```bash
   curl https://your-tunnel-domain.com/health
   ```

---

## File Locations

```
Your Project:
├── functions/python/
│   ├── mcp_server_lite.py      ← Your MCP server
│   ├── .env                    ← API credentials
│   └── openclaw_reminder_skill.js  ← This skill (copy to OpenClaw)
│
OpenClaw Installation:
├── ~/.openclaw/
│   ├── skills/
│   │   └── reminder.js         ← Paste the skill here
│   ├── .env                    ← Add REMINDER_* variables
│   └── config.json
```

---

## Advanced: Deploy on R-Pi with Systemd

### Keep MCP Server Running (R-Pi)
Create `/etc/systemd/system/aireminder-mcp.service`:
```ini
[Unit]
Description=AI Reminder MCP Server
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/aireminder/functions/python
Environment="PATH=/home/pi/aireminder/functions/python/venv/bin"
ExecStart=/home/pi/aireminder/functions/python/venv/bin/python mcp_server_lite.py
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable aireminder-mcp
sudo systemctl start aireminder-mcp
sudo systemctl status aireminder-mcp
```

### Remote Access via Cloudflare Tunnel
```bash
# Install (macOS)
brew install cloudflare/warp/cloudflared

# Install (Linux/R-Pi)
curl -L https://aka.cf/cloudflared-install | sh

# Create tunnel
cloudflared tunnel login
cloudflared tunnel create aireminder-mcp

# Configure tunnel to your MCP server
# Edit: ~/.cloudflared/config.yml
tunnel: aireminder-mcp
credentials-file: /home/pi/.cloudflared/aireminder-mcp.json

ingress:
  - hostname: reminder.yourdomain.com
    service: http://localhost:8000
  - service: http_status:404

# Run tunnel
cloudflared tunnel run aireminder-mcp
```

Then use in OpenClaw:
```bash
REMINDER_API_URL=https://reminder.yourdomain.com
```

---

## Next Steps

1. ✅ Copy skill to `~/.openclaw/skills/reminder.js`
2. ✅ Set environment variables in OpenClaw
3. ✅ Restart OpenClaw
4. ✅ Test via chat app
5. (Optional) Set up systemd service for R-Pi
6. (Optional) Set up Cloudflare Tunnel for remote access

---

## Support

- **OpenClaw Docs**: https://docs.openclaw.ai/
- **OpenClaw Discord**: https://discord.com/invite/clawd
- **Your MCP Server API**: http://localhost:8000/docs
