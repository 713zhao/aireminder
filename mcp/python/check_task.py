#!/usr/bin/env python3
"""Check a specific task in Firebase"""

import sys
sys.path.insert(0, '/home/anythingllm/aireminder/mcp/python')

import asyncio
from firebase_config import get_firestore
from reminders_service import get_reminder_by_id

async def main():
    task_id = "1771765574048000"
    user_id = "0502@hotmail.com"
    
    # Try to get the task from Firebase
    task = await get_reminder_by_id(user_id, task_id)
    
    if task:
        print(f"Task found: {task_id}")
        print(f"Title: {task.get('title')}")
        print(f"DueAt: {task.get('dueAt')}")
        print(f"Recurrence: {task.get('recurrence')}")
        print(f"IsCompleted: {task.get('isCompleted')}")
        print(f"OwnerId: {task.get('ownerId')}")
        print(f"Full task: {task}")
    else:
        print(f"Task {task_id} not found")

if __name__ == "__main__":
    asyncio.run(main())
