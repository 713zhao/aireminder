#!/usr/bin/env python3
"""
Check ALL reminders in Firestore and calculate which ones repeat on Feb 22, 2026
"""

import sys
from datetime import datetime, timezone
from dotenv import load_dotenv
import os

sys.path.insert(0, '.')

from firebase_config import initialize_firebase, get_firestore

load_dotenv()

def normalize_date_to_midnight(dt):
    """Normalize a datetime to midnight UTC"""
    if isinstance(dt, str):
        # Parse ISO format string
        if 'T' in dt:
            dt = datetime.fromisoformat(dt.replace('Z', '+00:00'))
        else:
            dt = datetime.fromisoformat(dt)
    
    if isinstance(dt, datetime):
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.replace(hour=0, minute=0, second=0, microsecond=0)
    
    return None

def matches_on_date(reminder: dict, target_date: datetime) -> bool:
    """Check if reminder matches target date using flutter algorithm"""
    
    due_at = reminder.get('dueAt')
    if not due_at:
        return False
    
    # Normalize dates
    due = normalize_date_to_midnight(due_at)
    target = normalize_date_to_midnight(target_date)
    
    if not due:
        return False
    
    # Check if target >= due
    if target < due:
        return False
    
    # Check recurrence end date
    recurrence_end = reminder.get('recurrenceEnd')
    if recurrence_end:
        end_date = normalize_date_to_midnight(recurrence_end)
        if end_date and target > end_date:
            return False
    
    # No recurrence
    recurrence = reminder.get('recurrence') or 'none'
    if isinstance(recurrence, str):
        recurrence = recurrence.lower()
    else:
        recurrence = 'none'
    
    if recurrence == 'none':
        return target == due
    
    # Daily
    if recurrence == 'daily':
        return True
    
    # Weekly
    if recurrence == 'weekly':
        weekly_days = reminder.get('weeklyDays', [])
        target_weekday = target.isoweekday()  # Mon=1, Sun=7
        
        if not weekly_days:
            # No days specified, use due date's weekday
            due_weekday = due.isoweekday()
            return target_weekday == due_weekday
        else:
            return target_weekday in weekly_days
    
    # Monthly
    if recurrence == 'monthly':
        return target.day == due.day
    
    # Yearly
    if recurrence == 'yearly':
        return target.month == due.month and target.day == due.day
    
    return False

def main():
    try:
        print("[*] Initializing Firebase...")
        initialize_firebase()
        print("[OK] Firebase initialized\n")
        
        db = get_firestore()
        
        target_date = datetime(2026, 2, 22, 0, 0, 0, tzinfo=timezone.utc)
        target_weekday = target_date.isoweekday()
        
        print("=" * 80)
        print(f"[TARGET DATE] 2026-02-22 (Weekday: {['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][target_weekday-1]})")
        print("=" * 80)
        
        # Get ALL reminders
        print("\n[QUERY] Fetching ALL reminders from Firestore...")
        docs = db.collection("shared_tasks").stream()
        all_reminders = []
        for doc in docs:
            all_reminders.append(doc.to_dict())
        
        print(f"[RESULT] Found {len(all_reminders)} total reminders\n")
        
        # Check each reminder
        matching = []
        non_matching = []
        
        print("[ANALYSIS] Checking each reminder against Feb 22, 2026...")
        print("-" * 80)
        
        for i, reminder in enumerate(all_reminders, 1):
            title = reminder.get('title', 'Untitled')
            due = reminder.get('dueAt', 'N/A')
            recurrence = reminder.get('recurrence', 'none')
            owner = reminder.get('ownerId', 'Unknown')
            shared_with = reminder.get('sharedWith', [])
            
            matches = matches_on_date(reminder, target_date)
            
            if matches:
                matching.append(reminder)
                print(f"\n[MATCH] {i}. {title}")
                print(f"  Owner: {owner}")
                print(f"  Shared with: {shared_with}")
                print(f"  Due: {due}")
                print(f"  Recurrence: {recurrence}")
                if recurrence == 'weekly':
                    print(f"  Weekly days: {reminder.get('weeklyDays', [])}")
            else:
                non_matching.append(reminder)
        
        print("\n" + "=" * 80)
        print(f"\n[SUMMARY] Feb 22, 2026 Reminders:")
        print(f"  Total reminders in database: {len(all_reminders)}")
        print(f"  Matching Feb 22: {len(matching)}")
        print(f"  Not matching: {len(non_matching)}")
        
        print("\n[MATCHING REMINDERS FOR FEB 22, 2026]")
        print("-" * 80)
        for i, reminder in enumerate(matching, 1):
            print(f"{i}. {reminder.get('title', 'Untitled')}")
            print(f"   Owner: {reminder.get('ownerId')}")
            print(f"   Recurrence: {reminder.get('recurrence', 'none')}")
        
        print("\n" + "=" * 80)
        print("\nSearching for the 3 expected reminders:")
        print("-" * 80)
        
        expected = [
            "beichen football",
            "Hellen Nafa drawing 2026",
            "Hellen Gymnastic Training"
        ]
        
        for expected_title in expected:
            found = None
            for reminder in all_reminders:
                if expected_title.lower() in reminder.get('title', '').lower():
                    found = reminder
                    break
            
            if found:
                matches = matches_on_date(found, target_date)
                status = "✓ FOUND & MATCHES" if matches else "✗ FOUND BUT DOESN'T MATCH"
                print(f"  {expected_title}: {status}")
                if found:
                    print(f"    Owner: {found.get('ownerId')}")
                    print(f"    Due: {found.get('dueAt')}")
                    print(f"    Recurrence: {found.get('recurrence', 'none')}")
            else:
                print(f"  {expected_title}: ✗ NOT FOUND IN DATABASE")
        
        print("\n" + "=" * 80)
        
    except Exception as e:
        print(f"[ERROR] {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
