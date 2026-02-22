#!/usr/bin/env python3
"""
Show all reminders owned by user 0502@hotmail.com
"""

import sys
from dotenv import load_dotenv
import os

sys.path.insert(0, '.')

from firebase_config import initialize_firebase, get_firestore

load_dotenv()

def main():
    try:
        print("[*] Initializing Firebase...")
        initialize_firebase()
        print("[OK] Firebase initialized\n")
        
        user_id = os.getenv("USER_ID", "0502@hotmail.com")
        print(f"[USER] User ID: {user_id}\n")
        print("=" * 70)
        
        db = get_firestore()
        
        # Get all reminders OWNED by this user
        print(f"\n[QUERY] All reminders OWNED by {user_id}...")
        print("-" * 70)
        
        docs = db.collection("shared_tasks").where("ownerId", "==", user_id).stream()
        count = 0
        for doc in docs:
            count += 1
            data = doc.to_dict()
            title = data.get('title', 'Untitled')
            due = data.get('dueAt', 'N/A')
            recurrence = data.get('recurrence', 'none')
            shared = data.get('sharedWith', [])
            
            print(f"{count}. {title}")
            print(f"   Due: {due}")
            print(f"   Recurrence: {recurrence}")
            print(f"   Shared with: {shared}")
            print()
        
        if count == 0:
            print("*** NO REMINDERS OWNED BY THIS USER ***")
        else:
            print(f"[RESULT] Total owned: {count}")
        
        print("\n" + "=" * 70)
        
    except Exception as e:
        print(f"[ERROR] {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
