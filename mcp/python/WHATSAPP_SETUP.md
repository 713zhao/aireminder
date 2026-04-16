# WhatsApp Notifications Setup Guide

## Overview
This guide shows how to add WhatsApp notifications to your AI Reminder system. There are two main approaches:

1. **Twilio WhatsApp API** (Quick & Easy - Recommended for individuals)
2. **WhatsApp Business API** (Enterprise - Requires approval)

---

## Option 1: Twilio WhatsApp API (Recommended)

### Why Twilio?
- Quick setup (15 minutes)
- Sandbox for testing (no approval needed)
- Reliable for personal use
- Good free tier

### Step 1: Create Twilio Account

1. Go to https://www.twilio.com/try-twilio
2. Sign up and verify your email
3. You'll get a free trial account with $15 credit
4. Get your credentials from the dashboard:
   - Account SID
   - Auth Token

### Step 2: Create WhatsApp Sandbox

1. Go to https://www.twilio.com/console/sms/whatsapp/learn (logged in)
2. Click "Create Sandbox"
3. You'll get a sandbox phone number (something like `+1234567890`)
4. Join the sandbox by sending "join <code>" to that number from your phone
   - WhatsApp will send you the code
   - Send exactly as shown

### Step 3: Get Your Phone Number

1. From your WhatsApp account, verify the phone number you used above
2. Add international code (e.g., +1 for US)

### Step 4: Update Environment Variables

Add to `.env` file:

```bash
# Twilio WhatsApp
TWILIO_ACCOUNT_SID=your_account_sid_here
TWILIO_AUTH_TOKEN=your_auth_token_here
TWILIO_WHATSAPP_FROM=whatsapp:+1234567890  # Sandbox number from Twilio
WHATSAPP_TO_NUMBER=whatsapp:+yourphonenumber  # Your real number
```

### Step 5: Install Dependencies

```bash
pip install twilio
```

### Step 6: Test It

```bash
python3 send_events_to_whatsapp.py
```

---

## Option 2: WhatsApp Business API (Enterprise)

### Prerequisites
- Business Meta/Facebook account
- WhatsApp Business Account approved
- Phone number verified
- API access approved

### Setup Steps

1. Go to https://developers.facebook.com/
2. Create/Login to your app
3. Add "WhatsApp" product
4. Configure webhooks
5. Get credentials:
   - Phone Number ID
   - Business Account ID  
   - Access Token
   - Recipient Phone Number

### Update Environment Variables

```bash
# WhatsApp Business API
WHATSAPP_BUSINESS_PHONE_ID=your_phone_id
WHATSAPP_BUSINESS_ACCOUNT_ID=your_account_id
WHATSAPP_BUSINESS_ACCESS_TOKEN=your_access_token
WHATSAPP_RECIPIENT_PHONE=+yourphonenumber
```

### Usage

```python
from whatsapp_notifier import WhatsAppBusinessAPI

notifier = WhatsAppBusinessAPI()
await notifier.initialize()
await notifier.send_message("Your message here")
```

---

## Integration with Reminders

### Automatic Daily Digest via WhatsApp

1. Create a cron job to run the script daily:

```bash
# Edit crontab
crontab -e

# Add this line to send at 8 AM every day
0 8 * * * cd /home/eric/projects/aireminder/mcp/python && /usr/bin/python3 send_events_to_whatsapp.py
```

### Manual Script Usage

```bash
# In your terminal
cd /home/eric/projects/aireminder/mcp/python
python3 send_events_to_whatsapp.py
```

### Programmatic Usage

```python
import asyncio
from send_events_to_whatsapp import send_today_events_whatsapp

async def main():
    success = await send_today_events_whatsapp()
    if success:
        print("Events sent!")

asyncio.run(main())
```

---

## Troubleshooting

### "Twilio not installed"
```bash
pip install twilio
```

### "TWILIO_ACCOUNT_SID not set"
- Check your `.env` file
- Make sure you added all credentials
- Restart your Python process

### "WhatsApp sandbox not joined"
- Send exactly: `join <code>` to the Twilio sandbox number
- Wait 2-3 minutes
- Try again

### "Message failed to send"
- Check phone number format: `whatsapp:+1234567890`
- Ensure your number is in the sandbox
- Check Twilio console for error details

---

## Pricing

### Twilio
- **Sandbox**: Free (while testing)
- **Production**: $0.0083 per message (approximately $0.25 per 30 messages)
- First $15 free

### WhatsApp Business API
- Direct WhatsApp rates
- Conversation-based pricing
- Typically more expensive for high volume
- But better for customer engagement

---

## Advanced Features

### Send with Images
```python
notifier = WhatsAppNotifier()
await notifier.initialize()
await notifier.send_message(
    "Check this out!",
    media_url="https://example.com/image.jpg"
)
```

### Template Messages (Pre-approved)
```python
await notifier.send_template_message(
    "reminder_alert",
    parameters=["Event Name", "10:00 AM"]
)
```

---

## Security Best Practices

1. **Never commit credentials** to git
2. **Use .env file** for all secrets
3. **Rotate tokens** periodically  
4. **Use environment-specific** credentials
5. **Monitor API usage** for abuse
6. **Keep Twilio/Meta SDK updated**

---

## Monitoring & Logging

Add logging to your script:

```python
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

logger.info("Sending WhatsApp message...")
success = await notifier.send_message(message)
logger.info(f"Message sent: {success}")
```

---

## Next Steps

1. Choose Twilio (quick) or Business API (enterprise)
2. Set up credentials
3. Update `.env` file
4. Install dependencies
5. Test manually: `python3 send_events_to_whatsapp.py`
6. Set up cron for daily digest
7. Monitor for any issues

---

## Support Resources

- **Twilio Docs**: https://www.twilio.com/docs/whatsapp
- **WhatsApp Business API**: https://developers.facebook.com/docs/whatsapp/cloud-api/
- **API Reference**: https://www.twilio.com/docs/sms/whatsapp/api
