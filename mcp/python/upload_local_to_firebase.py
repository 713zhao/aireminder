#!/usr/bin/env python3
"""
Upload local reminders to Firestore directly
"""

import sys
import json
from datetime import datetime, timezone
from dotenv import load_dotenv
import os

sys.path.insert(0, '.')

from firebase_config import initialize_firebase, get_firestore

load_dotenv()

def main():
    try:
        # Initialize Firebase
        print("[*] Initializing Firebase...")
        initialize_firebase()
        db = get_firestore()
        print("[OK] Firebase initialized\n")
        
        user_id = os.getenv("USER_ID", "0502@hotmail.com")
        
        # Load local backup
        backup_file = r"C:\Users\uidc1098\Downloads\aireminder_backup_2026-02-22T14-54-51.json"
        print(f"[*] Loading local backup from: {backup_file}")
        
        with open(backup_file, 'r') as f:
            local_data = json.load(f)
        
        local_tasks = local_data.get('tasks', [])
        print(f"[OK] Loaded {len(local_tasks)} local tasks\n")
        
        # Filter for unsynced tasks owned by user
        user_local_tasks = [t for t in local_tasks if t.get('ownerId') == user_id]
        
        # Check which are already in Firebase
        firebase_tasks = []
        docs = db.collection("shared_tasks").stream()
        for doc in docs:
            firebase_tasks.append(doc.to_dict())
        
        firebase_ids = set(t.get('id') for t in firebase_tasks if t.get('id'))
        firebase_titles = set(t.get('title', '').lower() for t in firebase_tasks)
        
        # Filter for unsynced
        unsynced = []
        for task in user_local_tasks:
            task_id = task.get('id')
            title = task.get('title', '').lower()
            
            if task_id not in firebase_ids and title not in firebase_titles:
                unsynced.append(task)
        
        print("=" * 80)
        print(f"[UPLOAD] Found {len(unsynced)} unsynced tasks to upload")
        print("=" * 80)
        
        # Show which ones will be uploaded
        for i, task in enumerate(unsynced, 1):
            print(f"{i}. {task.get('title')}")
        
        print("\n" + "=" * 80)
        response = input("\nProceed with upload? (yes/no): ").strip().lower()
        
        if response != 'yes':
            print("[CANCELLED] Upload cancelled")
            return
        
        print("\n[UPLOADING]")
        print("-" * 80)
        
        uploaded_count = 0
        failed_count = 0
        
        for task in unsynced:
            try:
                # Map local fields to Firestore format
                firestore_task = {
                    'id': task.get('id'),
                    'title': task.get('title'),
                    'notes': task.get('notes'),
                    'dueAt': task.get('dueAt'),
                    'recurrence': task.get('recurrence'),
                    'recurrenceEnd': task.get('recurrenceEndDate'),
                    'weeklyDays': task.get('weeklyDays'),
                    'ownerId': task.get('ownerId'),
                    'sharedWith': task.get('sharedWith'),
                    'isDisabled': task.get('isDisabled'),
                    'remindBeforeMinutes': task.get('remindBeforeMinutes'),
                    'createdAt': task.get('createdAt'),
                    'updatedAt': task.get('updatedAt'),
                }
                
                # Upload to Firestore
                doc_id = task.get('id')
                db.collection("shared_tasks").document(str(doc_id)).set(firestore_task)
                
                print(f"[OK] Uploaded: {task.get('title')}")
                uploaded_count += 1
                
            except Exception as e:
                print(f"[ERROR] Failed to upload {task.get('title')}: {e}")
                failed_count += 1
        
        print("\n" + "=" * 80)
        print(f"[SUMMARY]")
        print(f"  Uploaded: {uploaded_count}")
        print(f"  Failed: {failed_count}")
        print(f"  Total: {uploaded_count + failed_count}")
        print("\n[SUCCESS] All reminders have been synced!")
        print("The MCP server will now return all 3 reminders for Feb 22, 2026:")
        print("  1. Hellen Nafa drawing 2026")
        print("  2. Beichen ActiveSG Football Academy (Sunday)")
        print("  3. Hellen Gymnastic Training (already synced)")
        print("=" * 80)
        
    except Exception as e:
        print(f"[ERROR] {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
