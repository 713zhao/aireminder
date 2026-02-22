#!/usr/bin/env python3
"""
Fix script to add missing 'id' fields to existing tasks in Firestore shared_tasks collection.

This script was created to fix tasks that were created by MCP but are missing the 'id' field.
The issue was that doc.add() would save the document without the Firestore document ID as a field.

Usage:
    python fix_missing_task_ids.py

This will:
1. Query all documents in shared_tasks collection
2. For each document missing an 'id' field, add the Firestore doc.id as the field
3. Print progress and summary
"""

import os
import sys
from firebase_config import initialize_firebase, get_firestore
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def fix_missing_task_ids():
    """
    Add missing 'id' field to tasks in Firestore.
    """
    try:
        db = get_firestore()
        collection = db.collection("shared_tasks")
        
        print("Scanning shared_tasks collection for missing 'id' fields...")
        print("-" * 60)
        
        docs = collection.stream()
        fixed_count = 0
        total_count = 0
        already_has_id = 0
        
        for doc in docs:
            total_count += 1
            data = doc.to_dict()
            doc_id = doc.id
            
            # Check if document is missing the 'id' field
            if "id" not in data or data.get("id") is None:
                print(f"Fixing task: {doc_id}")
                print(f"  Owner: {data.get('ownerId', 'N/A')}")
                print(f"  Title: {data.get('title', 'N/A')}")
                
                # Add the id field
                doc.reference.update({"id": doc_id})
                fixed_count += 1
                print(f"  ✓ Fixed")
            else:
                already_has_id += 1
        
        print("-" * 60)
        print(f"Total documents scanned: {total_count}")
        print(f"Documents fixed: {fixed_count}")
        print(f"Documents already had id: {already_has_id}")
        
        if fixed_count > 0:
            print(f"\n✓ Successfully fixed {fixed_count} tasks!")
        else:
            print("\n✓ No tasks needed fixing - all are OK!")
            
    except Exception as error:
        print(f"✗ Error: {str(error)}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    fix_missing_task_ids()
