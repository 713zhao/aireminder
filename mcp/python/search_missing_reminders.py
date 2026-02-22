#!/usr/bin/env python3
"""
Search Firestore directly for the missing reminders
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
        
        user_id = os.getenv("USER_ID", "test@example.com")
        print(f"[USER] User ID: {user_id}\n")
        print("=" * 70)
        
        db = get_firestore()
        
        # Search for "beichen football"
        print("\n[SEARCH] Looking for 'beichen football'...")
        print("-" * 70)
        
        docs = db.collection("shared_tasks").where("title", "==", "beichen football").stream()
        count = 0
        for doc in docs:
            count += 1
            data = doc.to_dict()
            print(f"Found: {data.get('title')}")
            print(f"  Owner: {data.get('ownerId')}")
            print(f"  Shared with: {data.get('sharedWith')}")
            print(f"  Due: {data.get('dueAt')}")
            print()
        
        if count == 0:
            print("NOT FOUND in shared_tasks")
        
        # Search for "Hellen Nafa drawing"
        print("\n[SEARCH] Looking for 'Hellen Nafa drawing'...")
        print("-" * 70)
        
        docs = db.collection("shared_tasks").where("title", "==", "Hellen Nafa drawing 2026").stream()
        count = 0
        for doc in docs:
            count += 1
            data = doc.to_dict()
            print(f"Found: {data.get('title')}")
            print(f"  Owner: {data.get('ownerId')}")
            print(f"  Shared with: {data.get('sharedWith')}")
            print(f"  Due: {data.get('dueAt')}")
            print()
        
        if count == 0:
            print("NOT FOUND in shared_tasks")
        
        # Search with substring
        print("\n[SEARCH] Searching for all tasks (limit 20)...")
        print("-" * 70)
        
        docs = db.collection("shared_tasks").limit(20).stream()
        for i, doc in enumerate(docs, 1):
            data = doc.to_dict()
            title = data.get('title', 'Untitled')
            owner = data.get('ownerId', 'Unknown')
            shared_with = data.get('sharedWith', [])
            
            # Check if user appears
            user_appears = (owner == user_id or user_id in shared_with)
            marker = " <--" if user_appears else ""
            
            print(f"{i}. {title}")
            print(f"   Owner: {owner}")
            print(f"   Shared with: {shared_with}{marker}")
            print()
        
        print("=" * 70)
        
    except Exception as e:
        print(f"[ERROR] {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
