import sys
sys.path.insert(0, '.')
from firebase_config import get_firestore
from dotenv import load_dotenv
import os

load_dotenv()
user_id = os.getenv('USER_ID')

db = get_firestore()

print(f'Checking tasks for USER_ID: {user_id}\n')

# Query shared_tasks for this user
docs = db.collection('shared_tasks').where('ownerId', '==', user_id).limit(10).stream()

count = 0
for doc in docs:
    count += 1
    data = doc.to_dict()
    title = data.get("title")
    due = data.get("dueAt")
    owner = data.get("ownerId")
    print(f'{count}. {title} - Due: {due}')

if count == 0:
    print(f'No tasks found for {user_id}')
    print('\n--- Possible owners in database ---')
    all_docs = db.collection('shared_tasks').limit(15).stream() 
    owners = set()
    for doc in all_docs:
        owner = doc.to_dict().get('ownerId')
        if owner:
            owners.add(owner)
    for owner in sorted(owners):
        print(f'  - {owner}')
