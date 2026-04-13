# Notification Scheduler Setup Guide

This guide helps you set up automated notifications on your Raspberry Pi for AI Reminders.

## 🎯 Features

- **7 AM Daily Summary**: Receive a list of all reminders for today
- **Pre-Event Reminders**: Get notified 15 minutes (configurable) before each event
- **Multiple Channels**: Support for Telegram and WhatsApp
- **24/7 Scheduling**: Runs continuously on your Pi

---

## 📋 Quick Start

### 1. Install Dependencies

```bash
cd mcp/python

# Activate virtual environment
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install notification packages
pip install -r requirements.txt
```

### 2. Configure .env File

Copy the template:
```bash
cp .env.example .env
```

Edit `.env` and fill in the notification settings (see detailed setup below).

### 3. Run the Scheduler

```bash
python notification_scheduler.py
```

You should see output like:
```
2026-04-12 07:00:00 - __main__ - INFO - ✓ Firebase initialized
2026-04-12 07:00:01 - __main__ - INFO - ✓ Telegram notifier ready
2026-04-12 07:00:02 - __main__ - INFO - ✓ WhatsApp notifier ready
2026-04-12 07:00:03 - __main__ - INFO - ✓ Scheduled morning summary at 07:00
2026-04-12 07:00:04 - __main__ - INFO - ✓ Scheduled pre-event reminder checker
2026-04-12 07:00:05 - __main__ - INFO - 💚 Notification scheduler is running. Press Ctrl+C to stop.
```

---

## 🤖 Telegram Setup

### Step 1: Create Telegram Bot

1. Open Telegram and search for **@BotFather**
2. Send `/newbot`
3. Follow the prompts:
   - Name your bot (e.g., "AI Reminder")
   - Choose a username (e.g., "ai_reminder_bot")
4. BotFather will give you a **token** like:
   ```
   123456789:ABCdefghIJKlmnoPQRstuvWXYzabcdef
   ```

### Step 2: Get Your Chat ID

1. Start the bot you just created by searching for it in Telegram
2. Send it any message (e.g., `/start`)
3. Now find your Chat ID:
   - **Option A (Recommended)**: Search for **@userinfobot** in Telegram
   - Send it `/start`
   - It will reply with your Chat ID (e.g., `123456789`)
   
   OR
   
   - **Option B**: Go to this URL in your browser (replace TOKEN):
     ```
     https://api.telegram.org/botTOKEN/getUpdates
     ```
     Look for `"from"` → `"id"` in the response

### Step 3: Update .env

```env
ENABLE_TELEGRAM=true
TELEGRAM_BOT_TOKEN=123456789:ABCdefghIJKlmnoPQRstuvWXYzabcdef
TELEGRAM_CHAT_ID=123456789
```

### Test

Telegram messages will be formatted with emoji and markdown:
```
📅 **Good Morning! Today's Reminders:**

1. **Team Meeting**
   ⏰ 2026-04-12T14:00:00

2. **Lunch with Sarah**
   ⏰ 2026-04-12T12:30:00
```

---

## 📱 WhatsApp Setup

You have **two options**:

### Option A: Twilio (Recommended - Easier)

#### Setup Twilio Account

1. Go to [twilio.com](https://www.twilio.com)
2. Sign up for a **free trial account**
3. Go to **Console Dashboard**
4. Copy:
   - `ACCOUNT SID` → `TWILIO_ACCOUNT_SID`
   - `AUTH TOKEN` → `TWILIO_AUTH_TOKEN`

#### Enable WhatsApp Sandbox

1. In Twilio Console, go to **Messaging → WhatsApp → Sandbox**
2. You'll see a number like: `+14155238886`
3. Join the sandbox by sending this message to the Twilio number:
   ```
   join WORD-WORD
   ```
   (Replace with the actual join code shown in sandbox settings)

4. **Save the phone number**: `whatsapp:+14155238886`

#### Get Your Phone Number

The phone number you want to **receive** messages on (with country code):
- Examples: `+1234567890`, `+447911123456`, `+353872345678`

#### Update .env

```env
ENABLE_WHATSAPP=true
WHATSAPP_METHOD=twilio

TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token_here
TWILIO_WHATSAPP_FROM=whatsapp:+14155238886
WHATSAPP_RECIPIENT_PHONE=+YOUR_PHONE_NUMBER
```

**Note**: The free Twilio sandbox has limitations. For production, you need to:
1. Upgrade Twilio account to production
2. Request WhatsApp Business Account
3. Update `TWILIO_WHATSAPP_FROM` to your business number

---

### Option B: WhatsApp Business API (Advanced)

This requires setting up the official WhatsApp Business API.

#### Prerequisites

- A Facebook Business Account
- WhatsApp Business Account verified
- A business phone number
- Meta/Facebook API access

#### Setup Steps

1. Get your credentials from Meta Business Platform:
   - Phone ID
   - Access Token
   - Business API URL

2. Update .env

```env
ENABLE_WHATSAPP=true
WHATSAPP_METHOD=business

WHATSAPP_BUSINESS_API_URL=https://graph.instagram.com/v18.0
WHATSAPP_BUSINESS_PHONE_ID=your_phone_id
WHATSAPP_BUSINESS_ACCESS_TOKEN=your_access_token
WHATSAPP_RECIPIENT_PHONE=your_recipient_phone_number
```

3. (Optional) Create message templates for better formatting

---

## ⚙️ Advanced Configuration

### Custom Morning Time

Change when the daily summary is sent:

```env
# Send at 8:30 AM instead of 7:00 AM
MORNING_SUMMARY_HOUR=8
MORNING_SUMMARY_MINUTE=30
```

### Custom Pre-Event Reminder Time

Change how many minutes before an event to send reminder:

```env
# Send reminder 30 minutes before (instead of 15)
PRE_EVENT_REMINDER_MINUTES=30
```

### Notification Check Frequency

How often to check for upcoming events:

```env
# Check every 30 seconds (default is 60)
NOTIFICATION_CHECK_INTERVAL_SECONDS=30
```

### Disable Channels

```env
# Don't send Telegram messages
ENABLE_TELEGRAM=false

# Don't send WhatsApp messages
ENABLE_WHATSAPP=false
```

---

## 🖥️ Run as Systemd Service (Persistent on Pi)

To make the scheduler run automatically on boot:

### 1. Create Service File

```bash
sudo nano /etc/systemd/system/aireminder-notifications.service
```

### 2. Paste This Content

```ini
[Unit]
Description=AI Reminder Notification Scheduler
After=network.target

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

### 3. Enable and Start

```bash
# Enable on boot
sudo systemctl enable aireminder-notifications.service

# Start now
sudo systemctl start aireminder-notifications.service

# Check status
sudo systemctl status aireminder-notifications.service

# View logs
sudo journalctl -u aireminder-notifications.service -f
```

### 4. Manage the Service

```bash
# Stop
sudo systemctl stop aireminder-notifications.service

# Restart
sudo systemctl restart aireminder-notifications.service

# Check logs
sudo journalctl -u aireminder-notifications.service -n 50
```

---

## 🐛 Troubleshooting

### Telegram bot not sending messages

**Check:**
1. Is `TELEGRAM_BOT_TOKEN` correct?
2. Is `TELEGRAM_CHAT_ID` correct?
3. Did you send a message to the bot first to "activate" it?

**Fix:**
```bash
# Test connection manually
python -c "
from telegram import Bot
import asyncio

async def test():
    bot = Bot(token='YOUR_TOKEN')
    me = await bot.get_me()
    print(f'Bot connected: {me.username}')

asyncio.run(test())
"
```

### WhatsApp messages failing

**Check:**
1. Is `TWILIO_ACCOUNT_SID` correct?
2. Is `TWILIO_AUTH_TOKEN` correct?
3. Did you join the WhatsApp sandbox?
4. Is `WHATSAPP_RECIPIENT_PHONE` in the correct format (with country code)?

**Fix:**
```bash
# Test Twilio connection
python -c "
from twilio.rest import Client

account_sid = 'YOUR_SID'
auth_token = 'YOUR_TOKEN'
client = Client(account_sid, auth_token)

# Try to send test message
message = client.messages.create(
    from_='whatsapp:+14155238886',
    body='Test from Twilio',
    to='whatsapp:+YOUR_PHONE'
)
print(f'Message SID: {message.sid}')
"
```

### Scheduler not running

**Check:**
1. Are dependencies installed? `pip list | grep -E "APScheduler|telegram"`
2. Are Firebase credentials correct in `.env`?
3. Check logs: `python notification_scheduler.py` (run directly to see errors)

---

## 📊 Example Output

### Morning Summary (7 AM)

**Telegram:**
```
📅 Good Morning! Today's Reminders:

1. Team Standup
   ⏰ 2026-04-12T09:00:00

2. Project Review Meeting
   ⏰ 2026-04-12T14:00:00

3. Dinner with friends
   ⏰ 2026-04-12T18:30:00
```

### Pre-Event Reminder (15 min before)

**WhatsApp:**
```
⏰ Upcoming Reminder (15 min)

📌 Team Standup
⏱️ Starts at: 2026-04-12T09:00:00

🔔 Don't miss it!
```

---

## 📞 Support

- **Telegram Bot Help**: Message @BotFather
- **Twilio Help**: Visit [twilio.com/console](https://www.twilio.com/console)
- **WhatsApp Business API**: [developers.facebook.com/docs/whatsapp](https://developers.facebook.com/docs/whatsapp)

---

## 🔒 Security Notes

- Never commit `.env` file to git
- Keep `TELEGRAM_BOT_TOKEN` and `TWILIO_AUTH_TOKEN` secret
- Use environment variables, not hardcoded values
- On a shared Pi, use restricted file permissions: `chmod 600 .env`

---

## Next Steps

1. ✅ Set up Telegram and/or WhatsApp
2. ✅ Configure `.env` with your credentials
3. ✅ Run `python notification_scheduler.py`
4. ✅ (Optional) Set up as systemd service for auto-start
5. ✅ Test by creating a reminder for soon

Happy reminding! 🎉
