#!/usr/bin/env python3
"""
Debug test to find reminders for today (Feb 22, 2026)
"""

import sys
import asyncio
from datetime import datetime, date
from dotenv import load_dotenv
import os

sys.path.insert(0, '.')

from firebase_config import initialize_firebase, get_firestore
import reminders_service as service

load_dotenv()

async def main():
    try:
        print("[*] Initializing Firebase...")
        initialize_firebase()
        print("[OK] Firebase initialized\n")
        
        user_id = os.getenv("USER_ID", "test@example.com")
        print(f"[USER] Testing for user: {user_id}\n")
        
        db = get_firestore()
        
        # Test date
        today = date.today()  # Feb 22, 2026
        print(f"[DATE] Today is: {today} (Python date object)\n")
        print("=" * 70)
        
        # Step 1: Query Firestore directly for all shared tasks
        print("\n[STEP 1] Querying Firestore directly for ALL shared tasks...")
        print("-" * 70)
        
        try:
            all_shared = db.collection("shared_tasks").where(
                "sharedWith", "array_contains", user_id
            ).stream()
            
            all_shared_list = []
            for doc in all_shared:
                data = doc.to_dict()
                all_shared_list.append({
                    "id": doc.id,
                    **data
                })
            
            print(f"Found {len(all_shared_list)} total shared reminders\n")
            
            for i, r in enumerate(all_shared_list[:10], 1):  # Show first 10
                title = r.get("title", "Untitled")
                due = r.get("dueAt")
                owner = r.get("ownerId")
                print(f"{i}. {title}")
                print(f"   Owner: {owner}")
                print(f"   Due (raw): {due}")
                print(f"   Type: {type(due)}")
                print()
        
        except Exception as e:
            print(f"[ERROR] {e}\n")
        
        # Step 2: Test date matching logic
        print("\n[STEP 2] Testing date matching logic...")
        print("-" * 70)
        
        # Function to check if two dates are the same day
        def is_same_day(dt1, dt2):
            """Check if two datetimes are on the same day"""
            if isinstance(dt1, str):
                try:
                    dt1 = datetime.fromisoformat(dt1.replace("Z", "+00:00"))
                except (ValueError, AttributeError):
                    return False
            
            if not isinstance(dt1, datetime) or not isinstance(dt2, datetime):
                return False
            
            return (
                dt1.year == dt2.year
                and dt1.month == dt2.month
                and dt1.day == dt2.day
            )
        
        target_datetime = datetime.combine(today, datetime.min.time())
        print(f"Target datetime: {target_datetime}")
        print(f"Target date: year={today.year}, month={today.month}, day={today.day}\n")
        
        # Filter shared tasks to today
        today_shared = []
        for r in all_shared_list:
            due = r.get("dueAt")
            title = r.get("title")
            
            matches = is_same_day(due, target_datetime)
            
            if matches:
                today_shared.append(r)
                print(f"[MATCH] {title}")
                print(f"        Due: {due}")
                print()
        
        print(f"\nFiltered to today: {len(today_shared)} reminders")
        
        # Step 3: Call the service function directly
        print("\n[STEP 3] Calling get_reminders_for_date() function...")
        print("-" * 70)
        
        try:
            today_str = today.isoformat()
            print(f"Calling with date: {today_str}\n")
            
            result = await service.get_reminders_for_date(
                user_id=user_id,
                date_str=today_str,
                include_completed=False,
                format_for_llm=False
            )
            
            print(f"Result: {len(result)} reminders for today\n")
            
            if result:
                for i, r in enumerate(result, 1):
                    title = r.get("title")
                    owner = r.get("ownerId")
                    is_own = owner == user_id
                    source = "OWN" if is_own else "SHARED"
                    print(f"{i}. [{source}] {title}")
                    print(f"   Owner: {owner}\n")
            else:
                print("No reminders returned!\n")
                
        except Exception as e:
            print(f"[ERROR] {e}\n")
            import traceback
            traceback.print_exc()
        
        # Step 4: Look specifically for the 3 reminders
        print("\n[STEP 4] Searching for the 3 known reminders...")
        print("-" * 70)
        
        target_titles = ["beichen football", "Hellen Nafa drawing 2026", "Hellen Gymnastic Training"]
        
        for target in target_titles:
            found = False
            for r in all_shared_list:
                title = r.get("title", "").lower()
                if target.lower() in title:
                    found = True
                    due = r.get("dueAt")
                    is_today = is_same_day(due, target_datetime)
                    
                    print(f"Found: {r.get('title')}")
                    print(f"  Due: {due}")
                    print(f"  Is today (Feb 22): {is_today}")
                    print()
                    break
            
            if not found:
                print(f"NOT FOUND in Firestore: {target}\n")
        
        print("=" * 70)
        print("[DONE] Debug completed!")
        
    except Exception as e:
        print(f"[FATAL] {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
