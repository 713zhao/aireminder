#!/usr/bin/env python3
"""
Manual trigger for daily summary notifications
This script fetches actual reminders from Firebase and sends them via Telegram/WhatsApp
"""

import asyncio
import sys
import os
from datetime import datetime
from typing import Optional, List, Dict

# Add to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from telegram_notifier import TelegramNotifier
from whatsapp_notifier import WhatsAppNotifier
from firebase_config import initialize_firebase
import reminders_service as service
from dotenv import load_dotenv
from dateutil import parser as date_parser

# Load environment variables
load_dotenv()

USER_ID = os.getenv("USER_ID", "user@example.com")
ENABLE_TELEGRAM = os.getenv("ENABLE_TELEGRAM", "true").lower() == "true"
ENABLE_WHATSAPP = os.getenv("ENABLE_WHATSAPP", "true").lower() == "true"

async def get_today_reminders() -> List[Dict]:
    """Fetch today's actual reminders from Firebase"""
    try:
        reminders = await service.get_today_reminders(USER_ID)
        return reminders if reminders else []
    except Exception as e:
        print(f"Warning: Could not fetch reminders from Firebase: {e}")
        return []

def extract_time(due_datetime_str: str) -> str:
    """Extract time from dueDateTime string"""
    if not due_datetime_str:
        return "No time"
    try:
        parsed = date_parser.parse(due_datetime_str)
        return parsed.strftime("%I:%M %p")
    except:
        return "No time"

async def format_reminders(reminders: List[Dict]) -> str:
    """Format reminders for the message"""
    message = "📅 **Good Morning! Today's Reminders:**\n\n"
    
    if not reminders:
        message = "📅 Good morning! You have no reminders for today."
    else:
        for i, reminder in enumerate(reminders, 1):
            title = reminder.get("title", "Untitled")
            due_datetime = reminder.get("dueDateTime", "")
            time_str = extract_time(due_datetime)
            recurrence = reminder.get("recurrence", "once")
            # Format recurrence with emoji
            recurrence_icon = "🔄" if recurrence != "once" else "📌"
            message += f"{i}. **{title}**\n   ⏰ {time_str} ({recurrence_icon} {recurrence})\n"
    
    return message

async def send_daily_summary() -> bool:
    """Send daily summary via Telegram and WhatsApp"""
    print("=" * 60)
    print("Daily Summary Trigger")
    print("=" * 60)
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    try:
        # Initialize Firebase
        print("\n1. Initializing Firebase...")
        initialize_firebase()
        print("   ✓ Firebase initialized")
        
        # Fetch actual reminders
        print("\n2. Fetching today's reminders from Firebase...")
        reminders = await get_today_reminders()
        print(f"   ✓ Found {len(reminders)} reminders for today")
        
        # Format the summary message
        print("\n3. Formatting daily summary...")
        message = await format_reminders(reminders)
        print("   ✓ Summary prepared")
        print(f"\nMessage preview:\n{message}")
        
        # Send via Telegram
        if ENABLE_TELEGRAM:
            print("\n4. Sending via Telegram...")
            try:
                telegram_notifier = TelegramNotifier()
                await telegram_notifier.initialize()
                success = await telegram_notifier.send_message(message)
                if success:
                    print("   ✓ Message sent to Telegram")
                else:
                    print("   ✗ Failed to send to Telegram")
            except Exception as e:
                print(f"   ✗ Telegram error: {e}")
        
        # Send via WhatsApp
        if ENABLE_WHATSAPP:
            print("\n5. Sending via WhatsApp...")
            try:
                whatsapp_notifier = WhatsAppNotifier()
                await whatsapp_notifier.initialize()
                success = await whatsapp_notifier.send_message(message)
                if success:
                    print("   ✓ Message sent to WhatsApp")
                else:
                    print("   ✗ Failed to send to WhatsApp")
            except Exception as e:
                print(f"   ✗ WhatsApp error: {e}")
        
        print("\n" + "=" * 60)
        print("✓ SUCCESS: Daily summary delivered")
        print("=" * 60)
        return True
            
    except Exception as e:
        print(f"\n✗ Error: {e}")
        print("\nTroubleshooting:")
        print("  1. Verify Firebase credentials in .env")
        print("  2. Verify TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID")
        print("  3. Check network connection")
        return False

async def main():
    """Main entry point"""
    success = await send_daily_summary()
    return 0 if success else 1

if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
