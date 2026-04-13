# Email Notification Setup Guide

## Overview
The aireminder notification system now supports email notifications alongside Telegram and WhatsApp. This guide walks you through setting up email notifications.

## Quick Start

### 1. Get Gmail App Password
For Gmail users (recommended):

1. Go to https://myaccount.google.com/apppasswords
2. Select "Mail" and "Windows Computer" (or your device)
3. Google will generate a 16-character password
4. Copy this password - you'll need it in the next step

**Important:** This is an "App Password", not your regular Gmail password!

### 2. Update .env File
Add the following to your `./mcp/python/.env` file:

```env
# Email Configuration
ENABLE_EMAIL=true
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SENDER_EMAIL=your-email@gmail.com
SENDER_PASSWORD=xxxx xxxx xxxx xxxx
```

Replace:
- `your-email@gmail.com` with your actual Gmail address
- `xxxx xxxx xxxx xxxx` with the App Password from step 1

### 3. Test Email Configuration
Run the test script:

```bash
python3 test_email_notifier.py
```

Expected output:
```
============================================================
Email Notifier Test
============================================================

1. Checking Email Configuration:
   Sender Email: your-email@gmail.com
   Recipient Email: 0502@hotmail.com
   SMTP Server: smtp.gmail.com
   SMTP Port: 587

2. Initializing Email Notifier...
   ✓ Notifier initialized

3. Sending Test Email...
   ✓ Test email sent successfully!

============================================================
✓ Email Notification System is Ready
============================================================
```

## Configuration for Other Email Providers

### Outlook (Hotmail)
```env
SMTP_SERVER=smtp-mail.outlook.com
SMTP_PORT=587
SENDER_EMAIL=your-email@outlook.com
SENDER_PASSWORD=your-password
```

### Yahoo
```env
SMTP_SERVER=smtp.mail.yahoo.com
SMTP_PORT=587
SENDER_EMAIL=your-email@yahoo.com
SENDER_PASSWORD=your-app-password
```

### Custom SMTP Server
```env
SMTP_SERVER=smtp.your-provider.com
SMTP_PORT=587
SENDER_EMAIL=your-email@example.com
SENDER_PASSWORD=your-password
```

## Security Best Practices

1. **Never commit .env file** - Keep it in .gitignore
2. **Use App Passwords** - Don't use your actual email password
3. **Protect .env file** - Set restrictive file permissions
4. **Rotate passwords** - Change app passwords periodically

## Troubleshooting

### "Authentication failed" Error
- Double-check your SENDER_EMAIL matches the email account
- Verify you copied the full App Password correctly
- For Gmail: Make sure you generated an "App Password", not a regular password

### "Connection refused" Error
- Check SMTP_SERVER and SMTP_PORT are correct
- Verify your firewall/internet is not blocking SMTP
- Try port 465 instead of 587 (usually for SSL)

### "Email not received" Error
- Check if email went to spam folder
- Verify SENDER_EMAIL and recipient email are correct
- Check system logs for more details

## Recipient Email Configuration

The recipient email is automatically set to your `USER_ID` from .env:
```env
USER_ID=0502@hotmail.com
```

This is where all email notifications will be sent.

## Testing Different Scenarios

### Send a Simple Test
```bash
python3 test_email_notifier.py
```

### Verify in Notification Scheduler
Once configured, email notifications will be sent automatically with:
- Daily summary emails at the configured time
- Pre-event reminder emails 15 minutes before events

## Integration with Notification Scheduler

The email notifier is automatically integrated with the notification scheduler. To enable email notifications in the scheduler:

1. Ensure ENABLE_EMAIL is set to true in .env
2. Configure SENDER_EMAIL and SENDER_PASSWORD
3. Run the scheduler as usual: `python3 notification_scheduler.py`

The scheduler will send emails for:
- Morning summaries
- Pre-event reminders

## Verification Checklist

- [ ] Gmail App Password generated (if using Gmail)
- [ ] SENDER_EMAIL added to .env
- [ ] SENDER_PASSWORD added to .env
- [ ] test_email_notifier.py runs successfully
- [ ] Test email received in inbox
- [ ] ENABLE_EMAIL set to true (optional, for auto-scheduler)

## Next Steps

Once email is configured:

1. `python3 test_email_notifier.py` - Verify email works
2. `python3 verify_setup.py` - Full system verification
3. `python3 notification_scheduler.py` - Start auto-scheduler with email support

