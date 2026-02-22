#!/usr/bin/env python3
"""
List all reminders owned by burnlm@hotmail.com
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
        
        db = get_firestore()
        
        owner = "burnlm@hotmail.com"
        print(f"[QUERY] All reminders OWNED by {owner}...")
        print("=" * 70)
        
        docs = db.collection("shared_tasks").where("ownerId", "==", owner).stream()
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
        
        print("=" * 70)
        print(f"[RESULT] Total reminders owned by {owner}: {count}")
        
        # Now search for the missing ones
        print("\n[SEARCH] Looking for missing reminders...")
        print("=" * 70)
        
        search_titles = ["beichen football", "Hellen Nafa drawing 2026"]
        
        for search_title in search_titles:
            print(f"\n[SEARCHING] '{search_title}'...")
            docs = db.collection("shared_tasks").stream()
            found = False
            for doc in docs:
                data = doc.to_dict()
                title = data.get('title', '').lower()
                if search_title.lower() in title:
                    print(f"  [FOUND] {data.get('title')}")
                    print(f"    Owner: {data.get('ownerId')}")
                    print(f"    Due: {data.get('dueAt')}")
                    print(f"    Recurrence: {data.get('recurrence', 'none')}")
                    print(f"    Shared with: {data.get('sharedWith', [])}")
                    found = True
            
            if not found:
                print(f"  NOT FOUND in any collection")
        
    except Exception as e:
        print(f"[ERROR] {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
