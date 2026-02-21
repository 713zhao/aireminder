# MCP Server for AI Reminder - Implementation Plan

## Overview
Create a Model Context Protocol (MCP) server that allows OpenClaw (and other AI tools) to retrieve user reminders and events from your Firestore database via a standardized interface.

## Architecture

```
┌─────────────────────┐
│  OpenClaw / Claude  │
│   (AI Tool/Client)  │
└──────────┬──────────┘
           │ (MCP Protocol)
           │
┌──────────▼──────────┐
│   MCP Server        │
│  (Node.js Service)  │
│  - stdio transport  │
└──────────┬──────────┘
           │ (Firebase SDK)
           │
┌──────────▼──────────┐
│  Firestore          │
│  (User Reminders)   │
└─────────────────────┘
```

## Implementation Steps

### Phase 1: Setup MCP Server Infrastructure
1. **Initialize Node.js project**
   - Create/update `package.json` with MCP SDK and Firebase dependencies
   - Install dependencies

2. **Create MCP Server core** (`mcp-server.js`)
   - Initialize MCP server with stdio transport
   - Setup Firebase Admin SDK connection
   - Define resources and tools for accessing reminders

3. **Implement Firebase connection** (`firebase-config.js`)
   - Initialize Firebase Admin SDK
   - Load service account credentials from environment
   - Create Firestore client

### Phase 2: Define MCP Resources & Tools

#### Resources
Resources are read-only data that the MCP server makes available:

- **`reminders://list/{userId}`** - Complete list of all reminders for a user
- **`reminders://upcoming/{userId}/{days}`** - Upcoming reminders for next N days
- **`reminders://today/{userId}`** - Reminders due today
- **`reminders://completed/{userId}/{limit}`** - Recently completed reminders

#### Tools
Tools are actions that can be invoked:

- **`list_reminders`** - Get all reminders with optional filters
  - Inputs: userId, status (pending|completed|all), limit
  - Returns: Array of reminder objects

- **`get_reminder_details`** - Get detailed info about a specific reminder
  - Inputs: reminderId
  - Returns: Full reminder object with metadata

- **`get_upcoming_reminders`** - Get reminders due in next N days
  - Inputs: userId, days, sortBy
  - Returns: Sorted array of upcoming reminders

- **`search_reminders`** - Search reminders by title/notes
  - Inputs: userId, query, status
  - Returns: Matching reminders

- **`add_reminder`** - Create a new reminder
  - Inputs: userId, title (required), notes, dueAt, recurrence, remindBeforeMinutes, sharedWith
  - Returns: Created reminder object with ID

- **`edit_reminder`** - Update an existing reminder
  - Inputs: userId, reminderId (required), title, notes, dueAt, recurrence, sharedWith
  - Returns: Updated reminder object

- **`delete_reminder`** - Delete a reminder
  - Inputs: userId, reminderId (required)
  - Returns: Success message

- **`complete_reminder`** - Mark a reminder as completed
  - Inputs: userId, reminderId (required)
  - Returns: Updated reminder with completion timestamp

### Phase 3: Create Helper Modules

1. **`reminders-service.js`** - Business logic for reminder queries and mutations
   - Query methods for different filter scenarios
   - Create, update, delete, complete operations
   - Data transformation/formatting
   - Error handling and ownership validation

2. **`utils.js`** - Utility functions
   - Date formatting and calculations
   - Data validation
   - Response formatting
   - Status detection

## Implementation Files to Create

```
functions/
├── mcp-server.js           # Main MCP server (stdio transport)
├── firebase-config.js      # Firebase initialization
├── reminders-service.js    # Reminder query & mutation logic
├── utils.js                # Helper utilities
├── .env.example            # Environment template
├── package.json            # Dependencies
└── README.md               # Setup instructions
```

## Configuration in OpenClaw

### Option 1: Direct MCP Server Connection (Recommended)

**Setup in OpenClaw config file** (`~/.openclaw/config.json` or project config):

```json
{
  "mcp": {
    "servers": {
      "aireminder": {
        "command": "node",
        "args": ["C:\\Projects\\AI\\aireminder\\functions\\mcp-server.js"],
        "env": {
          "FIREBASE_PROJECT_ID": "your-firebase-project",
          "FIREBASE_PRIVATE_KEY": "...",
          "FIREBASE_CLIENT_EMAIL": "...",
          "USER_ID": "current-user-email@example.com"
        }
      }
    }
  }
}
```

### Option 2: Using MCP via Environment Variables

If running MCP server separately:

```bash
# Start MCP server
set FIREBASE_PROJECT_ID=your-project-id
set FIREBASE_PRIVATE_KEY=your-private-key
set FIREBASE_CLIENT_EMAIL=your-service-account@...iam.gserviceaccount.com
set USER_ID=user@example.com
node mcp-server.js
```

Then configure OpenClaw to connect to the stdio channel.

### Option 3: Docker Container (Production)

Create a Dockerfile:

```dockerfile
FROM node:18-slim
WORKDIR /app
COPY functions/ .
RUN npm install
ENV FIREBASE_PROJECT_ID=your-project-id
# ... other env vars
CMD ["node", "mcp-server.js"]
```

## Feature Breakdown

### Core Reminder Operations (Read)
- ✅ List all reminders for authenticated user
- ✅ Filter by status (pending, completed, overdue)
- ✅ Get upcoming reminders (next N days)
- ✅ Search reminders by title/content
- ✅ Get reminder details with all metadata
- ✅ Get reminders summary and statistics
- ✅ Support for recurring reminders
- ✅ Support for shared/family reminders

### Reminder Mutations (Write)
- ✅ Create new reminders with all properties
- ✅ Edit/update existing reminders
- ✅ Delete reminders (soft delete)
- ✅ Mark reminders as completed
- ✅ Ownership validation and access control
- ✅ Support for sharing reminders
- ✅ Track modification history (version, lastModifiedBy)

### MCP Protocol Features
- ✅ Resource URIs for different data views
- ✅ Tools for complex queries
- ✅ Proper error handling and validation
- ✅ Response formatting for LLM consumption
- ✅ Pagination support for large datasets

## Security Considerations

1. **Authentication**
   - Use Firebase service account for server-side authentication
   - Validate user ID in all requests
   - Implement user context isolation

2. **Credentials**
   - Store Firebase credentials in `.env` file (not in git)
   - Use environment variables for config
   - Example `.env.example` file provided

3. **Access Control**
   - Only return reminders owned by or shared with the authenticated user
   - Respect privacy settings for shared reminders
   - Log access for audit purposes

4. **Data Protection**
   - Validate all inputs
   - Sanitize search queries
   - Rate limit API calls if needed

## Testing

Test the MCP server with:

```bash
# Manual testing with curl/stdio
node mcp-server.js

# Send MCP protocol messages
# Example: {"jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": {}}
```

## Integration with OpenClaw

Once configured, OpenClaw can use the MCP resources/tools like:

**Example Claude Prompt:**
```
User: "Show me my reminders for today"

Claude uses MCP:
→ tool: get_upcoming_reminders
  userId: "user@example.com"
  days: 1
  
← Returns reminders due today

Claude formats response in natural language to user
```

## Timeline & Dependencies

| Phase | Files | Effort | Dependencies |
|-------|-------|--------|--------------|
| 1 | `package.json`, `firebase-config.js` | 1-2h | Node.js, npm, Firebase Admin SDK |
| 2 | `mcp-server.js` | 2-3h | MCP SDK knowledge |
| 3 | `reminders-service.js`, `utils.js` | 2-3h | Firestore schema knowledge |
| 4 | OpenClaw Config | 1h | OpenClaw documentation |

**Total Estimated Time:** 6-9 hours

## Next Steps

1. Review this plan
2. Create the Node.js MCP server implementation
3. Set up Firebase credentials
4. Test MCP server locally
5. Configure OpenClaw to use the MCP server
6. Test integration end-to-end

