"""
Utility functions for the MCP reminder server
"""

from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional


def format_date(date: Any) -> Optional[str]:
    """
    Format a date for display
    
    Args:
        date: Date object or ISO string
        
    Returns:
        Formatted date string
    """
    if not date:
        return None
    
    if isinstance(date, str):
        date = datetime.fromisoformat(date.replace("Z", "+00:00"))
    
    return date.strftime("%b %d, %Y")


def format_datetime(date: Any) -> Optional[str]:
    """
    Format a date and time for display
    
    Args:
        date: Date object or ISO string
        
    Returns:
        Formatted datetime string
    """
    if not date:
        return None
    
    if isinstance(date, str):
        date = datetime.fromisoformat(date.replace("Z", "+00:00"))
    
    return date.strftime("%b %d, %Y %I:%M %p")


def days_until(date: Any) -> Optional[int]:
    """
    Calculate days until a date
    
    Args:
        date: Date object or ISO string
        
    Returns:
        Number of days
    """
    if not date:
        return None
    
    if isinstance(date, str):
        date = datetime.fromisoformat(date.replace("Z", "+00:00"))
    
    today = datetime.now(date.tzinfo).replace(hour=0, minute=0, second=0, microsecond=0)
    target = date.replace(hour=0, minute=0, second=0, microsecond=0)
    
    diff = target - today
    return (diff.days) + (1 if diff.seconds > 0 else 0)


def is_today(date: Any) -> bool:
    """
    Check if a date is today
    
    Args:
        date: Date object or ISO string
        
    Returns:
        True if today
    """
    if not date:
        return False
    
    if isinstance(date, str):
        date = datetime.fromisoformat(date.replace("Z", "+00:00"))
    
    today = datetime.now(date.tzinfo).date()
    return date.date() == today


def is_past(date: Any) -> bool:
    """
    Check if a date is in the past
    
    Args:
        date: Date object or ISO string
        
    Returns:
        True if past
    """
    if not date:
        return False
    
    if isinstance(date, str):
        date = datetime.fromisoformat(date.replace("Z", "+00:00"))
    
    return date < datetime.now(date.tzinfo)


def is_overdue(reminder: Dict[str, Any]) -> bool:
    """
    Check if a reminder is overdue
    
    Args:
        reminder: Reminder object
        
    Returns:
        True if overdue
    """
    return (
        reminder.get("dueAt") 
        and not reminder.get("isCompleted") 
        and is_past(reminder["dueAt"])
    )


def get_status(reminder: Dict[str, Any]) -> str:
    """
    Get a human-readable status for a reminder
    
    Args:
        reminder: Reminder object
        
    Returns:
        Status string
    """
    if reminder.get("isCompleted"):
        return "completed"
    
    if not reminder.get("dueAt"):
        return "no-due-date"
    
    if is_overdue(reminder):
        return "overdue"
    
    if is_today(reminder["dueAt"]):
        return "due-today"
    
    days = days_until(reminder["dueAt"])
    if days and days <= 0:
        return "due-today"
    if days == 1:
        return "due-tomorrow"
    if days and days <= 7:
        return "due-this-week"
    
    return "upcoming"


def is_valid_reminder(reminder: Dict[str, Any]) -> bool:
    """
    Validate a reminder object
    
    Args:
        reminder: Reminder object
        
    Returns:
        True if valid
    """
    return (
        isinstance(reminder, dict)
        and reminder.get("id")
        and reminder.get("title")
        and reminder.get("createdAt")
    )


def format_reminder_for_llm(reminder: Dict[str, Any]) -> Dict[str, Any]:
    """
    Format a reminder for LLM consumption
    
    Args:
        reminder: Raw reminder object
        
    Returns:
        Formatted reminder object
    """
    return {
        "id": reminder.get("id"),
        "title": reminder.get("title"),
        "notes": reminder.get("notes") or "",
        "status": get_status(reminder),
        "dueDate": format_date(reminder.get("dueAt")),
        "dueDateTime": format_datetime(reminder.get("dueAt")),
        "daysUntil": days_until(reminder.get("dueAt")) if reminder.get("dueAt") else None,
        "isCompleted": reminder.get("isCompleted"),
        "completedAt": format_datetime(reminder.get("completedAt")),
        "recurrence": reminder.get("recurrence") or "none",
        "isShared": reminder.get("isShared") or False,
        "sharedWith": reminder.get("sharedWith") or [],
        "createdAt": format_datetime(reminder.get("createdAt")),
        "isDisabled": reminder.get("isDisabled") or False,
    }


def sort_by_due_date(
    reminders: List[Dict[str, Any]], 
    order: str = "asc"
) -> List[Dict[str, Any]]:
    """
    Sort reminders by due date
    
    Args:
        reminders: List of reminders
        order: 'asc' or 'desc'
        
    Returns:
        Sorted list
    """
    def get_sort_key(r: Dict[str, Any]) -> float:
        if not r.get("dueAt"):
            return float("inf")
        due = r["dueAt"]
        if isinstance(due, str):
            due = datetime.fromisoformat(due.replace("Z", "+00:00"))
        return due.timestamp()
    
    return sorted(reminders, key=get_sort_key, reverse=(order == "desc"))


def sort_by_priority(reminders: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Sort reminders by status priority
    
    Args:
        reminders: List of reminders
        
    Returns:
        Sorted list
    """
    priority_map = {
        "overdue": 0,
        "due-today": 1,
        "due-tomorrow": 2,
        "due-this-week": 3,
        "upcoming": 4,
        "no-due-date": 5,
        "completed": 6,
    }
    
    def get_priority(r: Dict[str, Any]) -> int:
        return priority_map.get(get_status(r), 99)
    
    return sorted(reminders, key=get_priority)


def filter_by_status(
    reminders: List[Dict[str, Any]], 
    status: str = "all"
) -> List[Dict[str, Any]]:
    """
    Filter reminders by status
    
    Args:
        reminders: List of reminders
        status: 'pending', 'completed', or 'all'
        
    Returns:
        Filtered list
    """
    if status == "pending":
        return [r for r in reminders if not r.get("isCompleted")]
    if status == "completed":
        return [r for r in reminders if r.get("isCompleted")]
    return reminders


def search_reminders(
    reminders: List[Dict[str, Any]], 
    query: str
) -> List[Dict[str, Any]]:
    """
    Search reminders by query
    
    Args:
        reminders: List of reminders
        query: Search string
        
    Returns:
        Matching reminders
    """
    if not query:
        return reminders
    
    q = query.lower()
    return [
        r for r in reminders
        if q in r.get("title", "").lower() or q in (r.get("notes") or "").lower()
    ]


def paginate(
    items: List[Any], 
    limit: int = 10, 
    offset: int = 0
) -> Dict[str, Any]:
    """
    Paginate results
    
    Args:
        items: List of items
        limit: Items per page
        offset: Starting offset
        
    Returns:
        Paginated result
    """
    return {
        "total": len(items),
        "limit": limit,
        "offset": offset,
        "items": items[offset : offset + limit],
    }


def create_error_response(code: str, message: str) -> Dict[str, Any]:
    """
    Create an error response
    
    Args:
        code: Error code
        message: Error message
        
    Returns:
        Error response object
    """
    return {
        "success": False,
        "error": {
            "code": code,
            "message": message,
        },
    }


def create_success_response(data: Any) -> Dict[str, Any]:
    """
    Create a success response
    
    Args:
        data: Response data
        
    Returns:
        Success response object
    """
    return {
        "success": True,
        "data": data,
    }
