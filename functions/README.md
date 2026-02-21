# AI Reminder MCP Server Setup Guide

Welcome! This guide will help you set up and run the MCP (Model Context Protocol) server for accessing your AI Reminder events.

## Quick Start

### 1. Install Dependencies

```bash
cd c:\Projects\AI\aireminder\functions
npm install
```

### 2. Configure Firebase Credentials

Create a `.env` file in the `functions` directory:

```bash
cp .env.example .env
```

Then edit `.env` and add your Firebase credentials:

```env
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n
FIREBASE_CLIENT_EMAIL=your-service-account@your-project.iam.gserviceaccount.com
USER_ID=your-email@example.com
DEBUG=false
```

#### Getting Firebase Credentials

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Settings → Service Accounts → Generate new private key
4. Copy the JSON and extract:
   - `project_id` → FIREBASE_PROJECT_ID
   - `private_key` → FIREBASE_PRIVATE_KEY
   - `client_email` → FIREBASE_CLIENT_EMAIL

### 3. Test the Server

```bash
# Test Firebase connection and list reminders
npm start
```

If successful, you'll see the server running on stdio transport.

## Architecture

```
┌──────────────────────┐
│ OpenClaw / Claude    │
└──────────┬───────────┘
           │ stdio
┌──────────▼───────────┐
│ MCP Server           │
│ (mcp-server.js)      │
└──────────┬───────────┘
           │ Firebase SDK
┌──────────▼───────────┐
│ Firestore            │
│ reminders collection │
└──────────────────────┘
```

## Available Resources

The MCP server exposes the following **resources** (read-only data):

### 1. All Reminders
**URI:** `reminders://list/{userId}`
```json
[
  {
    "id": "reminder-id",
    "title": "Buy groceries",
    "status": "pending",
    "dueDate": "Feb 22, 2026",
    ...
  }
]
```

### 2. Upcoming Reminders (7 days)
**URI:** `reminders://upcoming/{userId}/7`

Reminders due in the next 7 days, sorted by priority.

### 3. Today's Reminders
**URI:** `reminders://today/{userId}`

All reminders due today.

### 4. Overdue Reminders
**URI:** `reminders://overdue/{userId}`

All pending reminders that are overdue.

### 5. Reminders Summary
**URI:** `reminders://summary/{userId}`

Statistics about your reminders:
```json
{
  "total": 25,
  "completed": 15,
  "pending": 10,
  "overdue": 2,
  "dueToday": 3,
  "upcoming": 8,
  "completionRate": "60.0"
}
```

### 6. Shared Reminders
**URI:** `reminders://shared/{userId}`

Reminders shared with you by other users.

## Available Tools

The MCP server provides **tools** (executable actions) for queries:

### 1. list_reminders
Get all reminders with optional filtering.

**Parameters:**
- `userId` (optional): User ID or email
- `status`: `pending` | `completed` | `all` (default: `all`)
- `limit`: Maximum results

**Example:**
```json
{
  "name": "list_reminders",
  "arguments": {
    "status": "pending",
    "limit": 10
  }
}
```

### 2. get_upcoming_reminders
Get reminders for the next N days.

**Parameters:**
- `userId` (optional): User ID or email
- `days`: Number of days to look ahead (default: 7)
- `sortBy`: `dueDate` | `priority` (default: `priority`)
- `includeCompleted`: Include completed items (default: false)

### 3. get_today_reminders
Get reminders due today.

**Parameters:**
- `userId` (optional): User ID or email
- `includeCompleted`: Include completed items (default: false)

### 4. get_overdue_reminders
Get all overdue reminders.

**Parameters:**
- `userId` (optional): User ID or email

### 5. get_reminder_details
Get detailed information about a specific reminder.

**Parameters:**
- `reminderId` (**required**): The reminder ID
- `userId` (optional): User ID or email

**Example:**
```json
{
  "name": "get_reminder_details",
  "arguments": {
    "reminderId": "reminder-123"
  }
}
```

### 6. search_reminders
Search reminders by title or notes.

**Parameters:**
- `query` (**required**): Search text
- `userId` (optional): User ID or email
- `status`: `pending` | `completed` | `all` (default: `all`)
- `limit`: Maximum results

**Example:**
```json
{
  "name": "search_reminders",
  "arguments": {
    "query": "grocery",
    "status": "pending"
  }
}
```

### 7. get_reminders_summary
Get summary statistics.

**Parameters:**
- `userId` (optional): User ID or email

### 8. get_shared_reminders
Get reminders shared with you.

**Parameters:**
- `userId` (optional): User ID or email

### 9. add_reminder
Create a new reminder.

**Parameters:**
- `title` (**required**): Reminder title
- `notes` (optional): Notes or description
- `dueAt` (optional): Due date/time in ISO format (e.g., `2026-02-22T10:00:00Z`)
- `recurrence` (optional): Recurrence pattern (`daily`, `weekly`, `monthly`, etc.)
- `remindBeforeMinutes` (optional): Minutes before due date to remind (default: 10)
- `recurrenceEndDate` (optional): End date for recurring reminders in ISO format
- `weeklyDays` (optional): Array of days for weekly recurrence (1=Monday, 7=Sunday)
- `sharedWith` (optional): Array of email addresses to share with
- `userId` (optional): User ID or email

**Example:**
```json
{
  "name": "add_reminder",
  "arguments": {
    "title": "Buy groceries",
    "notes": "Milk, eggs, bread",
    "dueAt": "2026-02-22T18:00:00Z",
    "recurrence": "weekly",
    "remindBeforeMinutes": 30,
    "weeklyDays": [1, 3, 5]
  }
}
```

### 10. edit_reminder
Update an existing reminder.

**Parameters:**
- `reminderId` (**required**): The ID of the reminder to update
- `title` (optional): New title
- `notes` (optional): Updated notes
- `dueAt` (optional): Updated due date/time
- `recurrence` (optional): Updated recurrence pattern
- `remindBeforeMinutes` (optional): Updated reminder time
- `recurrenceEndDate` (optional): Updated recurrence end date
- `weeklyDays` (optional): Updated weekly days
- `sharedWith` (optional): Updated share list
- `userId` (optional): User ID or email

**Example:**
```json
{
  "name": "edit_reminder",
  "arguments": {
    "reminderId": "reminder-123",
    "title": "Buy groceries and cook dinner",
    "dueAt": "2026-02-22T19:00:00Z"
  }
}
```

### 11. delete_reminder
Delete a reminder (soft delete - marks as deleted).

**Parameters:**
- `reminderId` (**required**): The ID of the reminder to delete
- `userId` (optional): User ID or email

**Example:**
```json
{
  "name": "delete_reminder",
  "arguments": {
    "reminderId": "reminder-123"
  }
}
```

### 12. complete_reminder
Mark a reminder as completed.

**Parameters:**
- `reminderId` (**required**): The ID of the reminder to complete
- `userId` (optional): User ID or email

**Example:**
```json
{
  "name": "complete_reminder",
  "arguments": {
    "reminderId": "reminder-123"
  }
}
```

## Configuration in OpenClaw

### Option 1: StdIO Transport (Recommended)

Edit your OpenClaw configuration file (usually in project root or `~/.openclaw/config.json`):

```json
{
  "mcp": {
    "servers": {
      "aireminder": {
        "command": "node",
        "args": ["C:\\Projects\\AI\\aireminder\\functions\\mcp-server.js"],
        "env": {
          "FIREBASE_PROJECT_ID": "your-firebase-project",
          "FIREBASE_PRIVATE_KEY": "your-private-key",
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

Set environment variables and run the server:

```powershell
$env:FIREBASE_PROJECT_ID = "your-project-id"
$env:FIREBASE_PRIVATE_KEY = "your-private-key-with-\n"
$env:FIREBASE_CLIENT_EMAIL = "your-service-account@..."
$env:USER_ID = "your-email@example.com"

node mcp-server.js
```

### Option 3: Docker Container

Create a `Dockerfile`:

```dockerfile
FROM node:18-slim

WORKDIR /app

COPY functions/ .

RUN npm install

ENV NODE_ENV=production

CMD ["node", "mcp-server.js"]
```

Build and run:

```bash
docker build -t aireminder-mcp .
docker run -e FIREBASE_PROJECT_ID="" -e FIREBASE_PRIVATE_KEY="" ... aireminder-mcp
```

## Usage Examples

### With Claude / OpenClaw

**Example 1: Get upcoming reminders**

You: "Show me my reminders for the next week"

Claude uses MCP:
```
→ tool: get_upcoming_reminders
  days: 7
  sortBy: priority
```

**Example 2: Search for a specific reminder**

You: "Do I have any reminders about the meeting?"

Claude uses MCP:
```
→ tool: search_reminders
  query: "meeting"
```

**Example 3: Get completion summary**

You: "How many reminders have I completed?"

Claude uses MCP:
```
→ tool: get_reminders_summary
```

## Troubleshooting

### Firebase Connection Error

```
Error: Missing Firebase configuration
```

**Solution:** Ensure `.env` file has all required fields:
```bash
cat .env
# Should show: FIREBASE_PROJECT_ID, FIREBASE_PRIVATE_KEY, FIREBASE_CLIENT_EMAIL, USER_ID
```

### Private Key Format Issues

If you see `PARSE_ERROR` or `INVALID_X509_CERT`, the private key format is wrong.

**Solution:** Copy the entire private key from JSON including newlines:

```bash
# From Firebase JSON:
"private_key": "-----BEGIN PRIVATE KEY-----\nMIIEv...\n-----END PRIVATE KEY-----\n"

# In .env file:
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIEv...\n-----END PRIVATE KEY-----\n"
```

### No reminders returned

**Check:**
1. Verify `USER_ID` matches your Firestore `ownerId` field
2. Ensure reminders exist in Firestore with matching `ownerId`
3. Check Firestore rules allow read access

### OpenClaw can't find the MCP server

**Solution:**
1. Verify the path to `mcp-server.js` is correct
2. Ensure Node.js is installed: `node --version`
3. Check npm packages are installed: `npm list @modelcontextprotocol/sdk`

### Enable Debug Mode

```bash
# In .env
DEBUG=true

# Or via environment
set DEBUG=true
npm start
```

This will print detailed logs to stderr.

## File Structure

```
functions/
├── mcp-server.js          # Main MCP server entry point
├── firebase-config.js     # Firebase initialization
├── reminders-service.js   # Business logic for queries
├── utils.js               # Helper utilities
├── package.json           # Node.js dependencies
├── .env                   # Configuration (DO NOT commit)
├── .env.example           # Configuration template
├── .gitignore             # Git ignore rules
└── README.md              # This file
```

## Reminder Data Model

Each reminder in Firestore has:

```javascript
{
  id: string,                    // Unique identifier
  title: string,                 // Reminder title
  notes?: string,                // Optional notes
  status: string,                // pending | completed
  dueAt?: Date,                  // Due date/time
  dueDate: string,               // Formatted due date (for LLM)
  dueDateTime: string,           // Formatted due date+time (for LLM)
  daysUntil?: number,            // Days until due
  isCompleted: boolean,          // Completion status
  completedAt?: Date,            // When completed
  recurrence?: string,           // Recurrence pattern (daily, weekly, etc)
  isShared: boolean,             // Is shared with others
  sharedWith?: string[],         // Emails of users it's shared with
  createdAt: Date,               // Creation timestamp
  isDisabled: boolean,           // Is disabled
  ownerId: string,               // Email of owner
}
```

## Security Notes

1. **Never commit `.env` file** - it contains credentials
2. **Use service account keys** for server-side access, not user credentials
3. **Firestore rules should validate** `ownerId` and `sharedWith` fields
4. **Credentials should be in environment variables** or secure vaults
5. **Only expose necessary fields** to AI assistant

## Performance Considerations

- Queries are limited to the authenticated user's reminders
- Results are formatted for LLM consumption (verbose but clear)
- Consider adding pagination for large reminder lists
- Firestore indexes may improve query performance

## Next Steps

1. ✅ Install dependencies: `npm install`
2. ✅ Configure Firebase credentials in `.env`
3. ✅ Test server: `npm start`
4. ✅ Configure OpenClaw with MCP server
5. ✅ Test Claude integration

## Support & Debugging

For issues:

1. Check `.env` configuration is correct
2. Enable `DEBUG=true` and check stderr output
3. Verify Firestore has data for the specified user
4. Test tool calls manually using MCP protocol

## API Reference

For detailed API documentation, see [MCP_SERVER_PLAN.md](./MCP_SERVER_PLAN.md).

---

Happy reminding! 🎯
