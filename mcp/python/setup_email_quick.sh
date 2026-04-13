#!/bin/bash
# Quick Email Setup Helper

echo "==========================================="
echo "aireminder Email Quick Setup"
echo "==========================================="
echo ""
echo "This script will help you configure email notifications."
echo ""
echo "Step 1: Get your Gmail App Password"
echo "  1. Visit: https://myaccount.google.com/apppasswords"
echo "  2. Select 'Mail' and 'Windows Computer'"
echo "  3. Copy the 16-character password"
echo ""
read -p "Enter your sender email address (e.g., your-email@gmail.com): " sender_email
read -sp "Enter your Gmail App Password (16 characters with spaces): " sender_password
echo ""

# Backup .env
cp .env .env.backup
echo "✓ Backup created: .env.backup"

# Add email config to .env if not exists
if ! grep -q "^ENABLE_EMAIL=" .env; then
    echo "" >> .env
    echo "# Email Configuration" >> .env
    echo "ENABLE_EMAIL=true" >> .env
fi

# Update or add SENDER_EMAIL
if grep -q "^SENDER_EMAIL=" .env; then
    sed -i "s|^SENDER_EMAIL=.*|SENDER_EMAIL=$sender_email|" .env
else
    echo "SENDER_EMAIL=$sender_email" >> .env
fi

# Update or add SENDER_PASSWORD
if grep -q "^SENDER_PASSWORD=" .env; then
    sed -i "s|^SENDER_PASSWORD=.*|SENDER_PASSWORD=$sender_password|" .env
else
    echo "SENDER_PASSWORD=$sender_password" >> .env
fi

echo ""
echo "✓ Email configuration updated!"
echo ""
echo "Step 2: Test email configuration"
echo "  Run: python3 test_email_notifier.py"
echo ""
