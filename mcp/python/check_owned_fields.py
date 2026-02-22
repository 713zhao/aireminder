#!/usr/bin/env python3
"""
Check the uploaded owned reminders to see their structure
"""

import sys
from firebase_config import initialize_firebase, get_firestore

initialize_firebase()
db = get_firestore()

user_id = "0502@hotmail.com"

print(f"[CHECKING] Owned reminders for {user_id}")
print("=" * 80)

docs = db.collection("shared_tasks").where("ownerId", "==", user_id).stream()

for i, doc in enumerate(docs, 1):
    data = doc.to_dict()
    if i <= 5:  # Show first 5
        print(f"\n{i}. {data.get('title', 'Untitled')}")
        print(f"   isCompleted: {data.get('isCompleted')}")
        print(f"   isDisabled: {data.get('isDisabled')}")
        print(f"   dueAt: {data.get('dueAt')}")
        print(f"   recurrence: {data.get('recurrence')}")
        print(f"   weeklyDays: {data.get('weeklyDays')}")

# Now check what fields the shared reminders have
print("\n" + "=" * 80)
print(f"[CHECKING] Shared reminders")
print("=" * 80)

shared_docs = db.collection("shared_tasks").where("sharedWith", "array_contains", user_id).stream()

for i, doc in enumerate(shared_docs, 1):
    data = doc.to_dict()
    if i <= 3:  # Show first 3
        print(f"\n{i}. {data.get('title', 'Untitled')}")
        print(f"   isCompleted: {data.get('isCompleted')}")
        print(f"   isDisabled: {data.get('isDisabled')}")
        print(f"   dueAt: {data.get('dueAt')}")
        print(f"   recurrence: {data.get('recurrence')}")
