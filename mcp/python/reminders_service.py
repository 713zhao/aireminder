"""
Reminders service - Business logic for querying and filtering reminders
"""

from datetime import datetime
from typing import List, Dict, Any, Optional
from firebase_config import get_firestore
from utils import (
    sort_by_due_date,
    sort_by_priority,
    filter_by_status,
    search_reminders,
    format_reminder_for_llm,
    days_until,
    is_today,
    is_past,
    is_overdue,
    get_status,
)


async def get_all_reminders(
    user_id: str,
    status: str = "all",
    limit: Optional[int] = None,
    format_for_llm: bool = True,
) -> List[Dict[str, Any]]:
    """
    Get all reminders for a user
    
    Args:
        user_id: User email or ID
        status: 'pending', 'completed', or 'all'
        limit: Maximum number of reminders
        format_for_llm: Format for LLM consumption
        
    Returns:
        List of reminders
    """
    try:
        db = get_firestore()
        query = db.collection("shared_tasks").where("ownerId", "==", user_id)
        
        # Filter by completion status
        if status == "completed":
            query = query.where("isCompleted", "==", True)
        elif status == "pending":
            query = query.where("isCompleted", "==", False)
        
        docs = query.stream()
        reminders = [
            {
                "id": doc.id,
                **doc.to_dict(),
            }
            for doc in docs
        ]
        
        # Apply limit if specified
        if limit:
            reminders = reminders[:limit]
        
        # Format for LLM consumption if requested
        if format_for_llm:
            reminders = [format_reminder_for_llm(r) for r in reminders]
        
        return reminders
    except Exception as error:
        raise Exception(f"Error fetching reminders: {str(error)}")


async def get_upcoming_reminders(
    user_id: str,
    days: int = 7,
    sort_by: str = "priority",
    include_completed: bool = False,
    format_for_llm: bool = True,
) -> List[Dict[str, Any]]:
    """
    Get upcoming reminders for the next N days
    
    Args:
        user_id: User email or ID
        days: Number of days to look ahead
        sort_by: 'dueDate' or 'priority'
        include_completed: Include completed reminders
        format_for_llm: Format for LLM consumption
        
    Returns:
        List of upcoming reminders
    """
    try:
        db = get_firestore()
        now = datetime.now()
        future_date = datetime.fromtimestamp(
            now.timestamp() + (days * 24 * 3600)
        )
        
        query = (
            db.collection("shared_tasks")
            .where("ownerId", "==", user_id)
            .where("dueAt", ">=", now)
            .where("dueAt", "<=", future_date)
        )
        
        if not include_completed:
            query = query.where("isCompleted", "==", False)
        
        docs = query.stream()
        reminders = [
            {
                "id": doc.id,
                **doc.to_dict(),
            }
            for doc in docs
        ]
        
        # Sort results
        if sort_by == "dueDate":
            reminders = sort_by_due_date(reminders, "asc")
        elif sort_by == "priority":
            reminders = sort_by_priority(reminders)
        
        # Format for LLM consumption if requested
        if format_for_llm:
            reminders = [format_reminder_for_llm(r) for r in reminders]
        
        return reminders
    except Exception as error:
        raise Exception(f"Error fetching upcoming reminders: {str(error)}")


async def get_today_reminders(
    user_id: str,
    include_completed: bool = False,
    format_for_llm: bool = True,
) -> List[Dict[str, Any]]:
    """
    Get reminders due today
    
    Args:
        user_id: User email or ID
        include_completed: Include completed reminders
        format_for_llm: Format for LLM consumption
        
    Returns:
        List of today's reminders
    """
    try:
        reminders = await get_all_reminders(
            user_id,
            status="all" if include_completed else "pending",
            format_for_llm=False,
        )
        
        today_reminders = [r for r in reminders if is_today(r.get("dueAt"))]
        
        # Format for LLM consumption if requested
        if format_for_llm:
            today_reminders = [format_reminder_for_llm(r) for r in today_reminders]
        
        return today_reminders
    except Exception as error:
        raise Exception(f"Error fetching today reminders: {str(error)}")


async def get_overdue_reminders(
    user_id: str,
    format_for_llm: bool = True,
) -> List[Dict[str, Any]]:
    """
    Get overdue reminders
    
    Args:
        user_id: User email or ID
        format_for_llm: Format for LLM consumption
        
    Returns:
        List of overdue reminders
    """
    try:
        reminders = await get_all_reminders(
            user_id,
            status="pending",
            format_for_llm=False,
        )
        
        overdue_reminders = [r for r in reminders if is_overdue(r)]
        
        # Format for LLM consumption if requested
        if format_for_llm:
            overdue_reminders = [format_reminder_for_llm(r) for r in overdue_reminders]
        
        return overdue_reminders
    except Exception as error:
        raise Exception(f"Error fetching overdue reminders: {str(error)}")


async def get_reminder_by_id(
    reminder_id: str,
    user_id: str,
    format_for_llm: bool = True,
) -> Dict[str, Any]:
    """
    Get a specific reminder by ID
    
    Args:
        reminder_id: Reminder ID
        user_id: User email or ID (for validation)
        format_for_llm: Format for LLM consumption
        
    Returns:
        Reminder object
    """
    try:
        db = get_firestore()
        doc = db.collection("shared_tasks").document(reminder_id).get()
        
        if not doc.exists:
            raise Exception("Reminder not found")
        
        reminder = {
            "id": doc.id,
            **doc.to_dict(),
        }
        
        # Verify ownership
        if (
            reminder.get("ownerId") != user_id
            and user_id not in (reminder.get("sharedWith") or [])
        ):
            raise Exception("Access denied")
        
        if format_for_llm:
            return format_reminder_for_llm(reminder)
        
        return reminder
    except Exception as error:
        raise Exception(f"Error fetching reminder: {str(error)}")


async def search_user_reminders(
    user_id: str,
    query: str,
    status: str = "all",
    limit: Optional[int] = None,
    format_for_llm: bool = True,
) -> List[Dict[str, Any]]:
    """
    Search reminders
    
    Args:
        user_id: User email or ID
        query: Search query
        status: 'pending', 'completed', or 'all'
        limit: Maximum results
        format_for_llm: Format for LLM consumption
        
    Returns:
        List of matching reminders
    """
    try:
        reminders = await get_all_reminders(
            user_id,
            status=status,
            format_for_llm=False,
        )
        
        reminders = search_reminders(reminders, query)
        
        if limit:
            reminders = reminders[:limit]
        
        if format_for_llm:
            reminders = [format_reminder_for_llm(r) for r in reminders]
        
        return reminders
    except Exception as error:
        raise Exception(f"Error searching reminders: {str(error)}")


async def get_reminders_summary(user_id: str) -> Dict[str, Any]:
    """
    Get reminders summary for a user
    
    Args:
        user_id: User email or ID
        
    Returns:
        Summary statistics
    """
    try:
        reminders = await get_all_reminders(
            user_id,
            status="all",
            format_for_llm=False,
        )
        
        completed = [r for r in reminders if r.get("isCompleted")]
        pending = [r for r in reminders if not r.get("isCompleted")]
        overdue = [r for r in pending if r.get("dueAt") and is_past(r["dueAt"])]
        due_today = [
            r for r in reminders
            if r.get("dueAt") and is_today(r["dueAt"]) and not r.get("isCompleted")
        ]
        upcoming = [r for r in pending if r.get("dueAt") and not is_past(r["dueAt"])]
        
        return {
            "total": len(reminders),
            "completed": len(completed),
            "pending": len(pending),
            "overdue": len(overdue),
            "dueToday": len(due_today),
            "upcoming": len(upcoming),
            "completionRate": (
                round((len(completed) / len(reminders)) * 100, 1) if reminders else 0
            ),
        }
    except Exception as error:
        raise Exception(f"Error generating summary: {str(error)}")


async def get_shared_reminders(
    user_id: str,
    format_for_llm: bool = True,
) -> List[Dict[str, Any]]:
    """
    Get shared reminders for a user
    
    Args:
        user_id: User email or ID
        format_for_llm: Format for LLM consumption
        
    Returns:
        List of shared reminders
    """
    try:
        db = get_firestore()
        docs = db.collection("shared_tasks").where(
            "sharedWith", "array-contains", user_id
        ).stream()
        
        reminders = [
            {
                "id": doc.id,
                **doc.to_dict(),
            }
            for doc in docs
        ]
        
        if format_for_llm:
            reminders = [format_reminder_for_llm(r) for r in reminders]
        
        return reminders
    except Exception as error:
        raise Exception(f"Error fetching shared reminders: {str(error)}")


async def create_reminder(
    user_id: str,
    title: str,
    notes: Optional[str] = None,
    due_at: Optional[str] = None,
    recurrence: Optional[str] = None,
    remind_before_minutes: int = 10,
    recurrence_end_date: Optional[str] = None,
    weekly_days: Optional[List[int]] = None,
    shared_with: Optional[List[str]] = None,
    format_for_llm: bool = True,
) -> Dict[str, Any]:
    """
    Create a new reminder
    
    Args:
        user_id: User email or ID (owner)
        title: Reminder title
        notes: Optional notes
        due_at: Due date/time in ISO format
        recurrence: Recurrence pattern
        remind_before_minutes: Minutes before to remind
        recurrence_end_date: Recurrence end date
        weekly_days: Weekly recurrence days
        shared_with: List of emails to share with
        format_for_llm: Format for LLM consumption
        
    Returns:
        Created reminder object
    """
    try:
        if not title or not title.strip():
            raise ValueError("Title is required")
        
        db = get_firestore()
        now = datetime.now()
        
        reminder_data = {
            "title": title.strip(),
            "notes": notes.strip() if notes else None,
            "createdAt": now,
            "updatedAt": now,
            "ownerId": user_id,
            "isCompleted": False,
            "completedAt": None,
            "isDisabled": False,
            "disabledUntil": None,
            "remindBeforeMinutes": remind_before_minutes,
            "dueAt": datetime.fromisoformat(due_at.replace("Z", "+00:00")) if due_at else None,
            "recurrence": recurrence or None,
            "recurrenceEndDate": (
                datetime.fromisoformat(recurrence_end_date.replace("Z", "+00:00"))
                if recurrence_end_date
                else None
            ),
            "weeklyDays": weekly_days or None,
            "isShared": bool(shared_with and len(shared_with) > 0),
            "sharedWith": shared_with or [],
            "lastModifiedBy": user_id,
            "deleted": False,
            "version": 1,
        }
        
        doc_ref = db.collection("shared_tasks").add(reminder_data)
        
        reminder = {
            "id": doc_ref[1].id,
            **reminder_data,
        }
        
        if format_for_llm:
            return format_reminder_for_llm(reminder)
        
        return reminder
    except Exception as error:
        raise Exception(f"Error creating reminder: {str(error)}")


async def update_reminder(
    reminder_id: str,
    user_id: str,
    **updates,
) -> Dict[str, Any]:
    """
    Update an existing reminder
    
    Args:
        reminder_id: Reminder ID
        user_id: User email or ID (must be owner)
        **updates: Fields to update
        
    Returns:
        Updated reminder object
    """
    try:
        format_for_llm = updates.pop("format_for_llm", True)
        
        db = get_firestore()
        reminder_ref = db.collection("shared_tasks").document(reminder_id)
        doc = reminder_ref.get()
        
        if not doc.exists:
            raise Exception("Reminder not found")
        
        reminder = doc.to_dict()
        
        # Verify ownership
        if reminder.get("ownerId") != user_id:
            raise Exception("Access denied: You can only edit your own reminders")
        
        # Validate title if being updated
        if "title" in updates and (not updates["title"] or not updates["title"].strip()):
            raise Exception("Title cannot be empty")
        
        # Prepare update data
        update_data = {
            **updates,
            "updatedAt": datetime.now(),
            "lastModifiedBy": user_id,
            "version": (reminder.get("version") or 0) + 1,
        }
        
        # Convert dates if provided
        if "dueAt" in update_data and update_data["dueAt"]:
            update_data["dueAt"] = datetime.fromisoformat(
                update_data["dueAt"].replace("Z", "+00:00")
            )
        elif "dueAt" in update_data:
            update_data["dueAt"] = None
        
        if "recurrenceEndDate" in update_data and update_data["recurrenceEndDate"]:
            update_data["recurrenceEndDate"] = datetime.fromisoformat(
                update_data["recurrenceEndDate"].replace("Z", "+00:00")
            )
        elif "recurrenceEndDate" in update_data:
            update_data["recurrenceEndDate"] = None
        
        # Update shared status based on sharedWith array
        if "sharedWith" in update_data:
            update_data["isShared"] = bool(
                update_data["sharedWith"] and len(update_data["sharedWith"]) > 0
            )
        
        reminder_ref.update(update_data)
        
        updated_reminder = {
            "id": reminder_id,
            **reminder,
            **update_data,
        }
        
        if format_for_llm:
            return format_reminder_for_llm(updated_reminder)
        
        return updated_reminder
    except Exception as error:
        raise Exception(f"Error updating reminder: {str(error)}")


async def delete_reminder(reminder_id: str, user_id: str) -> Dict[str, Any]:
    """
    Delete a reminder
    
    Args:
        reminder_id: Reminder ID
        user_id: User email or ID (must be owner)
        
    Returns:
        Success message
    """
    try:
        db = get_firestore()
        reminder_ref = db.collection("shared_tasks").document(reminder_id)
        doc = reminder_ref.get()
        
        if not doc.exists:
            raise Exception("Reminder not found")
        
        reminder = doc.to_dict()
        
        # Verify ownership
        if reminder.get("ownerId") != user_id:
            raise Exception("Access denied: You can only delete your own reminders")
        
        # Soft delete
        reminder_ref.update({
            "deleted": True,
            "deletedAt": datetime.now(),
            "lastModifiedBy": user_id,
            "version": (reminder.get("version") or 0) + 1,
        })
        
        return {
            "success": True,
            "message": f'Reminder "{reminder.get("title")}" deleted successfully',
            "reminderId": reminder_id,
        }
    except Exception as error:
        raise Exception(f"Error deleting reminder: {str(error)}")


async def complete_reminder(reminder_id: str, user_id: str) -> Dict[str, Any]:
    """
    Mark a reminder as completed
    
    Args:
        reminder_id: Reminder ID
        user_id: User email or ID (must be owner or has access)
        
    Returns:
        Completed reminder object
    """
    try:
        db = get_firestore()
        reminder_ref = db.collection("shared_tasks").document(reminder_id)
        doc = reminder_ref.get()
        
        if not doc.exists:
            raise Exception("Reminder not found")
        
        reminder = doc.to_dict()
        
        # Verify access
        if (
            reminder.get("ownerId") != user_id
            and user_id not in (reminder.get("sharedWith") or [])
        ):
            raise Exception(
                "Access denied: You do not have permission to complete this reminder"
            )
        
        now = datetime.now()
        
        reminder_ref.update({
            "isCompleted": True,
            "completedAt": now,
            "lastModifiedBy": user_id,
            "version": (reminder.get("version") or 0) + 1,
        })
        
        completed_reminder = {
            "id": reminder_id,
            **reminder,
            "isCompleted": True,
            "completedAt": now,
            "lastModifiedBy": user_id,
            "version": (reminder.get("version") or 0) + 1,
        }
        
        return format_reminder_for_llm(completed_reminder)
    except Exception as error:
        raise Exception(f"Error completing reminder: {str(error)}")
