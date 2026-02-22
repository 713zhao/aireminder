#!/usr/bin/env python3
"""
Test script for get_today_reminders() with shared reminders support
This verifies that the function correctly includes both own and shared reminders
"""

import sys
import asyncio
from datetime import datetime
from dotenv import load_dotenv
import os

sys.path.insert(0, '.')

from firebase_config import initialize_firebase
import reminders_service as service

load_dotenv()

async def main():
    """Test get_today_reminders with shared reminders"""
    try:
        # Initialize Firebase
        print("🔧 Initializing Firebase...")
        initialize_firebase()
        print("✓ Firebase initialized\n")
        
        # Get user ID from environment
        user_id = os.getenv("USER_ID", "test@example.com")
        print(f"📧 Testing for user: {user_id}\n")
        print("=" * 60)
        
        # Test 1: Get today's reminders (own + shared, pending only)
        print("\n1️⃣  GETTING TODAY'S REMINDERS (pending only)")
        print("-" * 60)
        try:
            today_reminders = await service.get_today_reminders(
                user_id=user_id,
                include_completed=False,
                format_for_llm=False
            )
            
            print(f"Found {len(today_reminders)} reminders for today:\n")
            
            if today_reminders:
                own_count = 0
                shared_count = 0
                
                for i, reminder in enumerate(today_reminders, 1):
                    is_own = reminder.get("ownerId") == user_id
                    source = "OWN" if is_own else f"SHARED (from {reminder.get('ownerId')})"
                    
                    if is_own:
                        own_count += 1
                    else:
                        shared_count += 1
                    
                    title = reminder.get("title", "Untitled")
                    due_at = reminder.get("dueAt", "No date")
                    completed = "❌" if reminder.get("isCompleted") else "✓"
                    
                    print(f"{i}. [{source}] {completed} {title}")
                    print(f"   Due: {due_at}")
                    if reminder.get("notes"):
                        print(f"   Notes: {reminder.get('notes')}")
                    print()
                
                print("-" * 60)
                print(f"Summary: {own_count} own | {shared_count} shared = {len(today_reminders)} total")
            else:
                print("⚠️  No reminders found for today")
            
        except Exception as e:
            print(f"❌ Error: {e}")
        
        # Test 2: Get today's reminders (including completed)
        print("\n\n2️⃣  GETTING TODAY'S REMINDERS (including completed)")
        print("-" * 60)
        try:
            all_reminders = await service.get_today_reminders(
                user_id=user_id,
                include_completed=True,
                format_for_llm=False
            )
            
            print(f"Found {len(all_reminders)} reminders (including completed):\n")
            
            if all_reminders:
                completed_count = sum(1 for r in all_reminders if r.get("isCompleted"))
                pending_count = len(all_reminders) - completed_count
                
                print(f"Completed: {completed_count} | Pending: {pending_count}")
            else:
                print("⚠️  No reminders found")
                
        except Exception as e:
            print(f"❌ Error: {e}")
        
        # Test 3: Test the new get_reminders_for_date function
        print("\n\n3️⃣  TESTING get_reminders_for_date() with specific date")
        print("-" * 60)
        try:
            today_str = datetime.now().strftime("%Y-%m-%d")
            print(f"Fetching reminders for: {today_str}\n")
            
            date_reminders = await service.get_reminders_for_date(
                user_id=user_id,
                date_str=today_str,
                include_completed=False,
                format_for_llm=False
            )
            
            print(f"Found {len(date_reminders)} reminders for {today_str}:\n")
            
            if date_reminders:
                for i, reminder in enumerate(date_reminders, 1):
                    is_own = reminder.get("ownerId") == user_id
                    source = "OWN" if is_own else "SHARED"
                    title = reminder.get("title", "Untitled")
                    due_at = reminder.get("dueAt", "No date")
                    
                    print(f"{i}. [{source}] {title}")
                    print(f"   Due: {due_at}\n")
            else:
                print("⚠️  No reminders found for this date")
                
        except Exception as e:
            print(f"❌ Error: {e}")
        
        # Test 4: Get reminders summary
        print("\n\n4️⃣  REMINDERS SUMMARY (all own + shared)")
        print("-" * 60)
        try:
            summary = await service.get_reminders_summary(user_id)
            
            print(f"Total reminders: {summary['total']}")
            print(f"  ✓ Pending: {summary['pending']}")
            print(f"  ❌ Completed: {summary['completed']}")
            print(f"  ⏰ Due today: {summary['dueToday']}")
            print(f"  📈 Upcoming: {summary['upcoming']}")
            print(f"  🔴 Overdue: {summary['overdue']}")
            print(f"  📊 Completion rate: {summary['completionRate']}%")
            
        except Exception as e:
            print(f"❌ Error: {e}")
        
        print("\n" + "=" * 60)
        print("✅ Test completed!")
        
    except Exception as e:
        print(f"❌ Fatal error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
