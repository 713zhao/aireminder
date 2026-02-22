#!/usr/bin/env python3
"""
Check which reminders should show on Feb 22 and why
"""

import asyncio
from datetime import datetime, timezone
from firebase_config import initialize_firebase
from reminders_service import get_reminders_for_date

async def main():
    initialize_firebase()
    
    user_id = "0502@hotmail.com"
    date_str = "2026-02-22"
    
    reminders = await get_reminders_for_date(
        user_id=user_id,
        date_str=date_str,
        include_completed=False,
        format_for_llm=False
    )
    
    print("Reminders matching Feb 22, 2026:")
    print("=" * 80)
    
    for i, r in enumerate(reminders, 1):
        title = r.get('title', 'Untitled')
        due = r.get('dueAt', 'N/A')
        recurrence = r.get('recurrence', 'none')
        recurrence_end = r.get('recurrenceEnd', 'N/A')
        owner = r.get('ownerId', 'Unknown')
        
        print(f"\n{i}. {title}")
        print(f"   Owner: {owner}")
        print(f"   Due: {due}")
        print(f"   Recurrence: {recurrence}")
        print(f"   Recurrence End: {recurrence_end}")

asyncio.run(main())
