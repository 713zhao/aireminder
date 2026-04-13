#!/usr/bin/env python3
"""
Manual trigger for daily summary notifications
This script can be run independently to send daily summaries via Telegram
without requiring Firebase connection
"""

import asyncio
import sys
import os
from datetime import datetime
from typing import Optional, List, Dict

# Add to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from telegram_notifier import TelegramNotifier
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

async def format_sample_reminders() -> str:
    """Format sample reminders for demonstration"""
    message = "📅 **Good Morning! Today's Reminders Summary:**\n\n"
    
    # In production, this would fetch from Firebase
    # For now, showing the structure
    sample_reminders = [
        {"title": "Team Standup", "dueAt": "10:00 AM"},
        {"title": "Project Review", "dueAt": "2:00 PM"},
        {"title": "Client Call", "dueAt": "4:30 PM"},
    ]
    
    if not sample_reminders:
        message = "📅 Good morning! You have no reminders for today."
    else:
        for i, reminder in enumerate(sample_reminders, 1):
            title = reminder.get("title", "Untitled")
            due_at = reminder.get("dueAt", "No time")
            message += f"{i}. **{title}**\n   ⏰ {due_at}\n"
    
    return message

async def send_daily_summary() -> bool:
    """Send daily summary via Telegram"""
    print("=" * 60)
    print("Daily Summary Trigger")
    print("=" * 60)
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    try:
        # Initialize Telegram notifier
        print("\n1. Initializing Telegram notifier...")
        telegram_notifier = TelegramNotifier()
        await telegram_notifier.initialize()
        print("   ✓ Telegram notifier initialized")
        
        # Format the summary message
        print("\n2. Formatting daily summary...")
        message = await format_sample_reminders()
        print("   ✓ Summary prepared")
        print(f"\nMessage preview:\n{message}")
        
        # Send message
        print("\n3. Sending daily summary via Telegram...")
        success = await telegram_notifier.send_message(message)
        
        if success:
            print("   ✓ Daily summary sent successfully!")
            print("\n" + "=" * 60)
            print("✓ SUCCESS: Daily summary delivered to Telegram")
            print("=" * 60)
            return True
        else:
            print("   ✗ Failed to send message")
            return False
            
    except Exception as e:
        print(f"\n✗ Error: {e}")
        print("\nTroubleshooting:")
        print("  1. Verify TELEGRAM_BOT_TOKEN in .env is correct")
        print("  2. Verify TELEGRAM_CHAT_ID in .env is correct")
        print("  3. Check that the Telegram bot is still active")
        return False

async def main():
    """Main entry point"""
    success = await send_daily_summary()
    return 0 if success else 1

if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
