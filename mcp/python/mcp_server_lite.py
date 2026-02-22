#!/usr/bin/env python3
"""
Simplified FastAPI Server for AI Reminder
Works with Python 3.9+ without requiring MCP SDK
Provides full HTTP API for reminder management

Usage:
    python mcp_server_lite.py
    
    Or with uvicorn:
    uvicorn mcp_server_lite:app --host 0.0.0.0 --port 8000
"""

import os
import sys
import json
from typing import Any, Optional, List
import asyncio

from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
import uvicorn
from dotenv import load_dotenv

from firebase_config import initialize_firebase, get_firestore, test_connection
import reminders_service as service
from utils import create_success_response, create_error_response

# Load environment variables
load_dotenv()

# Configuration
DEFAULT_USER_ID = os.getenv("USER_ID", "user@example.com")
DEBUG = os.getenv("DEBUG", "false").lower() == "true"

# Initialize FastAPI app
app = FastAPI(
    title="AI Reminder API Server",
    description="HTTP API for accessing user reminders",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)


# ============================================================================
# Pydantic Models for Requests/Responses
# ============================================================================

class ReminderCreate(BaseModel):
    """Model for creating a reminder"""
    title: str
    notes: Optional[str] = None
    dueAt: Optional[str] = None
    recurrence: Optional[str] = None
    remindBeforeMinutes: Optional[int] = 10
    recurrenceEndDate: Optional[str] = None
    weeklyDays: Optional[List[int]] = None
    sharedWith: Optional[List[str]] = None


class ReminderUpdate(BaseModel):
    """Model for updating a reminder"""
    title: Optional[str] = None
    notes: Optional[str] = None
    dueAt: Optional[str] = None
    recurrence: Optional[str] = None
    remindBeforeMinutes: Optional[int] = None
    recurrenceEndDate: Optional[str] = None
    weeklyDays: Optional[List[int]] = None
    sharedWith: Optional[List[str]] = None


class ToolCall(BaseModel):
    """Model for calling MCP tools via HTTP"""
    name: str
    arguments: dict


# ============================================================================
# Startup/Shutdown
# ============================================================================

@app.on_event("startup")
async def startup_event():
    """Initialize Firebase on startup"""
    try:
        if DEBUG:
            print("[DEBUG] Initializing Firebase...", file=sys.stderr)
        initialize_firebase()

        if DEBUG:
            print("[DEBUG] Testing Firebase connection...", file=sys.stderr)
            connected = await test_connection()
            if not connected:
                print(
                    "WARNING: Could not verify Firebase connection",
                    file=sys.stderr,
                )
        print("✓ Server started successfully", file=sys.stderr)
    except Exception as error:
        print(f"Fatal error during startup: {error}", file=sys.stderr)
        raise


# ============================================================================
# Health & Info Endpoints
# ============================================================================

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "ok",
        "service": "aireminder-api-server",
        "version": "1.0.0",
    }


@app.get("/")
async def root():
    """Root endpoint with service info"""
    return {
        "service": "AI Reminder API Server",
        "version": "1.0.0",
        "docs": "/docs",
        "redoc": "/redoc",
        "openapi": "/openapi.json",
        "endpoints": {
            "reminders": "/api/reminders",
            "tools": "/api/tools",
            "resources": "/api/resources",
        },
    }


# ============================================================================
# MCP Tools via HTTP (Compatibility Layer)
# ============================================================================

@app.get("/api/tools")
async def list_tools():
    """List all available MCP tools"""
    return {
        "tools": [
            {
                "name": "list_reminders",
                "description": "Get all reminders for the authenticated user with optional filtering",
                "parameters": {
                    "userId": "User ID or email (optional)",
                    "status": "pending|completed|all (default: all)",
                    "limit": "Maximum number of reminders",
                }
            },
            {
                "name": "get_upcoming_reminders",
                "description": "Get reminders due in the next N days",
                "parameters": {
                    "userId": "User ID or email (optional)",
                    "days": "Number of days to look ahead (default: 7)",
                    "sortBy": "dueDate|priority (default: priority)",
                    "includeCompleted": "Include completed reminders (default: false)",
                }
            },
            {
                "name": "get_today_reminders",
                "description": "Get all reminders due today (includes own + shared reminders)",
                "parameters": {
                    "userId": "User ID or email (optional)",
                    "includeCompleted": "Include completed reminders (default: false)",
                }
            },
            {
                "name": "get_reminders_for_date",
                "description": "Get reminders for a specific date (includes own + shared reminders)",
                "parameters": {
                    "userId": "User ID or email (optional)",
                    "date": "Date in ISO format (YYYY-MM-DD or ISO-8601 format) (required)",
                    "includeCompleted": "Include completed reminders (default: false)",
                }
            },
            {
                "name": "get_overdue_reminders",
                "description": "Get all overdue (pending) reminders",
                "parameters": {
                    "userId": "User ID or email (optional)",
                }
            },
            {
                "name": "get_reminder_details",
                "description": "Get detailed information about a specific reminder",
                "parameters": {
                    "reminderId": "The reminder ID (required)",
                    "userId": "User ID or email (optional)",
                }
            },
            {
                "name": "search_reminders",
                "description": "Search reminders by title or notes",
                "parameters": {
                    "query": "Search query (required)",
                    "userId": "User ID or email (optional)",
                    "status": "pending|completed|all (default: all)",
                    "limit": "Maximum number of results",
                }
            },
            {
                "name": "get_reminders_summary",
                "description": "Get a summary of reminder statistics",
                "parameters": {
                    "userId": "User ID or email (optional)",
                }
            },
            {
                "name": "get_shared_reminders",
                "description": "Get reminders that are shared with the user",
                "parameters": {
                    "userId": "User ID or email (optional)",
                }
            },
            {
                "name": "add_reminder",
                "description": "Create a new reminder",
                "parameters": {
                    "title": "Reminder title (required)",
                    "userId": "User ID or email (optional)",
                    "notes": "Optional notes or description",
                    "dueAt": "Due date/time in ISO format",
                    "recurrence": "Recurrence pattern (daily, weekly, monthly)",
                    "remindBeforeMinutes": "Minutes before due date to remind",
                    "recurrenceEndDate": "End date for recurring reminders",
                    "weeklyDays": "Days of week for weekly recurrence (1=Monday, 7=Sunday)",
                    "sharedWith": "List of email addresses to share with",
                }
            },
            {
                "name": "edit_reminder",
                "description": "Update an existing reminder",
                "parameters": {
                    "reminderId": "The reminder ID (required)",
                    "userId": "User ID or email (optional)",
                    "title": "New reminder title",
                    "notes": "Updated notes",
                    "dueAt": "Updated due date/time",
                    "recurrence": "Updated recurrence pattern",
                    "remindBeforeMinutes": "Updated reminder time",
                    "recurrenceEndDate": "Updated recurrence end date",
                    "weeklyDays": "Updated weekly days",
                    "sharedWith": "Updated share list",
                }
            },
            {
                "name": "delete_reminder",
                "description": "Delete a reminder (soft delete)",
                "parameters": {
                    "reminderId": "The reminder ID (required)",
                    "userId": "User ID or email (optional)",
                }
            },
            {
                "name": "complete_reminder",
                "description": "Mark a reminder as completed",
                "parameters": {
                    "reminderId": "The reminder ID (required)",
                    "userId": "User ID or email (optional)",
                }
            },
        ]
    }


@app.get("/api/resources")
async def list_resources(userId: Optional[str] = Query(None)):
    """List all available MCP resources"""
    user_id = userId or DEFAULT_USER_ID
    return {
        "resources": [
            {
                "uri": f"reminders://list/{user_id}",
                "name": "All Reminders",
                "description": "Complete list of all reminders for the user",
                "endpoint": "/api/reminders",
            },
            {
                "uri": f"reminders://upcoming/{user_id}/7",
                "name": "Upcoming Reminders (7 days)",
                "description": "Reminders due in the next 7 days",
                "endpoint": "/api/reminders/upcoming",
            },
            {
                "uri": f"reminders://today/{user_id}",
                "name": "Today Reminders",
                "description": "Reminders due today",
                "endpoint": "/api/reminders/today",
            },
            {
                "uri": f"reminders://overdue/{user_id}",
                "name": "Overdue Reminders",
                "description": "Reminders that are overdue",
                "endpoint": "/api/reminders/overdue",
            },
            {
                "uri": f"reminders://summary/{user_id}",
                "name": "Reminders Summary",
                "description": "Summary statistics of user reminders",
                "endpoint": "/api/reminders/summary",
            },
            {
                "uri": f"reminders://shared/{user_id}",
                "name": "Shared Reminders",
                "description": "Reminders shared with the user by others",
                "endpoint": "/api/reminders/shared",
            },
        ]
    }


@app.post("/api/tools/call")
async def call_tool(tool_call: ToolCall):
    """Execute a tool call via HTTP (MCP tool simulation)"""
    name = tool_call.name
    arguments = tool_call.arguments
    user_id = arguments.get("userId", DEFAULT_USER_ID)

    try:
        result = None

        if name == "list_reminders":
            result = await service.get_all_reminders(
                user_id,
                status=arguments.get("status", "all"),
                limit=arguments.get("limit"),
            )

        elif name == "get_upcoming_reminders":
            result = await service.get_upcoming_reminders(
                user_id,
                days=arguments.get("days", 7),
                sort_by=arguments.get("sortBy", "priority"),
                include_completed=arguments.get("includeCompleted", False),
            )

        elif name == "get_today_reminders":
            result = await service.get_today_reminders(
                user_id,
                include_completed=arguments.get("includeCompleted", False),
            )

        elif name == "get_reminders_for_date":
            if "date" not in arguments:
                raise HTTPException(
                    status_code=400,
                    detail="'date' parameter is required for get_reminders_for_date"
                )
            result = await service.get_reminders_for_date(
                user_id,
                arguments["date"],
                include_completed=arguments.get("includeCompleted", False),
            )

        elif name == "get_overdue_reminders":
            result = await service.get_overdue_reminders(user_id)

        elif name == "get_reminder_details":
            result = await service.get_reminder_by_id(
                arguments["reminderId"], user_id
            )

        elif name == "search_reminders":
            result = await service.search_user_reminders(
                user_id,
                arguments["query"],
                status=arguments.get("status", "all"),
                limit=arguments.get("limit"),
            )

        elif name == "get_reminders_summary":
            result = await service.get_reminders_summary(user_id)

        elif name == "get_shared_reminders":
            result = await service.get_shared_reminders(user_id)

        elif name == "add_reminder":
            result = await service.create_reminder(
                user_id,
                arguments["title"],
                notes=arguments.get("notes"),
                due_at=arguments.get("dueAt"),
                recurrence=arguments.get("recurrence"),
                remind_before_minutes=arguments.get("remindBeforeMinutes", 10),
                recurrence_end_date=arguments.get("recurrenceEndDate"),
                weekly_days=arguments.get("weeklyDays"),
                shared_with=arguments.get("sharedWith"),
            )

        elif name == "edit_reminder":
            result = await service.update_reminder(
                arguments["reminderId"],
                user_id,
                title=arguments.get("title"),
                notes=arguments.get("notes"),
                due_at=arguments.get("dueAt"),
                recurrence=arguments.get("recurrence"),
                remind_before_minutes=arguments.get("remindBeforeMinutes"),
                recurrence_end_date=arguments.get("recurrenceEndDate"),
                weekly_days=arguments.get("weeklyDays"),
                shared_with=arguments.get("sharedWith"),
            )

        elif name == "delete_reminder":
            result = await service.delete_reminder(arguments["reminderId"], user_id)

        elif name == "complete_reminder":
            result = await service.complete_reminder(arguments["reminderId"], user_id)

        else:
            raise HTTPException(
                status_code=404,
                detail=f"Unknown tool: {name}"
            )

        return create_success_response(result)

    except Exception as error:
        if DEBUG:
            print(f"[DEBUG] Tool call error in {name}: {error}", file=sys.stderr)
        raise HTTPException(
            status_code=500,
            detail=str(error)
        )


# ============================================================================
# REST API Endpoints for Reminders
# ============================================================================

@app.get("/api/debug/all-reminders")
async def debug_all_reminders():
    """Debug endpoint - return ALL reminders from Firestore (no filter)"""
    try:
        db = get_firestore()
        docs = db.collection("reminders").stream()
        reminders = []
        for doc in docs:
            reminders.append({
                "id": doc.id,
                **doc.to_dict()
            })
        return {
            "total_count": len(reminders),
            "reminders": reminders
        }
    except Exception as error:
        if DEBUG:
            print(f"[DEBUG] Error getting all reminders: {error}", file=sys.stderr)
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/api/debug/collections")
async def debug_collections():
    """Debug endpoint - list all collections in Firestore"""
    try:
        db = get_firestore()
        collections = db.collections()
        collection_list = []
        for col in collections:
            collection_list.append({
                "name": col.id,
                "path": col.path
            })
        return {
            "total_collections": len(collection_list),
            "collections": collection_list
        }
    except Exception as error:
        if DEBUG:
            print(f"[DEBUG] Error getting collections: {error}", file=sys.stderr)
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/api/debug/collection/{collection_name}")
async def debug_get_collection(collection_name: str):
    """Debug endpoint - get documents from a collection"""
    try:
        db = get_firestore()
        docs = db.collection(collection_name).stream()
        items = []
        for doc in docs:
            items.append({
                "id": doc.id,
                **doc.to_dict()
            })
        return {
            "collection": collection_name,
            "count": len(items),
            "items": items
        }
    except Exception as error:
        if DEBUG:
            print(f"[DEBUG] Error getting collection: {error}", file=sys.stderr)
        raise HTTPException(status_code=500, detail=str(error))


# ============================================================================
# REST API Endpoints for Reminders
# ============================================================================

@app.get("/api/reminders/upcoming")
async def get_upcoming_reminders(
    userId: Optional[str] = Query(None),
    days: int = Query(7),
    sortBy: Optional[str] = Query("priority"),
    includeCompleted: bool = Query(False),
):
    """Get upcoming reminders"""
    user_id = userId or DEFAULT_USER_ID
    try:
        reminders = await service.get_upcoming_reminders(
            user_id, days=days, sort_by=sortBy, include_completed=includeCompleted
        )
        return create_success_response(reminders)
    except Exception as error:
        if DEBUG:
            print(f"[DEBUG] Error getting upcoming reminders: {error}", file=sys.stderr)
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/api/reminders/today")
async def get_today_reminders(
    userId: Optional[str] = Query(None),
    includeCompleted: bool = Query(False),
):
    """Get today's reminders"""
    user_id = userId or DEFAULT_USER_ID
    try:
        reminders = await service.get_today_reminders(user_id, include_completed=includeCompleted)
        return create_success_response(reminders)
    except Exception as error:
        if DEBUG:
            print(f"[DEBUG] Error getting today reminders: {error}", file=sys.stderr)
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/api/reminders/date/{date}")
async def get_reminders_for_date(
    date: str,
    userId: Optional[str] = Query(None),
    includeCompleted: bool = Query(False),
):
    """Get reminders for a specific date (YYYY-MM-DD or ISO-8601 format)"""
    user_id = userId or DEFAULT_USER_ID
    try:
        reminders = await service.get_reminders_for_date(
            user_id, 
            date, 
            include_completed=includeCompleted
        )
        return create_success_response(reminders)
    except Exception as error:
        if DEBUG:
            print(f"[DEBUG] Error getting reminders for date: {error}", file=sys.stderr)
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/api/reminders/overdue")
async def get_overdue_reminders(userId: Optional[str] = Query(None)):
    """Get overdue reminders"""
    user_id = userId or DEFAULT_USER_ID
    try:
        reminders = await service.get_overdue_reminders(user_id)
        return create_success_response(reminders)
    except Exception as error:
        if DEBUG:
            print(f"[DEBUG] Error getting overdue reminders: {error}", file=sys.stderr)
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/api/reminders/summary")
async def get_reminders_summary(userId: Optional[str] = Query(None)):
    """Get summary statistics"""
    user_id = userId or DEFAULT_USER_ID
    try:
        summary = await service.get_reminders_summary(user_id)
        return create_success_response(summary)
    except Exception as error:
        if DEBUG:
            print(f"[DEBUG] Error getting summary: {error}", file=sys.stderr)
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/api/reminders/shared")
async def get_shared_reminders(userId: Optional[str] = Query(None)):
    """Get reminders shared with the user"""
    user_id = userId or DEFAULT_USER_ID
    try:
        reminders = await service.get_shared_reminders(user_id)
        return create_success_response(reminders)
    except Exception as error:
        if DEBUG:
            print(f"[DEBUG] Error getting shared reminders: {error}", file=sys.stderr)
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/api/reminders/{reminder_id}")
async def get_reminder_details(
    reminder_id: str,
    userId: Optional[str] = Query(None),
):
    """Get details of a specific reminder"""
    user_id = userId or DEFAULT_USER_ID
    try:
        reminder = await service.get_reminder_by_id(reminder_id, user_id)
        return create_success_response(reminder)
    except Exception as error:
        if DEBUG:
            print(f"[DEBUG] Error getting reminder details: {error}", file=sys.stderr)
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/api/reminders/search/{query}")
async def search_reminders(
    query: str,
    userId: Optional[str] = Query(None),
    status: Optional[str] = Query("all"),
    limit: Optional[int] = Query(None),
):
    """Search reminders by title or notes"""
    user_id = userId or DEFAULT_USER_ID
    try:
        reminders = await service.search_user_reminders(
            user_id, query, status=status, limit=limit
        )
        return create_success_response(reminders)
    except Exception as error:
        if DEBUG:
            print(f"[DEBUG] Error searching reminders: {error}", file=sys.stderr)
        raise HTTPException(status_code=500, detail=str(error))


@app.post("/api/reminders")
async def create_reminder(
    reminder: ReminderCreate,
    userId: Optional[str] = Query(None),
):
    """Create a new reminder"""
    user_id = userId or DEFAULT_USER_ID
    try:
        new_reminder = await service.create_reminder(
            user_id,
            reminder.title,
            notes=reminder.notes,
            due_at=reminder.dueAt,
            recurrence=reminder.recurrence,
            remind_before_minutes=reminder.remindBeforeMinutes,
            recurrence_end_date=reminder.recurrenceEndDate,
            weekly_days=reminder.weeklyDays,
            shared_with=reminder.sharedWith,
        )
        return create_success_response(new_reminder)
    except Exception as error:
        if DEBUG:
            print(f"[DEBUG] Error creating reminder: {error}", file=sys.stderr)
        raise HTTPException(status_code=500, detail=str(error))


@app.put("/api/reminders/{reminder_id}")
async def update_reminder(
    reminder_id: str,
    reminder: ReminderUpdate,
    userId: Optional[str] = Query(None),
):
    """Update an existing reminder"""
    user_id = userId or DEFAULT_USER_ID
    try:
        updated = await service.update_reminder(
            reminder_id,
            user_id,
            title=reminder.title,
            notes=reminder.notes,
            due_at=reminder.dueAt,
            recurrence=reminder.recurrence,
            remind_before_minutes=reminder.remindBeforeMinutes,
            recurrence_end_date=reminder.recurrenceEndDate,
            weekly_days=reminder.weeklyDays,
            shared_with=reminder.sharedWith,
        )
        return create_success_response(updated)
    except Exception as error:
        if DEBUG:
            print(f"[DEBUG] Error updating reminder: {error}", file=sys.stderr)
        raise HTTPException(status_code=500, detail=str(error))


@app.delete("/api/reminders/{reminder_id}")
async def delete_reminder(
    reminder_id: str,
    userId: Optional[str] = Query(None),
):
    """Delete a reminder"""
    user_id = userId or DEFAULT_USER_ID
    try:
        result = await service.delete_reminder(reminder_id, user_id)
        return create_success_response(result)
    except Exception as error:
        if DEBUG:
            print(f"[DEBUG] Error deleting reminder: {error}", file=sys.stderr)
        raise HTTPException(status_code=500, detail=str(error))


@app.post("/api/reminders/{reminder_id}/complete")
async def complete_reminder(
    reminder_id: str,
    userId: Optional[str] = Query(None),
):
    """Mark a reminder as completed"""
    user_id = userId or DEFAULT_USER_ID
    try:
        result = await service.complete_reminder(reminder_id, user_id)
        return create_success_response(result)
    except Exception as error:
        if DEBUG:
            print(f"[DEBUG] Error completing reminder: {error}", file=sys.stderr)
        raise HTTPException(status_code=500, detail=str(error))


# ============================================================================
# Main
# ============================================================================

if __name__ == "__main__":
    # Start FastAPI server with uvicorn
    print("Starting AI Reminder API Server on http://127.0.0.1:8000", file=sys.stderr)
    print("Docs available at http://127.0.0.1:8000/docs", file=sys.stderr)
    uvicorn.run(
        "mcp_server_lite:app",
        host="127.0.0.1",
        port=8000,
        reload=DEBUG,
        log_level="debug" if DEBUG else "info",
    )
