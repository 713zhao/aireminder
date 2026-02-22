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


def _merge_and_deduplicate_reminders(own_reminders: List[Dict], shared_reminders: List[Dict]) -> List[Dict]:
    """
    Merge own and shared reminders, deduplicating by ID
    
    Args:
        own_reminders: List of user's own reminders
        shared_reminders: List of reminders shared with the user
        
    Returns:
        Merged list without duplicates
    """
    seen_ids = set()
    merged = []
    
    # Add own reminders first
    for reminder in own_reminders:
        reminder_id = reminder.get("id")
        if reminder_id not in seen_ids:
            merged.append(reminder)
            seen_ids.add(reminder_id)
    
    # Add shared reminders (avoiding duplicates)
    for reminder in shared_reminders:
        reminder_id = reminder.get("id")
        if reminder_id not in seen_ids:
            merged.append(reminder)
            seen_ids.add(reminder_id)
    
    return merged


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
        
        docs = query.stream()
        reminders = [
            {
                "id": doc.id,
                **doc.to_dict(),
            }
            for doc in docs
        ]
        
        # Filter by completion status (in Python to handle None values)
        if status == "completed":
            reminders = [r for r in reminders if r.get("isCompleted") is True]
        elif status == "pending":
            # Include False and None as "pending"
            reminders = [r for r in reminders if not r.get("isCompleted")]
        
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
    Get upcoming reminders for the next N days (including shared reminders)
    
    Args:
        user_id: User email or ID
        days: Number of days to look ahead
        sort_by: 'dueDate' or 'priority'
        include_completed: Include completed reminders
        format_for_llm: Format for LLM consumption
        
    Returns:
        List of upcoming reminders (own + shared)
    """
    try:
        # Get user's own reminders
        own_reminders = await get_all_reminders(
            user_id,
            status="all" if include_completed else "pending",
            format_for_llm=False,
        )
        
        # Get shared reminders
        shared_reminders = await get_shared_reminders(
            user_id,
            format_for_llm=False,
        )
        
        # Filter shared reminders by completion status
        if not include_completed:
            shared_reminders = [r for r in shared_reminders if not r.get("isCompleted")]
        
        # Merge and deduplicate
        all_reminders = _merge_and_deduplicate_reminders(own_reminders, shared_reminders)
        
        # Filter to upcoming reminders by checking each day in the range
        upcoming_reminders = []
        today = datetime.now()
        from datetime import timedelta
        
        for day_offset in range(days):
            check_date = datetime(
                today.year, today.month, today.day
            ) + timedelta(days=day_offset)
            
            for reminder in all_reminders:
                # Use the Flutter algorithm to check if reminder matches this date
                if _matches_on_date(reminder, check_date):
                    # Only add if not already in list
                    if reminder.get("id") not in [r.get("id") for r in upcoming_reminders]:
                        upcoming_reminders.append(reminder)
        
        # Sort results
        if sort_by == "dueDate":
            upcoming_reminders = sort_by_due_date(upcoming_reminders, "asc")
        elif sort_by == "priority":
            upcoming_reminders = sort_by_priority(upcoming_reminders)
        
        # Format for LLM consumption if requested
        if format_for_llm:
            upcoming_reminders = [format_reminder_for_llm(r) for r in upcoming_reminders]
        
        return upcoming_reminders
    except Exception as error:
        raise Exception(f"Error fetching upcoming reminders: {str(error)}")


async def get_today_reminders(
    user_id: str,
    include_completed: bool = False,
    format_for_llm: bool = True,
) -> List[Dict[str, Any]]:
    """
    Get reminders due today (including shared reminders)
    
    Uses the SAME algorithm as Flutter's TasksForDate._matchesOnDate()
    
    Args:
        user_id: User email or ID
        include_completed: Include completed reminders
        format_for_llm: Format for LLM consumption
        
    Returns:
        List of today's reminders (own + shared)
    """
    try:
        # Get today's date normalized to midnight
        today = datetime.now()
        today_midnight = datetime(today.year, today.month, today.day)
        
        # Use get_reminders_for_date with today's date
        reminders = await get_reminders_for_date(
            user_id=user_id,
            date_str=today_midnight.isoformat(),
            include_completed=include_completed,
            format_for_llm=format_for_llm
        )
        
        return reminders
    except Exception as error:
        raise Exception(f"Error fetching today reminders: {str(error)}")


async def get_reminders_for_date(
    user_id: str,
    date_str: str,
    include_completed: bool = False,
    format_for_llm: bool = True,
) -> List[Dict[str, Any]]:
    """
    Get reminders for a specific date (including shared reminders)
    
    Uses the SAME algorithm as the Flutter app's TasksForDate._matchesOnDate()
    
    Args:
        user_id: User email or ID
        date_str: Date string in ISO format (e.g., '2026-02-22')
        include_completed: Include completed reminders
        format_for_llm: Format for LLM consumption
        
    Returns:
        List of reminders for that date (own + shared)
    """
    try:
        # Parse the date
        try:
            target_date = datetime.fromisoformat(date_str)
        except ValueError:
            raise Exception(f"Invalid date format: {date_str}. Use ISO format (YYYY-MM-DD or ISO-8601)")
        
        # Normalize target date to midnight (same as Flutter)
        target_date = datetime(target_date.year, target_date.month, target_date.day)
        
        # Get user's own reminders
        own_reminders = await get_all_reminders(
            user_id,
            status="all" if include_completed else "pending",
            format_for_llm=False,
        )
        
        # Get shared reminders
        shared_reminders = await get_shared_reminders(
            user_id,
            format_for_llm=False,
        )
        
        # Filter shared reminders by completion status
        if not include_completed:
            shared_reminders = [r for r in shared_reminders if not r.get("isCompleted")]
        
        # Merge and deduplicate
        all_reminders = _merge_and_deduplicate_reminders(own_reminders, shared_reminders)
        
        # Filter to specific date reminders using the SAME algorithm as Flutter
        date_reminders = [
            r for r in all_reminders 
            if _matches_on_date(r, target_date)
        ]
        
        # Sort by time of day (earliest first)
        date_reminders.sort(
            key=lambda r: _get_time_of_day(r.get("dueAt")),
            reverse=False
        )
        
        # Format for LLM consumption if requested
        if format_for_llm:
            date_reminders = [format_reminder_for_llm(r) for r in date_reminders]
        
        return date_reminders
    except Exception as error:
        raise Exception(f"Error fetching reminders for date: {str(error)}")


def _is_same_day(dt1: Any, dt2: datetime) -> bool:
    """Check if two datetime objects are on the same day"""
    if isinstance(dt1, str):
        try:
            dt1 = datetime.fromisoformat(dt1.replace("Z", "+00:00"))
        except (ValueError, AttributeError):
            return False
    
    if not isinstance(dt1, datetime) or not isinstance(dt2, datetime):
        return False
    
    return (
        dt1.year == dt2.year
        and dt1.month == dt2.month
        and dt1.day == dt2.day
    )


def _normalize_date_to_midnight(dt: Any) -> Optional[datetime]:
    """Normalize a datetime to midnight (same day, 00:00:00)"""
    if isinstance(dt, str):
        try:
            dt = datetime.fromisoformat(dt.replace("Z", "+00:00"))
        except (ValueError, AttributeError):
            return None
    
    if isinstance(dt, datetime):
        return datetime(dt.year, dt.month, dt.day)
    
    return None


def _get_time_of_day(dt: Any) -> int:
    """Extract time as minutes since midnight for sorting"""
    if isinstance(dt, str):
        try:
            dt = datetime.fromisoformat(dt.replace("Z", "+00:00"))
        except (ValueError, AttributeError):
            return 0
    
    if isinstance(dt, datetime):
        return dt.hour * 60 + dt.minute
    
    return 0


def _matches_on_date(reminder: Dict[str, Any], target_date: datetime) -> bool:
    """
    Check if a reminder should appear on a target date.
    
    Uses the SAME algorithm as Flutter's TasksForDate._matchesOnDate()
    This ensures consistency between frontend and backend.
    
    Args:
        reminder: Reminder/task dictionary
        target_date: Target date (should be normalized to midnight)
        
    Returns:
        True if reminder appears on this date
    """
    try:
        due_at = reminder.get("dueAt")
        if due_at is None:
            return False
        
        # Normalize due date to midnight
        due = _normalize_date_to_midnight(due_at)
        if due is None:
            return False
        
        # Ensure target is normalized to midnight
        if target_date.hour != 0 or target_date.minute != 0:
            target_date = datetime(target_date.year, target_date.month, target_date.day)
        
        # Check if target is before due date (and they're not the same day)
        if target_date < due and not _is_same_day(due, target_date):
            return False
        
        # Check if target date is after recurrence end date
        # Try both field names: recurrenceEnd (Firestore) and recurrenceEndDate (local)
        recurrence_end_date = reminder.get("recurrenceEnd") or reminder.get("recurrenceEndDate")
        if recurrence_end_date:
            end_date = _normalize_date_to_midnight(recurrence_end_date)
            if end_date and target_date > end_date:
                return False
        
        # Check recurrence pattern
        recurrence = reminder.get("recurrence")
        
        # No recurrence: must be exact same day
        if not recurrence:
            return _is_same_day(due, target_date)
        
        recurrence_lower = recurrence.lower().strip()
        
        # DAILY: Show on due date and every day after
        if recurrence_lower == "daily":
            return target_date >= due
        
        # WEEKLY: Show on specific weekdays
        elif recurrence_lower == "weekly":
            # Check if target is before due date
            if target_date < due:
                return False
            
            # If weeklyDays specified, check if target weekday is in the set
            weekly_days = reminder.get("weeklyDays")
            if weekly_days and isinstance(weekly_days, list) and len(weekly_days) > 0:
                # weeklyDays use Python/ISO weekday (Monday=1, Sunday=7)
                target_weekday = target_date.isoweekday()
                return target_weekday in weekly_days
            else:
                # Default: show on same weekday as due date
                return target_date.isoweekday() == due.isoweekday()
        
        # MONTHLY: Show on same day of month
        elif recurrence_lower == "monthly":
            return (due.day == target_date.day and target_date >= due)
        
        # YEARLY: Show on same month and day
        elif recurrence_lower == "yearly":
            return (
                due.month == target_date.month
                and due.day == target_date.day
                and target_date >= due
            )
        
        # Unknown recurrence: treat as no recurrence
        else:
            return _is_same_day(due, target_date)
    
    except Exception as e:
        # If any error, don't include the reminder
        return False


async def get_overdue_reminders(
    user_id: str,
    format_for_llm: bool = True,
) -> List[Dict[str, Any]]:
    """
    Get overdue reminders (including shared reminders)
    
    Args:
        user_id: User email or ID
        format_for_llm: Format for LLM consumption
        
    Returns:
        List of overdue reminders (own + shared)
    """
    try:
        # Get user's own reminders
        own_reminders = await get_all_reminders(
            user_id,
            status="pending",
            format_for_llm=False,
        )
        
        # Get shared reminders
        shared_reminders = await get_shared_reminders(
            user_id,
            format_for_llm=False,
        )
        
        # Filter shared reminders by pending status
        shared_reminders = [r for r in shared_reminders if not r.get("isCompleted")]
        
        # Merge and deduplicate
        all_reminders = _merge_and_deduplicate_reminders(own_reminders, shared_reminders)
        
        # Filter to overdue reminders
        overdue_reminders = [r for r in all_reminders if is_overdue(r)]
        
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
    Get reminders summary for a user (including shared reminders)
    
    Args:
        user_id: User email or ID
        
    Returns:
        Summary statistics
    """
    try:
        # Get user's own reminders
        own_reminders = await get_all_reminders(
            user_id,
            status="all",
            format_for_llm=False,
        )
        
        # Get shared reminders
        shared_reminders = await get_shared_reminders(
            user_id,
            format_for_llm=False,
        )
        
        # Merge and deduplicate
        reminders = _merge_and_deduplicate_reminders(own_reminders, shared_reminders)
        
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
            "sharedWith", "array_contains", user_id
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
