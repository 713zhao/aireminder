#!/usr/bin/env python3
import json
from datetime import datetime, timezone

backup_file = r"C:\Users\uidc1098\Downloads\aireminder_backup_2026-02-22T14-54-51.json"

with open(backup_file, 'r') as f:
    data = json.load(f)

target_date = datetime(2026, 2, 22, 0, 0, 0, tzinfo=timezone.utc)

print("=" * 80)
print("Reminders containing 'nafa', 'beichen', or 'football':")
print("=" * 80)

for task in data.get('tasks', []):
    title = task.get('title', '')
    if any(x in title.lower() for x in ['nafa', 'beichen', 'football']):
        print(f"\nTitle: {title}")
        print(f"  Due: {task.get('dueAt')}")
        print(f"  Recurrence: {task.get('recurrence')}")
        print(f"  Weekly Days: {task.get('weeklyDays')}")
        print(f"  Owner: {task.get('ownerId')}")
        print(f"  Shared With: {task.get('sharedWith')}")
        print(f"  Recurrence End: {task.get('recurrenceEndDate')}")
