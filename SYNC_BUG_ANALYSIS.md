# Flutter Sync Bug Analysis

## Root Cause Identified

The Flutter app and MCP server use **different storage paths** for reminders:

### Flutter App (firestore_sync.dart)
```dart
// Line 658-675: pushTask() method
// 1. OWNED tasks go to user collection:
final col = _fs!.collection('users').doc(uid).collection('tasks');
await col.doc(t.id).set(taskData, ...);

// 2. SHARED tasks ALSO go to shared_tasks collection:
if (t.isShared && t.sharedWith != null && t.sharedWith!.isNotEmpty) {
  final sharedTasksCol = _fs!.collection('shared_tasks');
  await sharedTasksCol.doc(t.id).set(taskData, ...);
}
```

### MCP Server (reminders_service.py)
```python
# Only queries 'shared_tasks' collection for everything:
db.collection("shared_tasks").where("ownerId", "==", user_id)
```

## The Problem

**27 local reminders were NOT synced to Firebase because:**

1. ✗ Non-shared reminders stay in `users/{uid}/tasks/{taskId}` (not synced to shared_tasks)
2. ✓ Only reminders marked as `isShared=true` get pushed to `shared_tasks` collection
3. ✗ MCP server only queries `shared_tasks`, missing all non-shared owned reminders
4. ✗ When we uploaded via script, we uploaded directly to `shared_tasks` (bypassing the user collection path)

## Storage Architecture

```
Firestore Structure:
├── users/{uid}/tasks/{taskId}          ← Owned non-shared reminders (NOT synced by script)
├── shared_tasks/{taskId}                ← Only tasks where isShared=true
└── sharing_index/{email}/shared_tasks/  ← Index for finding shared reminders
```

## Why Sync Failed

The Flutter app's `box.watch()` listener triggers whenever a local task changes:
1. **Condition check** (line 101-108): Only pushes if `_auth?.currentUser != null`
   - ✗ If user is NOT logged in, tasks won't sync
   - ✓ If user IS logged in, tasks should sync

2. **For non-shared tasks** (line 685): Only save to `users/{uid}/tasks/`
   - ✗ Does NOT automatically push to `shared_tasks`
   - ✗ MCP server can't find them

3. **For shared tasks** (line 676-690): Also save to `shared_tasks`
   - ✓ This works correctly
   - ✓ Sharing index is updated

## Why Upload Script Worked

When we ran `upload_local_to_firebase.py`:
- Directly wrote to `shared_tasks` collection
- Bypassed the `users/{uid}/tasks/` path entirely
- 27 reminders were uploaded to the "wrong" collection
- But the MCP server could find them because it queries `shared_tasks`

## Solutions

### Option 1: Fix Flutter App (Recommended)
Auto-sync owned tasks to `shared_tasks` collection:

```dart
// After line 675, add:
else {
  // Even non-shared tasks should sync to shared_tasks for better visibility
  final sharedTasksCol = _fs!.collection('shared_tasks');
  await sharedTasksCol.doc(t.id).set(taskData, firestore.SetOptions(merge: true));
}
```

**Pros:**
- Centralizes all reminders in one collection
- Works with existing MCP server
- Simpler Firestore structure

**Cons:**
- Changes app architecture
- Migration needed for existing uploaded reminders

### Option 2: Fix MCP Server (Quick Fix)
Query both `users/{uid}/tasks/` AND `shared_tasks`:

```python
# In get_all_reminders(), add:
# Get owned reminders from user collection
user_col = db.collection('users').where('uid', '==', user_id).stream()
own_reminders = []
for user_doc in user_col:
    tasks = db.collection('users').document(user_doc.id).collection('tasks').stream()
    own_reminders.extend([doc.to_dict() for doc in tasks])

# Get shared reminders (already done)
shared_reminders = db.collection('shared_tasks').where('sharedWith', 'array_contains', user_id).stream()
```

**Pros:**
- No changes to Flutter app
- Backward compatible
- Quick fix

**Cons:**
- More complex querying
- Performance impact with more reads
- Need to maintain two code paths

### Option 3: Fix Both (Best Practice)
1. **Update Flutter app** to always push to `shared_tasks`
2. **Migrate existing data** in `users/{uid}/tasks/` to `shared_tasks`
3. **Simplify MCP** to only query `shared_tasks`

## Why Login Matters

The sync listener (line 141-160) only activates when:
1. `_auth?.currentUser != null` (user is logged in)
2. There's a watch event on the local tasks_box

**If not logged in:**
- Local changes won't trigger sync
- No `_startListening()` call
- Tasks stay local

## Recommendation

**Implement Option 2 (Quick fix) first** to get sync working:
- Add query for `users/{uid}/tasks/` collection in MCP server
- No changes to Flutter app required
- Existing reminders work immediately
- Can migrate to cleaner architecture later

Then **implement Option 1** long-term:
- Update Flutter app to sync all tasks to `shared_tasks`
- Simpler, more maintainable structure
