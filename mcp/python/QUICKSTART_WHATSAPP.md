# Quick Start: WhatsApp Notifications

## 5-Minute Setup

### Step 1: Get Twilio Account (2 min)
```bash
# Visit: https://www.twilio.com/try-twilio
# Sign up → Verify email → Get Account SID & Auth Token
```

### Step 2: Create WhatsApp Sandbox (2 min)
```
1. Go to Twilio Console
2. Click "WhatsApp" under Products
3. Click "Sandbox"
4. You'll see a tutorial code like: join some-word-here
5. Send that EXACT message to the Twilio sandbox number from WhatsApp
```

### Step 3: Configure (.env)
```bash
# Copy template
cp .env.example .env

# Edit .env with your details:
TWILIO_ACCOUNT_SID=AC...  # From Twilio dashboard
TWILIO_AUTH_TOKEN=...      # From Twilio dashboard  
TWILIO_WHATSAPP_FROM=whatsapp:+1234567890  # Sandbox number from Twilio
WHATSAPP_TO_NUMBER=whatsapp:+1234567890    # Your phone number
USER_ID=your_user_id
```

### Step 4: Install Twilio
```bash
pip install twilio
```

### Step 5: Test!
```bash
python3 send_events_to_whatsapp.py
```

You should get your today's events in WhatsApp!

---

## Automate Daily

### Option A: Cron Job (Linux/Mac)
```bash
crontab -e

# Add line for 8 AM daily:
0 8 * * * cd /home/eric/projects/aireminder/mcp/python && python3 send_events_to_whatsapp.py
```

### Option B: Windows Scheduled Task
```batch
# Run as administrator in Command Prompt:
schtasks /create /tn "WhatsApp Daily" /tr "python3 C:\path\to\send_events_to_whatsapp.py" /sc DAILY /st 08:00
```

---

## Files Included

- `send_events_to_whatsapp.py` - Main script to send daily events
- `whatsapp_notifier.py` - Twilio/WhatsApp API wrapper
- `WHATSAPP_SETUP.md` - Detailed setup guide
- `.env.example` - Environment variable template

---

## Troubleshooting

### "Connection failed"
→ Check your internet connection and Twilio credentials

### "Invalid phone number"  
→ Use format: `whatsapp:+1234567890` (with country code)

### "Sandbox not joined"
→ Send the exact "join" message to the Twilio number from your phone

### "No events found"
→ Make sure your USER_ID is correct and you have events for today

---

## Next: Go Production!

When ready to move to production:

1. Enable WhatsApp Business on your Twilio account
2. Verify your actual phone number (not sandbox)
3. Update `.env` with production numbers
4. Done! Same code, real numbers.

---

## Need Help?

- Check `WHATSAPP_SETUP.md` for detailed guide
- View Twilio logs: https://www.twilio.com/console/logs
- Read API docs: https://www.twilio.com/docs/whatsapp/api

Happy reminding!
