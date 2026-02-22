# AI Reminder MCP Server - Node.js Version

A fast, lightweight MCP (Model Context Protocol) server for accessing AI Reminder events from Firestore.

**Fast startup** (~100ms) with minimal memory footprint (~50MB) - perfect for CLI integration with OpenClaw.

## Quick Start

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Firebase

Create `.env` file:

```bash
cp .env.example .env
```

Edit `.env` with your Firebase credentials:

```env
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\nMIIEv...\n-----END PRIVATE KEY-----\n
FIREBASE_CLIENT_EMAIL=your-service-account@your-project.iam.gserviceaccount.com
USER_ID=your-email@example.com
DEBUG=false
```

#### Get Firebase Credentials

1. [Firebase Console](https://console.firebase.google.com/) → Your Project
2. ⚙️ Settings → Service Accounts → Generate New Private Key
3. Copy `project_id`, `private_key`, `client_email`

### 3. Run the Server

```bash
npm start
```

The server communicates via stdin/stdout (MCP protocol).

## Architecture

```
OpenClaw / Claude
      ↓ (MCP protocol via stdio)
MCP Server (mcp-server.js)
      ↓ (Firebase SDK)
Firestore Database
```

## Available Tools & Resources

### Read-Only Resources (6)
- `reminders://list/{userId}` - All reminders
- `reminders://upcoming/{userId}/7` - Next 7 days
- `reminders://today/{userId}` - Today's reminders
- `reminders://overdue/{userId}` - Overdue items
- `reminders://summary/{userId}` - Statistics
- `reminders://shared/{userId}` - Shared with me

### Query Tools (8)
1. `list_reminders` - Get all reminders with filters
2. `get_upcoming_reminders` - Reminders for next N days
3. `get_today_reminders` - Today's reminders
4. `get_overdue_reminders` - Overdue items
5. `get_reminder_details` - Single reminder by ID
6. `search_reminders` - Search by title/notes
7. `get_reminders_summary` - Statistics
8. `get_shared_reminders` - Items shared with user

### Mutation Tools (4)
9. `add_reminder` - Create new reminder
10. `edit_reminder` - Update existing reminder
11. `delete_reminder` - Delete reminder (soft delete)
12. `complete_reminder` - Mark as completed

## Configuration in OpenClaw

### Option 1: Direct StdIO (Recommended)

Edit your OpenClaw configuration:

```json
{
  "mcp": {
    "servers": {
      "aireminder": {
        "command": "node",
        "args": ["C:\\Projects\\AI\\aireminder\\functions\\nodejs\\mcp-server.js"],
        "env": {
          "FIREBASE_PROJECT_ID": "your-firebase-project",
          "FIREBASE_PRIVATE_KEY": "your-private-key-with-\\n",
          "FIREBASE_CLIENT_EMAIL": "your-service-account@...iam.gserviceaccount.com",
          "USER_ID": "your-email@example.com",
          "DEBUG": "false"
        }
      }
    }
  }
}
```

### Option 2: Environment Variables

```powershell
$env:FIREBASE_PROJECT_ID = "your-project-id"
$env:FIREBASE_PRIVATE_KEY = "your-private-key-with-\n"
$env:FIREBASE_CLIENT_EMAIL = "your-service-account@..."
$env:USER_ID = "your-email@example.com"

npm start
```

### Option 3: Docker

```dockerfile
FROM node:18-slim
WORKDIR /app
COPY . .
RUN npm install
CMD ["npm", "start"]
```

```bash
docker build -t aireminder-mcp .
docker run -e FIREBASE_PROJECT_ID="..." aireminder-mcp
```

## Tool Examples

### List upcoming reminders
```json
{
  "name": "get_upcoming_reminders",
  "arguments": {
    "days": 7,
    "sortBy": "priority"
  }
}
```

### Add a reminder
```json
{
  "name": "add_reminder",
  "arguments": {
    "title": "Buy groceries",
    "notes": "Milk, eggs, bread",
    "dueAt": "2026-02-22T18:00:00Z",
    "recurrence": "weekly",
    "weeklyDays": [1, 3, 5]
  }
}
```

### Search reminders
```json
{
  "name": "search_reminders",
  "arguments": {
    "query": "meeting",
    "status": "pending"
  }
}
```

## Troubleshooting

### Firebase Connection Error

**Error:** `Missing Firebase configuration`

**Fix:** Check `.env` has all required fields:
```bash
cat .env
# Should output: FIREBASE_PROJECT_ID, FIREBASE_PRIVATE_KEY, FIREBASE_CLIENT_EMAIL, USER_ID
```

### Private Key Format Issues

**Error:** `PARSE_ERROR` or `INVALID_X509_CERT`

**Fix:** Ensure newlines in private key use `\n` format:
```env
# Correct:
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIEv...\n-----END PRIVATE KEY-----\n"

# Wrong:
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----
MIIEv...
-----END PRIVATE KEY-----"
```

### No Reminders Returned

1. Verify `USER_ID` in `.env` matches Firestore `ownerId` field
2. Check reminders exist in Firestore with correct `ownerId`
3. Verify Firestore security rules allow read access

### Enable Debug Mode

```env
DEBUG=true
```

Server will print detailed logs to stderr.

## File Structure

```
nodejs/
├── mcp-server.js           # Main MCP server entry point
├── firebase-config.js      # Firebase initialization
├── reminders-service.js    # Business logic for queries
├── utils.js                # Helper utilities
├── package.json            # Node.js dependencies
├── .env                    # Configuration (DO NOT commit)
├── .env.example            # Configuration template
├── .gitignore              # Git ignore rules
└── README.md               # This file
```

## Reminder Data Model

Each reminder has:

```javascript
{
  id: string,                    // Unique identifier
  title: string,                 // Reminder title
  notes?: string,                // Optional notes
  status: string,                // "pending" | "completed"
  dueAt?: Date,                  // Due date/time
  dueDate: string,               // Formatted date (e.g., "Feb 22, 2026")
  dueDateTime: string,           // Formatted date+time
  daysUntil?: number,            // Days until due
  isCompleted: boolean,          // Completion status
  completedAt?: Date,            // When completed
  recurrence?: string,           // "daily" | "weekly" | "monthly" | etc
  isShared: boolean,             // Is shared with others
  sharedWith?: string[],         // Emails of shared users
  createdAt: Date,               // Creation timestamp
  isDisabled: boolean,           // Is disabled
  ownerId: string,               // Reminder owner email
}
```

## Security

1. ✅ Never commit `.env` file - it contains credentials
2. ✅ Use service account keys (not user credentials)
3. ✅ Firestore rules should validate `ownerId` and `sharedWith`
4. ✅ Credentials in environment variables or secure vaults
5. ✅ Only expose necessary reminder fields to AI

## Performance Notes

- Queries limited to authenticated user's reminders
- Results formatted for LLM use (verbose but clear)
- Firestore indexes recommended for large datasets
- Startup time: ~100ms, Memory: ~50MB

## Comparison with Python Version

| Feature | Node.js | Python |
|---------|---------|--------|
| Startup Time | ~100ms | ~500ms |
| Memory | ~50MB | ~100MB |
| Transport | StdIO (CLI) | HTTP API |
| API Docs | N/A | /docs (Swagger) |
| Best For | OpenClaw CLI | Web integration |

See [../python/README.md](../python/README.md) for Python version details.

## Next Steps

1. ✅ Install: `npm install`
2. ✅ Configure: Create `.env` with credentials
3. ✅ Test: `npm start`
4. ✅ Integrate: Add to OpenClaw config
5. ✅ Use: Talk to Claude!

---

**Questions?** Check [../MCP_SERVER_PLAN.md](../MCP_SERVER_PLAN.md) for full technical details.
