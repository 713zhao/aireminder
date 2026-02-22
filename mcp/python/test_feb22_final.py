#!/usr/bin/env python3
"""
Final verification: Test get_reminders_for_date for Feb 22, 2026 with user 0502@hotmail.com
"""

import sys
import asyncio
from firebase_config import initialize_firebase

sys.path.insert(0, '.')
from reminders_service import get_reminders_for_date

async def main():
    initialize_firebase()
    
    user_id = "0502@hotmail.com"
    date_str = "2026-02-22"
    
    print("=" * 80)
    print(f"[TEST] Fetching reminders for {user_id} on {date_str}")
    print("=" * 80)
    
    try:
        reminders = await get_reminders_for_date(
            user_id=user_id,
            date_str=date_str,
            include_completed=False,
            format_for_llm=False
        )
        
        print(f"\n[RESULT] Found {len(reminders)} reminders for Feb 22, 2026\n")
        
        for i, r in enumerate(reminders, 1):
            title = r.get('title', 'Untitled')
            owner = r.get('ownerId', 'Unknown')
            shared = r.get('sharedWith', [])
            print(f"{i}. {title}")
            print(f"   Owner: {owner}")
            print(f"   Shared: {shared}")
            print()
        
        # Check for the expected ones
        titles = [r.get('title', '').lower() for r in reminders]
        
        print("=" * 80)
        print("[VERIFICATION]")
        print("-" * 80)
        
        expected = [
            ("Hellen Nafa drawing 2026", "hellen nafa drawing"),
            ("Beichen ActiveSG Football", "beichen"),
            ("Hellen Gymnastic Training", "gymnastic")
        ]
        
        for name, search_key in expected:
            found = any(search_key.lower() in t for t in titles)
            status = "✓ FOUND" if found else "✗ NOT FOUND"
            print(f"  {name}: {status}")
        
        print("=" * 80)
        
    except Exception as e:
        print(f"[ERROR] {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
