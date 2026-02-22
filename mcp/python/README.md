# AI Reminder MCP Server - Python/FastAPI Version

Welcome! This is the Python/FastAPI implementation of the MCP (Model Context Protocol) server for accessing your AI Reminder events.

## Quick Start

### 1. Create Python Virtual Environment

```bash
cd c:\Projects\AI\aireminder\functions\python

# Create virtual environment
python -m venv venv

# Activate virtual environment
# On Windows:
venv\Scripts\activate

# On macOS/Linux:
source venv/bin/activate
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Configure Firebase Credentials

Copy the example `.env` file:

```bash
cp .env.example .env
```

Edit `.env` with your Firebase credentials:

```env
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\nMIIEvQI...\n-----END PRIVATE KEY-----\n
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-abc@your-project.iam.gserviceaccount.com
USER_ID=your-email@example.com
DEBUG=false
```

**Getting Firebase credentials:**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project → Settings (gear icon)
3. Service Accounts tab → Generate new private key
4. Copy values from the downloaded JSON file

### 4. Start the Server

```bash
# Using Python directly
python mcp_server.py

# Or using uvicorn
uvicorn mcp_server:app --reload

# Or with custom host/port
uvicorn mcp_server:app --host 127.0.0.1 --port 8000
```

You should see output like:
```
INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)
```

---

## Running Methods

### Method 1: Direct Python Execution (Development)

```bash
cd c:\Projects\AI\aireminder\functions\python
source venv/Scripts/activate  # or venv\Scripts\activate on Windows
python mcp_server.py
```

### Method 2: With Uvicorn (Production)

```bash
# Install uvicorn separately if needed
pip install uvicorn

# Run with auto-reload for development
uvicorn mcp_server:app --reload

# Run for production
uvicorn mcp_server:app --host 0.0.0.0 --port 8000 --workers 4
```

### Method 3: With OpenClaw

Add to your OpenClaw config (`config.json` or `.openclaw/config.json`):

```json
{
  "mcp": {
    "servers": {
      "aireminder-python": {
        "command": "python",
        "args": ["C:\\Projects\\AI\\aireminder\\functions\\python\\mcp_server.py"],
        "env": {
          "FIREBASE_PROJECT_ID": "your-firebase-project-id",
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

### Method 4: Docker Container

Create a `Dockerfile` in the python directory:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV PYTHONUNBUFFERED=1
ENV NODE_ENV=production

CMD ["python", "mcp_server.py"]
```

Build and run:

```bash
docker build -t aireminder-mcp-python .
docker run -e FIREBASE_PROJECT_ID="..." \
           -e FIREBASE_PRIVATE_KEY="..." \
           -e FIREBASE_CLIENT_EMAIL="..." \
           -e USER_ID="..." \
           aireminder-mcp-python
```

---

## API Documentation

Once running, visit:
- **Swagger UI:** http://127.0.0.1:8000/docs
- **ReDoc:** http://127.0.0.1:8000/redoc
- **Health Check:** http://127.0.0.1:8000/health

---

## Available Endpoints

### Health Check

```bash
GET /health

Response:
{
  "status": "ok",
  "service": "aireminder-mcp-server",
  "version": "1.0.0"
}
```

### Root Info

```bash
GET /

Response:
{
  "service": "AI Reminder MCP Server (FastAPI)",
  "version": "1.0.0",
  "docs": "/docs",
  "openapi": "/openapi.json"
}
```

---

## MCP Resources & Tools

### Resources (Read-Only)

Resources are read-only data endpoints:

- `reminders://list/{userId}` - All reminders
- `reminders://upcoming/{userId}/7` - Next 7 days
- `reminders://today/{userId}` - Today's reminders
- `reminders://overdue/{userId}` - Overdue items
- `reminders://summary/{userId}` - Statistics
- `reminders://shared/{userId}` - Shared with you

### Tools (Callable Actions)

#### Read Tools

- **list_reminders** - Get all reminders with optional filters
- **get_upcoming_reminders** - Next N days with priority sorting
- **get_today_reminders** - Today's reminders
- **get_overdue_reminders** - Overdue items
- **get_reminder_details** - Single reminder details
- **search_reminders** - Full-text search
- **get_reminders_summary** - Statistics
- **get_shared_reminders** - Shared items

#### Write Tools

- **add_reminder** - Create a new reminder
- **edit_reminder** - Update existing reminder
- **delete_reminder** - Delete (soft delete)
- **complete_reminder** - Mark as completed

---

## File Structure

```
python/
├── mcp_server.py          # Main FastAPI MCP server
├── firebase_config.py     # Firebase initialization
├── reminders_service.py   # Business logic
├── utils.py              # Helper utilities
├── requirements.txt      # Python dependencies
├── .env.example          # Configuration template
├── .env                  # Configuration (DO NOT commit)
├── .gitignore           # Git ignore rules
└── README.md            # This file
```

## Python Virtual Environment

### Create and Activate

```bash
# Create
python -m venv venv

# Activate (Windows)
venv\Scripts\activate

# Activate (macOS/Linux)
source venv/bin/activate

# Deactivate
deactivate
```

### Install/Update Dependencies

```bash
pip install -r requirements.txt

# Update single package
pip install --upgrade firebase-admin
```

---

## Configuration File Location

Create `.env` in the **python** directory:

```
c:\Projects\AI\aireminder\
├── functions/
│   └── python/
│       ├── .env           ← Your credentials go here (DO NOT commit)
│       ├── .env.example   ← Template (safe to commit)
│       ├── mcp_server.py
│       └── requirements.txt
```

**⚠️ Important:** Never commit the `.env` file - it contains secrets!

---

## Testing

### Enable Debug Mode

```bash
# In .env
DEBUG=true

# Or via environment variable
set DEBUG=true
python mcp_server.py
```

This prints detailed logs showing:
- Firebase connection status
- Tool calls received
- Data being returned
- Any errors

### Test with curl

```bash
# Health check
curl http://127.0.0.1:8000/health

# API docs
curl http://127.0.0.1:8000/docs
```

### Test with OpenClaw/Claude

Once running with OpenClaw, ask Claude:

```
"Show me my reminders for today"
"Create a reminder to call mom tomorrow at 2pm"
"Mark my dentist appointment as complete"
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `ModuleNotFoundError: No module named 'firebase_admin'` | Run `pip install -r requirements.txt` in activated venv |
| `Firebase configuration error` | Check `.env` has all 3 Firebase fields |
| `Access denied: You do not have permission` | Verify `USER_ID` matches Firestore `ownerId` |
| `No reminders returned` | Ensure reminders exist in Firestore for that user |
| `Port 8000 already in use` | Use different port: `--port 8001` |
| `venv not recognized` | Activate with: `source venv/Scripts/activate` (Windows) |

Enable `DEBUG=true` to see detailed error messages.

---

## Dependencies

Key packages:

- **fastapi** - Modern web framework
- **uvicorn** - ASGI server
- **firebase-admin** - Firebase Admin SDK for Python
- **mcp** - Model Context Protocol SDK
- **pydantic** - Data validation
- **python-dotenv** - Environment variable loading
- **pytest** - Testing framework (optional)

See [requirements.txt](requirements.txt) for all dependencies and versions.

---

## Security

1. **Never commit `.env`** - Use `.env.example` for credentials template
2. **Use environment variables** for sensitive data
3. **Firebase rules** should validate `ownerId` and `sharedWith` fields
4. **User validation** - All operations verify user ownership
5. **Soft deletes** - Data is marked deleted, not removed
6. **Audit trail** - Track modifications with `lastModifiedBy` and `version`

---

## Performance Notes

- Queries are filtered by authenticated user
- Results are formatted for LLM consumption
- Firestore indexes may improve query performance
- Consider pagination for large datasets
- Async/await used throughout for better concurrency

---

## Comparison: Node.js vs Python

| Feature | Node.js | Python |
|---------|---------|--------|
| Framework | MCP SDK (stdio) | FastAPI + MCP SDK |
| Server Type | StdIO transport | HTTP + StdIO |
| Startup | Fast (~100ms) | Slower (~500ms) |
| Memory | Low (~50MB) | Medium (~150MB) |
| Best For | CLI tools | Web integration |
| API Docs | None | Swagger + ReDoc |

Both have identical functionality - choose based on your infrastructure.

---

## Next Steps

1. ✅ Create venv: `python -m venv venv`
2. ✅ Activate: `source venv/Scripts/activate`
3. ✅ Install: `pip install -r requirements.txt`
4. ✅ Configure: Edit `.env` with Firebase credentials
5. ✅ Test: `python mcp_server.py`
6. ✅ Access docs: Visit http://127.0.0.1:8000/docs
7. ✅ Use with OpenClaw: Add config to `.openclaw/config.json`

Ready to go! 🚀
