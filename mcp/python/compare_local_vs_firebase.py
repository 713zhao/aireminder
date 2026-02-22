#!/usr/bin/env python3
"""
Compare local backup with Firestore and identify reminders not synced yet
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
        print("[OK] Firebase initialized\n")
        
        user_id = os.getenv("USER_ID", "0502@hotmail.com")
        
        # Load local backup
        backup_file = r"C:\Users\uidc1098\Downloads\aireminder_backup_2026-02-22T14-54-51.json"
        print(f"[*] Loading local backup from: {backup_file}")
        
        with open(backup_file, 'r') as f:
            local_data = json.load(f)
        
        local_tasks = local_data.get('tasks', [])
        print(f"[OK] Loaded {len(local_tasks)} local tasks\n")
        
        # Filter local tasks for the current user
        user_local_tasks = [t for t in local_tasks if t.get('ownerId') == user_id]
        print(f"[FILTER] Tasks owned by {user_id}: {len(user_local_tasks)}")
        print("=" * 80)
        
        # Get Firebase tasks
        db = get_firestore()
        firebase_tasks = []
        
        print("\n[*] Fetching tasks from Firestore...")
        docs = db.collection("shared_tasks").stream()
        for doc in docs:
            firebase_tasks.append(doc.to_dict())
        
        print(f"[OK] Found {len(firebase_tasks)} total tasks in Firestore\n")
        
        # Create sets of task IDs for comparison
        firebase_ids = set(t.get('id') for t in firebase_tasks if t.get('id'))
        firebase_titles = set(t.get('title', '').lower() for t in firebase_tasks)
        
        print("=" * 80)
        print("[COMPARISON] Local vs Firebase")
        print("=" * 80)
        
        not_in_firebase = []
        
        for task in user_local_tasks:
            task_id = task.get('id')
            title = task.get('title', 'Untitled')
            due = task.get('dueAt', 'N/A')
            recurrence = task.get('recurrence', 'none')
            
            # Check if this task is in Firebase (by ID or title)
            in_firebase = task_id in firebase_ids or title.lower() in firebase_titles
            
            if not in_firebase:
                not_in_firebase.append(task)
                print(f"\n[NOT SYNCED] {title}")
                print(f"  ID: {task_id}")
                print(f"  Due: {due}")
                print(f"  Recurrence: {recurrence}")
                print(f"  Weekly Days: {task.get('weeklyDays')}")
                print(f"  Shared: {task.get('isShared')}")
            else:
                print(f"\n[✓ SYNCED] {title}")
        
        print("\n" + "=" * 80)
        print(f"\n[SUMMARY]")
        print(f"  Total local tasks for {user_id}: {len(user_local_tasks)}")
        print(f"  Already in Firestore: {len(user_local_tasks) - len(not_in_firebase)}")
        print(f"  NOT synced yet: {len(not_in_firebase)}")
        
        if not_in_firebase:
            print("\n[TASKS TO SYNC]")
            print("-" * 80)
            for i, task in enumerate(not_in_firebase, 1):
                print(f"{i}. {task.get('title', 'Untitled')}")
                print(f"   ID: {task.get('id')}")
                print(f"   Due: {task.get('dueAt')}")
        
        print("\n" + "=" * 80)
        print("\n[HOW TO SYNC]")
        print("-" * 80)
        sync_guide = """
The MCP server can help sync these tasks. You have two options:

OPTION 1: Manual Sync from Flutter App
  1. Open the Flutter app
  2. Login with 0502@hotmail.com (if not already logged in)
  3. Ensure you have internet connection
  4. Go to Settings > Sync or Backup
  5. Manually trigger sync to Firestore
  6. Check Settings > Import/Export to see sync status

OPTION 2: Upload via Import Function (if available)
  1. The Flutter app has an import feature
  2. You could export the backup and re-import it
  3. During import, select "Sync to Firestore" option

OPTION 3: Direct Firebase Upload (Advanced)
  1. Use the mcp_server_lite.py API to create reminders
  2. Or manually add to Firestore console

Once synced, the MCP server will automatically return all 3 reminders 
for Feb 22, 2026.
        """
        try:
            print(sync_guide)
        except UnicodeEncodeError:
            print("See sync guide above")
        print("=" * 80)
        
    except Exception as e:
        print(f"[ERROR] {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
