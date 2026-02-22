#!/usr/bin/env python3
"""
MCP Server for AI Reminder - FastAPI Implementation
Provides access to user reminders through the Model Context Protocol

Usage:
    python mcp_server.py
    
    Or with uvicorn:
    uvicorn mcp_server:app --host 0.0.0.0 --port 8000
"""

import os
import sys
import json
from typing import Any, Optional
import asyncio

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn
from dotenv import load_dotenv

# MCP imports
from mcp.server.fastapi import FastAPIServer
from mcp.types import (
    Tool,
    TextContent,
    ToolResult,
    Resource,
)

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
    title="AI Reminder MCP Server",
    description="MCP server for accessing user reminders via FastAPI",
    version="1.0.0",
)

# Initialize MCP Server
mcp_server = FastAPIServer(title="aireminder-mcp-server", version="1.0.0")


# ============================================================================
# Pydantic Models
# ============================================================================

class ListResourcesRequest(BaseModel):
    """Request to list available resources"""

    pass


class ReadResourceRequest(BaseModel):
    """Request to read a resource"""

    uri: str


class ListToolsRequest(BaseModel):
    """Request to list available tools"""

    pass


class CallToolRequest(BaseModel):
    """Request to call a tool"""

    name: str
    arguments: dict


# ============================================================================
# Resources
# ============================================================================

@mcp_server.list_resources()
async def list_resources() -> list[Resource]:
    """List available resources"""
    return [
        Resource(
            uri=f"reminders://list/{DEFAULT_USER_ID}",
            name="All Reminders",
            description="Complete list of all reminders for the user",
            mimeType="application/json",
        ),
        Resource(
            uri=f"reminders://upcoming/{DEFAULT_USER_ID}/7",
            name="Upcoming Reminders (7 days)",
            description="Reminders due in the next 7 days",
            mimeType="application/json",
        ),
        Resource(
            uri=f"reminders://today/{DEFAULT_USER_ID}",
            name="Today Reminders",
            description="Reminders due today",
            mimeType="application/json",
        ),
        Resource(
            uri=f"reminders://overdue/{DEFAULT_USER_ID}",
            name="Overdue Reminders",
            description="Reminders that are overdue",
            mimeType="application/json",
        ),
        Resource(
            uri=f"reminders://summary/{DEFAULT_USER_ID}",
            name="Reminders Summary",
            description="Summary statistics of user reminders",
            mimeType="application/json",
        ),
        Resource(
            uri=f"reminders://shared/{DEFAULT_USER_ID}",
            name="Shared Reminders",
            description="Reminders shared with the user by others",
            mimeType="application/json",
        ),
    ]


@mcp_server.read_resource()
async def read_resource(uri: str) -> str:
    """Read a resource by URI"""
    import re

    try:
        # Parse URI: reminders://type/userId/optional-param
        match = re.match(r"^reminders://([^/]+)/([^/]+)(?:/(.+))?$", uri)
        if not match:
            return json.dumps(
                create_error_response("INVALID_URI", "Invalid resource URI format"),
                indent=2,
            )

        resource_type, user_id, param = match.groups()
        data = None

        if resource_type == "list":
            data = await service.get_all_reminders(user_id)

        elif resource_type == "upcoming":
            days = int(param) if param else 7
            data = await service.get_upcoming_reminders(user_id, days, sort_by="priority")

        elif resource_type == "today":
            data = await service.get_today_reminders(user_id)

        elif resource_type == "overdue":
            data = await service.get_overdue_reminders(user_id)

        elif resource_type == "summary":
            data = await service.get_reminders_summary(user_id)

        elif resource_type == "shared":
            data = await service.get_shared_reminders(user_id)

        else:
            return json.dumps(
                create_error_response(
                    "UNKNOWN_TYPE", f"Unknown resource type: {resource_type}"
                ),
                indent=2,
            )

        return json.dumps(create_success_response(data), indent=2)

    except Exception as error:
        if DEBUG:
            print(f"[DEBUG] ReadResourceRequest error: {error}", file=sys.stderr)
        return json.dumps(
            create_error_response("INTERNAL_ERROR", str(error)),
            indent=2,
        )


# ============================================================================
# Tools
# ============================================================================

@mcp_server.list_tools()
async def list_tools() -> list[Tool]:
    """List available tools"""
    return [
        # Read tools
        Tool(
            name="list_reminders",
            description="Get all reminders for the authenticated user with optional filtering",
            inputSchema={
                "type": "object",
                "properties": {
                    "userId": {
                        "type": "string",
                        "description": "User ID or email (optional, uses USER_ID env var if not provided)",
                    },
                    "status": {
                        "type": "string",
                        "enum": ["pending", "completed", "all"],
                        "description": "Filter by reminder status",
                        "default": "all",
                    },
                    "limit": {
                        "type": "number",
                        "description": "Maximum number of reminders to return",
                    },
                },
                "required": [],
            },
        ),
        Tool(
            name="get_upcoming_reminders",
            description="Get reminders due in the next N days, sorted by priority",
            inputSchema={
                "type": "object",
                "properties": {
                    "userId": {
                        "type": "string",
                        "description": "User ID or email (optional, uses USER_ID env var if not provided)",
                    },
                    "days": {
                        "type": "number",
                        "description": "Number of days to look ahead",
                        "default": 7,
                    },
                    "sortBy": {
                        "type": "string",
                        "enum": ["dueDate", "priority"],
                        "description": "Sort order for results",
                        "default": "priority",
                    },
                    "includeCompleted": {
                        "type": "boolean",
                        "description": "Include completed reminders",
                        "default": False,
                    },
                },
                "required": [],
            },
        ),
        Tool(
            name="get_today_reminders",
            description="Get all reminders due today",
            inputSchema={
                "type": "object",
                "properties": {
                    "userId": {
                        "type": "string",
                        "description": "User ID or email (optional, uses USER_ID env var if not provided)",
                    },
                    "includeCompleted": {
                        "type": "boolean",
                        "description": "Include completed reminders",
                        "default": False,
                    },
                },
                "required": [],
            },
        ),
        Tool(
            name="get_overdue_reminders",
            description="Get all overdue (pending) reminders",
            inputSchema={
                "type": "object",
                "properties": {
                    "userId": {
                        "type": "string",
                        "description": "User ID or email (optional, uses USER_ID env var if not provided)",
                    },
                },
                "required": [],
            },
        ),
        Tool(
            name="get_reminder_details",
            description="Get detailed information about a specific reminder",
            inputSchema={
                "type": "object",
                "properties": {
                    "reminderId": {
                        "type": "string",
                        "description": "The ID of the reminder to fetch",
                    },
                    "userId": {
                        "type": "string",
                        "description": "User ID or email (optional, uses USER_ID env var if not provided)",
                    },
                },
                "required": ["reminderId"],
            },
        ),
        Tool(
            name="search_reminders",
            description="Search reminders by title or notes",
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Search query string",
                    },
                    "userId": {
                        "type": "string",
                        "description": "User ID or email (optional, uses USER_ID env var if not provided)",
                    },
                    "status": {
                        "type": "string",
                        "enum": ["pending", "completed", "all"],
                        "description": "Filter by status",
                        "default": "all",
                    },
                    "limit": {
                        "type": "number",
                        "description": "Maximum number of results",
                    },
                },
                "required": ["query"],
            },
        ),
        Tool(
            name="get_reminders_summary",
            description="Get a summary of reminder statistics",
            inputSchema={
                "type": "object",
                "properties": {
                    "userId": {
                        "type": "string",
                        "description": "User ID or email (optional, uses USER_ID env var if not provided)",
                    },
                },
                "required": [],
            },
        ),
        Tool(
            name="get_shared_reminders",
            description="Get reminders that are shared with the user by others",
            inputSchema={
                "type": "object",
                "properties": {
                    "userId": {
                        "type": "string",
                        "description": "User ID or email (optional, uses USER_ID env var if not provided)",
                    },
                },
                "required": [],
            },
        ),
        # Write tools
        Tool(
            name="add_reminder",
            description="Create a new reminder",
            inputSchema={
                "type": "object",
                "properties": {
                    "title": {
                        "type": "string",
                        "description": "Reminder title (required)",
                    },
                    "notes": {
                        "type": "string",
                        "description": "Optional notes or description",
                    },
                    "dueAt": {
                        "type": "string",
                        "description": "Due date/time in ISO format (e.g., 2026-02-22T10:00:00Z)",
                    },
                    "recurrence": {
                        "type": "string",
                        "description": "Recurrence pattern (daily, weekly, monthly, etc.)",
                    },
                    "remindBeforeMinutes": {
                        "type": "number",
                        "description": "Minutes before due date to remind (default: 10)",
                    },
                    "recurrenceEndDate": {
                        "type": "string",
                        "description": "End date for recurring reminders in ISO format",
                    },
                    "weeklyDays": {
                        "type": "array",
                        "items": {"type": "number"},
                        "description": "Days of week for weekly recurrence (1=Monday, 7=Sunday)",
                    },
                    "sharedWith": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "List of email addresses to share this reminder with",
                    },
                    "userId": {
                        "type": "string",
                        "description": "User ID or email (optional, uses USER_ID env var if not provided)",
                    },
                },
                "required": ["title"],
            },
        ),
        Tool(
            name="edit_reminder",
            description="Update an existing reminder",
            inputSchema={
                "type": "object",
                "properties": {
                    "reminderId": {
                        "type": "string",
                        "description": "The ID of the reminder to update (required)",
                    },
                    "title": {
                        "type": "string",
                        "description": "New reminder title",
                    },
                    "notes": {
                        "type": "string",
                        "description": "Updated notes or description",
                    },
                    "dueAt": {
                        "type": "string",
                        "description": "Updated due date/time in ISO format",
                    },
                    "recurrence": {
                        "type": "string",
                        "description": "Updated recurrence pattern",
                    },
                    "remindBeforeMinutes": {
                        "type": "number",
                        "description": "Updated reminder time in minutes",
                    },
                    "recurrenceEndDate": {
                        "type": "string",
                        "description": "Updated end date for recurring reminders",
                    },
                    "weeklyDays": {
                        "type": "array",
                        "items": {"type": "number"},
                        "description": "Updated days of week for weekly recurrence",
                    },
                    "sharedWith": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Updated list of email addresses to share with",
                    },
                    "userId": {
                        "type": "string",
                        "description": "User ID or email (optional, uses USER_ID env var if not provided)",
                    },
                },
                "required": ["reminderId"],
            },
        ),
        Tool(
            name="delete_reminder",
            description="Delete a reminder",
            inputSchema={
                "type": "object",
                "properties": {
                    "reminderId": {
                        "type": "string",
                        "description": "The ID of the reminder to delete (required)",
                    },
                    "userId": {
                        "type": "string",
                        "description": "User ID or email (optional, uses USER_ID env var if not provided)",
                    },
                },
                "required": ["reminderId"],
            },
        ),
        Tool(
            name="complete_reminder",
            description="Mark a reminder as completed",
            inputSchema={
                "type": "object",
                "properties": {
                    "reminderId": {
                        "type": "string",
                        "description": "The ID of the reminder to complete (required)",
                    },
                    "userId": {
                        "type": "string",
                        "description": "User ID or email (optional, uses USER_ID env var if not provided)",
                    },
                },
                "required": ["reminderId"],
            },
        ),
    ]


@mcp_server.call_tool()
async def call_tool(name: str, arguments: dict) -> str:
    """Call a tool"""
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
                dueAt=arguments.get("dueAt"),
                recurrence=arguments.get("recurrence"),
                remindBeforeMinutes=arguments.get("remindBeforeMinutes"),
                recurrenceEndDate=arguments.get("recurrenceEndDate"),
                weeklyDays=arguments.get("weeklyDays"),
                sharedWith=arguments.get("sharedWith"),
            )

        elif name == "delete_reminder":
            result = await service.delete_reminder(
                arguments["reminderId"], user_id
            )

        elif name == "complete_reminder":
            result = await service.complete_reminder(
                arguments["reminderId"], user_id
            )

        else:
            return json.dumps(
                create_error_response("UNKNOWN_TOOL", f"Unknown tool: {name}"),
                indent=2,
            )

        return json.dumps(create_success_response(result), indent=2)

    except Exception as error:
        if DEBUG:
            print(f"[DEBUG] Tool call error in {name}: {error}", file=sys.stderr)
        return json.dumps(
            create_error_response("TOOL_ERROR", str(error)),
            indent=2,
        )


# ============================================================================
# FastAPI Routes
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
    except Exception as error:
        print(f"Fatal error during startup: {error}", file=sys.stderr)
        raise


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "ok",
        "service": "aireminder-mcp-server",
        "version": "1.0.0",
    }


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "AI Reminder MCP Server (FastAPI)",
        "version": "1.0.0",
        "docs": "/docs",
        "openapi": "/openapi.json",
    }


# ============================================================================
# Main
# ============================================================================

if __name__ == "__main__":
    # Start FastAPI server with uvicorn
    uvicorn.run(
        "mcp_server:app",
        host="127.0.0.1",
        port=8000,
        reload=DEBUG,
        log_level="debug" if DEBUG else "info",
    )
