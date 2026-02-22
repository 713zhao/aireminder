#!/usr/bin/env python3
"""
Detailed test to see which reminders match Feb 22, 2026
"""

import sys
import asyncio
from datetime import datetime, date
from dotenv import load_dotenv
import os

sys.path.insert(0, '.')

from firebase_config import initialize_firebase
import reminders_service as service

load_dotenv()

async def main():
    try:
        print("[*] Initializing Firebase...")
        initialize_firebase()
        print("[OK] Firebase initialized\n")
        
        user_id = os.getenv("USER_ID", "test@example.com")
        print(f"[USER] Testing for user: {user_id}\n")
        print("=" * 70)
        
        # Get all reminders (own + shared)
        print("\n[STEP 1] Fetching all reminders...")
        print("-" * 70)
        
        own = await service.get_all_reminders(user_id, status="all", format_for_llm=False)
        shared = await service.get_shared_reminders(user_id, format_for_llm=False)
        all_reminders = own + shared
        
        print(f"Own: {len(own)}")
        print(f"Shared: {len(shared)}")
        print(f"Total: {len(all_reminders)}\n")
        
        # Test date: Feb 22, 2026 (Sunday)
        test_date = date(2026, 2, 22)
        test_datetime = datetime(2026, 2, 22)
        
        print(f"[TEST DATE] {test_date.isoformat()} (Weekday: {test_datetime.strftime('%A')})")
        print()
        
        # Check each reminder to see if it matches
        print("[STEP 2] Checking each reminder against Feb 22, 2026...")
        print("-" * 70)
        
        matches = []
        for i, reminder in enumerate(all_reminders, 1):
            title = reminder.get("title", "Untitled")
            due_at = reminder.get("dueAt")
            recurrence = reminder.get("recurrence", "none")
            owner = reminder.get("ownerId")
            
            # Check if it matches Feb 22
            from reminders_service import _matches_on_date
            matches_date = _matches_on_date(reminder, test_datetime)
            
            if matches_date:
                matches.append(reminder)
                print(f"[MATCH] {i}. {title}")
                print(f"        Due: {due_at}")
                print(f"        Recurrence: {recurrence}")
                print(f"        Owner: {owner}\n")
            else:
                # Show why it doesn't match
                print(f"[NO MATCH] {i}. {title}")
                print(f"           Due: {due_at}")
                print(f"           Recurrence: {recurrence}")
                
                # Debug why
                if recurrence and recurrence.lower() == "weekly":
                    from reminders_service import _normalize_date_to_midnight
                    due = _normalize_date_to_midnight(due_at)
                    if due:
                        due_weekday = due.isoweekday()  # Monday=1, Sunday=7
                        test_weekday = test_datetime.isoweekday()
                        print(f"           Due weekday: {due_weekday} ({['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][due_weekday-1]})")
                        print(f"           Test weekday: {test_weekday} ({['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][test_weekday-1]})")
                print()
        
        print(f"\n[RESULT] {len(matches)} reminders match Feb 22, 2026:")
        for r in matches:
            print(f"  - {r.get('title')}")
        
        print("\n[EXPECTED] Based on user's statement, should have 3 reminders:")
        print("  1. beichen football")
        print("  2. Hellen Nafa drawing 2026")
        print("  3. Hellen Gymnastic Training")
        
        print("\n" + "=" * 70)
        
    except Exception as e:
        print(f"[ERROR] {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
