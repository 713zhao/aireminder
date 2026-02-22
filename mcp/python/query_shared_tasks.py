#!/usr/bin/env python3
import sys
sys.path.insert(0, '.')
from firebase_config import get_firestore
from datetime import datetime, date
import json

db = get_firestore()

# Get today's date range
today = date.today()
today_start = datetime.combine(today, datetime.min.time()).isoformat() + '.000'
today_end = datetime.combine(today, datetime.max.time()).isoformat() + '.000'

print(f'Looking for tasks due today: {today}')
print(f'Date range: {today_start} to {today_end}\n')

# Query shared_tasks with dueAt between today's range
docs = db.collection('shared_tasks').where('dueAt', '>=', today_start).where('dueAt', '<=', today_end).limit(5).stream()

count = 0
for doc in docs:
    count += 1
    data = doc.to_dict()
    title = data.get("title")
    owner = data.get("ownerId")
    due = data.get("dueAt")
    completed = data.get("isCompleted")
    deleted = data.get("deleted")
    print(f'Document {count} (ID: {doc.id}):')
    print(f'  Title: {title}')
    print(f'  Owner: {owner}')
    print(f'  Due: {due}')
    print(f'  Completed: {completed}')
    print(f'  Deleted: {deleted}')
    print()

if count == 0:
    print('No tasks found for today')
    print('\n--- Checking ALL non-deleted tasks ---')
    all_docs = db.collection('shared_tasks').where('deleted', '==', False).limit(5).stream()
    for i, doc in enumerate(all_docs, 1):
        data = doc.to_dict()
        title = data.get("title")
        owner = data.get("ownerId")
        due = data.get("dueAt")
        print(f'Task {i}: {title} - Due: {due} - Owner: {owner}')
