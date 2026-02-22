#!/usr/bin/env python3
"""
Test script to show all reminders (own + shared) including overdue
Demonstrates that the shared reminders functionality is working correctly
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
    """Test function to show all reminders including shared"""
    try:
        # Initialize Firebase
        print("[*] Initializing Firebase...")
        initialize_firebase()
        print("[OK] Firebase initialized\n")
        
        # Get user ID from environment
        user_id = os.getenv("USER_ID", "test@example.com")
        print(f"[USER] Testing for user: {user_id}\n")
        print("=" * 70)
        
        # Test: Get ALL reminders (own + shared)
        print("\n[TEST] GETTING ALL REMINDERS (own + shared, including overdue)")
        print("-" * 70)
        try:
            # Get own reminders
            print("\n[FETCH] Fetching own reminders...")
            own_reminders = await service.get_all_reminders(
                user_id=user_id,
                status="all",
                format_for_llm=False
            )
            print(f"   [OK] Found {len(own_reminders)} own reminders")
            
            # Get shared reminders
            print("\n[FETCH] Fetching shared reminders...")
            shared_reminders = await service.get_shared_reminders(
                user_id=user_id,
                format_for_llm=False
            )
            print(f"   [OK] Found {len(shared_reminders)} shared reminders")
            
            # Combine and display
            all_reminders = own_reminders + shared_reminders
            print(f"\n{'Merged Total:':20} {len(all_reminders)} reminders")
            print("\n" + "=" * 70)
            print("REMINDERS LIST:")
            print("-" * 70)
            
            if all_reminders:
                own_list = []
                shared_list = []
                
                for reminder in all_reminders:
                    if reminder.get("ownerId") == user_id:
                        own_list.append(reminder)
                    else:
                        shared_list.append(reminder)
                
                # Display own reminders
                if own_list:
                    print(f"\n[OWN] YOUR OWN REMINDERS ({len(own_list)}):")
                    print("-" * 70)
                    for i, r in enumerate(own_list, 1):
                        status = "DONE" if r.get("isCompleted") else "TODO"
                        title = r.get("title", "Untitled")
                        due = r.get("dueAt", "No date")
                        
                        print(f"{i}. [{status}] {title}")
                        print(f"   Date: {due}")
                        if r.get("recurrence"):
                            print(f"   [REPEAT] {r.get('recurrence')}")
                        if r.get("notes"):
                            print(f"   Notes: {r.get('notes')[:50]}...")
                        print()
                
                # Display shared reminders
                if shared_list:
                    print(f"\n[SHARED] SHARED WITH YOU ({len(shared_list)}):")
                    print("-" * 70)
                    for i, r in enumerate(shared_list, 1):
                        status = "DONE" if r.get("isCompleted") else "TODO"
                        title = r.get("title", "Untitled")
                        owner = r.get("ownerId", "Unknown")
                        due = r.get("dueAt", "No date")
                        
                        print(f"{i}. [{status}] {title}")
                        print(f"   From: {owner}")
                        print(f"   Date: {due}")
                        if r.get("recurrence"):
                            print(f"   [REPEAT] {r.get('recurrence')}")
                        print()
            else:
                print("[INFO] No reminders found")
            
            print("\n" + "=" * 70)
            print("[SUCCESS] Test completed successfully!")
            print("\n[SUMMARY] Key findings:")
            print(f"   * Own reminders: {len(own_reminders)}")
            print(f"   * Shared with you: {len(shared_reminders)}")
            print(f"   * Total visible: {len(all_reminders)}")
            
        except Exception as e:
            print(f"[ERROR] {e}")
            import traceback
            traceback.print_exc()
        
    except Exception as e:
        print(f"[FATAL] {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
