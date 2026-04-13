#!/usr/bin/env python3
"""
Send all TODAY events (own + shared) to Telegram
"""

import os
import asyncio
from datetime import datetime
from dotenv import load_dotenv
from reminders_service import get_today_reminders, get_shared_reminders
from telegram_notifier import TelegramNotifier

load_dotenv()


def _parse_datetime(date_str):
    """Parse a datetime string and return datetime object"""
    if not date_str:
        return None
    
    try:
        return datetime.strptime(date_str, "%b %d, %Y %I:%M %p")
    except ValueError:
        pass
    
    try:
        return datetime.fromisoformat(date_str.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        pass
    
    return None


def _extract_time(date_str):
    """Extract just the time from a datetime string"""
    dt = _parse_datetime(date_str)
    if not dt:
        return None
    
    return dt.strftime("%I:%M %p")


def _format_today_with_time(date_str):
    """Format today's date with the time from the datetime string"""
    today = datetime.now()
    time_str = _extract_time(date_str)
    
    if not time_str:
        return None
    
    formatted_date = today.strftime("%b %d, %Y")
    return f"{formatted_date} {time_str}"


async def send_today_events():
    """Fetch today's events (own + shared) and send to Telegram"""
    
    print("=" * 70)
    print("Fetching Today's Events and Sending to Telegram")
    print("=" * 70)
    
    user_id = os.getenv("USER_ID")
    print(f"\nUser ID: {user_id}")
    
    try:
        print("\n1. Fetching your events for today...")
        today_reminders = await get_today_reminders(user_id, format_for_llm=False)
        
        # Format times for user's own events
        for reminder in today_reminders:
            due_at = reminder.get("dueAt") or reminder.get("dueDateTime", "")
            if due_at and not reminder.get("dueDateTime"):
                reminder['dueDateTime'] = _format_today_with_time(due_at)
        
        print(f"   ✓ Found {len(today_reminders)} of your events for today")
        
        print("\n2. Fetching shared reminders...")
        all_shared = await get_shared_reminders(user_id, format_for_llm=False)
        
        today_shared = []
        today_date = datetime.now()
        today_weekday = today_date.isoweekday()
        
        for reminder in all_shared:
            due_at = reminder.get("dueAt", "")
            recurrence = (reminder.get("recurrence") or "").lower()
            weekly_days = reminder.get("weeklyDays", [])
            
            matches_today = False
            
            if not due_at:
                continue
            
            due_date = _parse_datetime(due_at)
            if not due_date:
                continue
            
            due_weekday = due_date.isoweekday()
            
            if not recurrence or recurrence == "none":
                if due_date.date() == today_date.date():
                    matches_today = True
            
            elif recurrence == "daily":
                if today_date.date() >= due_date.date():
                    matches_today = True
            
            elif recurrence == "weekly":
                if weekly_days and today_weekday in weekly_days:
                    if today_date.date() >= due_date.date():
                        matches_today = True
                elif not weekly_days and today_weekday == due_weekday:
                    if today_date.date() >= due_date.date():
                        matches_today = True
            
            if matches_today:
                reminder['dueDateTime'] = _format_today_with_time(due_at)
                today_shared.append(reminder)
        
        print(f"   ✓ Found {len(today_shared)} shared events for today")
        
        # Merge reminders and deduplicate by title + time + owner
        all_reminders = today_reminders + today_shared
        seen_events = set()
        unique_reminders = []
        
        for reminder in all_reminders:
            title = reminder.get("title", "")
            due_time = reminder.get("dueDateTime", "")
            owner = reminder.get("ownerId", user_id)
            event_key = (title, due_time, owner)
            
            if event_key not in seen_events and due_time:
                seen_events.add(event_key)
                unique_reminders.append(reminder)
        
        # Sort by time
        unique_reminders.sort(key=lambda r: r.get("dueDateTime", ""))
        
        if not unique_reminders:
            message = f"📅 **Today's Events ({user_id}):**\n\nNo reminders for today."
        else:
            message = f"📅 **Today's Events ({user_id}):**\n\n"
            
            for i, reminder in enumerate(unique_reminders, 1):
                title = reminder.get("title", "Untitled")
                notes = reminder.get("notes", "")
                due_date_time = reminder.get("dueDateTime", "Unknown time")
                recurrence = reminder.get("recurrence", "none")
                
                status_emoji = "✅" if reminder.get("isCompleted") else "⏳"
                
                message += f"{i}. {status_emoji} **{title}**\n"
                
                if notes:
                    message += f"   📝 {notes}\n"
                message += f"   ⏰ {due_date_time}\n"
                if recurrence != "none":
                    message += f"   🔄 Recurring: {recurrence}\n"
                message += "\n"
        
        print("\n3. Initializing Telegram bot...")
        
        notifier = TelegramNotifier()
        await notifier.initialize()
        print("   ✓ Bot initialized")
        
        print("\n4. Sending to Telegram...")
        success = await notifier.send_message(message)
        
        if success:
            print("   ✓ Message sent successfully!")
            print("\n" + "=" * 70)
            print("✓ SUCCESS: Today's events sent to Telegram")
            print("=" * 70)
            return True
        else:
            print("   ✗ Failed to send message")
            return False
            
    except Exception as e:
        print(f"   ✗ Error: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    asyncio.run(send_today_events())
