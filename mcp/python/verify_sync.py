#!/usr/bin/env python3
import sys
from firebase_config import initialize_firebase, get_firestore

initialize_firebase()
db = get_firestore()

user_id = '0502@hotmail.com'

# Get owned reminders
own_docs = db.collection('shared_tasks').where('ownerId', '==', user_id).stream()
own_reminders = [doc.to_dict() for doc in own_docs]

# Get shared reminders
shared_docs = db.collection('shared_tasks').where('sharedWith', 'array_contains', user_id).stream()
shared_reminders = [doc.to_dict() for doc in shared_docs]

print(f"For user {user_id}:")
print(f"Owned: {len(own_reminders)}")
print(f"Shared: {len(shared_reminders)}")
print()
print("Owned reminders (first 5):")
for r in own_reminders[:5]:
    print(f"  - {r.get('title')}")

print()
print("Shared reminders (first 5):")
for r in shared_reminders[:5]:
    print(f"  - {r.get('title')}")
