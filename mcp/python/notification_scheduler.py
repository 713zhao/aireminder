#!/usr/bin/env python3
"""
Notification Scheduler Service
Handles scheduled notifications via Telegram & WhatsApp

Features:
  - 7 AM daily summary of today's reminders
  - Pre-event reminders (configurable minutes before)
  - Multiple notification channels (Telegram, WhatsApp)
  - Persistent tracking to avoid duplicate notifications

Usage:
    python notification_scheduler.py
"""

import os
import sys
import json
import asyncio
from dateutil import parser as date_parser
from datetime import datetime, timedelta
from typing import List, Dict, Optional, Set
from dotenv import load_dotenv
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger
import logging

from firebase_config import get_firestore, initialize_firebase
import reminders_service as service
from telegram_notifier import TelegramNotifier
from whatsapp_notifier import WhatsAppNotifier
from utils import is_today, is_past

# Load environment variables
load_dotenv()

# Logging configuration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration
USER_ID = os.getenv("USER_ID", "user@example.com")
MORNING_SUMMARY_HOUR = int(os.getenv("MORNING_SUMMARY_HOUR", "7"))
MORNING_SUMMARY_MINUTE = int(os.getenv("MORNING_SUMMARY_MINUTE", "0"))
PRE_EVENT_REMINDER_MINUTES = int(os.getenv("PRE_EVENT_REMINDER_MINUTES", "15"))
NOTIFICATION_CHECK_INTERVAL_SECONDS = int(os.getenv("NOTIFICATION_CHECK_INTERVAL_SECONDS", "60"))

# Notification channels
ENABLE_TELEGRAM = os.getenv("ENABLE_TELEGRAM", "true").lower() == "true"
ENABLE_WHATSAPP = os.getenv("ENABLE_WHATSAPP", "true").lower() == "true"

# Track which reminders have been sent pre-event notifications
_notified_reminders: Set[str] = set()
_notified_reminders_file = "notified_reminders.json"



def extract_time(due_datetime_str: str) -> str:
    """Extract time from dueDateTime string"""
    if not due_datetime_str:
        return "No time"
    try:
        parsed = date_parser.parse(due_datetime_str)
        return parsed.strftime("%I:%M %p")
    except:
        return "No time"


class NotificationScheduler:
    """Main scheduler for managing notifications"""

    def __init__(self):
        self.scheduler = BackgroundScheduler()
        self.telegram_notifier = None
        self.whatsapp_notifier = None
        self.is_running = False
        self._load_notified_reminders()

    async def initialize(self):
        """Initialize Firebase and notification channels"""
        try:
            logger.info("Initializing Firebase...")
            initialize_firebase()
            logger.info("✓ Firebase initialized")

            if ENABLE_TELEGRAM:
                logger.info("Initializing Telegram notifier...")
                self.telegram_notifier = TelegramNotifier()
                await self.telegram_notifier.initialize()
                logger.info("✓ Telegram notifier ready")

            if ENABLE_WHATSAPP:
                logger.info("Initializing WhatsApp notifier...")
                self.whatsapp_notifier = WhatsAppNotifier()
                await self.whatsapp_notifier.initialize()
                logger.info("✓ WhatsApp notifier ready")

        except Exception as e:
            logger.error(f"Initialization error: {e}")
            raise

    def start(self):
        """Start the scheduler"""
        if self.is_running:
            logger.warning("Scheduler already running")
            return

        logger.info("Starting notification scheduler...")

        # Schedule 7 AM daily summary
        self.scheduler.add_job(
            self._send_morning_summary,
            CronTrigger(
                hour=MORNING_SUMMARY_HOUR,
                minute=MORNING_SUMMARY_MINUTE,
                timezone="Asia/Singapore"
            ),
            id="morning_summary",
            name="Daily 7 AM Summary",
            replace_existing=True,
        )
        logger.info(
            f"✓ Scheduled morning summary at "
            f"{MORNING_SUMMARY_HOUR:02d}:{MORNING_SUMMARY_MINUTE:02d}"
        )

        # Schedule pre-event reminder checker
        self.scheduler.add_job(
            self._check_and_send_pre_event_reminders,
            IntervalTrigger(seconds=NOTIFICATION_CHECK_INTERVAL_SECONDS),
            id="pre_event_checker",
            name="Pre-Event Reminder Checker",
            replace_existing=True,
        )
        logger.info(
            f"✓ Scheduled pre-event reminder checker "
            f"(every {NOTIFICATION_CHECK_INTERVAL_SECONDS} seconds)"
        )

        self.scheduler.start()
        self.is_running = True
        logger.info("✅ Notification scheduler started successfully")

    def stop(self):
        """Stop the scheduler"""
        if not self.is_running:
            logger.warning("Scheduler not running")
            return

        self.scheduler.shutdown()
        self.is_running = False
        logger.info("Notification scheduler stopped")

    async def _send_morning_summary(self):
        """Send daily summary of today's reminders at 7 AM"""
        try:
            logger.info("Sending morning summary...")

            # Get today's reminders
            reminders = await service.get_today_reminders(USER_ID)

            if not reminders:
                message = "📅 Good morning! You have no reminders for today."
            else:
                # Format reminders
                message = "📅 **Good Morning! Today's Reminders:**\n\n"
                for i, reminder in enumerate(reminders, 1):
                    title = reminder.get("title", "Untitled")
                    recurrence = reminder.get("recurrence", "once")
                    # Format recurrence with emoji
                    recurrence_icon = "🔄" if recurrence != "once" else "📌"
                    due_datetime = reminder.get("dueDateTime", "")
                    time_str = extract_time(due_datetime)
                    message += f"{i}. **{title}**\n   ⏰ {time_str} ({recurrence_icon} {recurrence})\n"

            # Send via all enabled channels
            if self.telegram_notifier:
                await self.telegram_notifier.send_message(message)
                logger.info("✓ Morning summary sent via Telegram")

            if self.whatsapp_notifier:
                await self.whatsapp_notifier.send_message(message)
                logger.info("✓ Morning summary sent via WhatsApp")

        except Exception as e:
            logger.error(f"Error sending morning summary: {e}")

    async def _check_and_send_pre_event_reminders(self):
        """Check for upcoming reminders and send pre-event notifications"""
        try:
            # Get all reminders
            reminders = await service.get_all_reminders(USER_ID, status="pending")

            current_time = datetime.now()
            upcoming_threshold = current_time + timedelta(minutes=PRE_EVENT_REMINDER_MINUTES)

            for reminder in reminders:
                reminder_id = reminder.get("id")
                
                # Skip if already notified
                if reminder_id in _notified_reminders:
                    continue

                # Parse due time
                due_at_str = reminder.get("dueDateTime")
                if not due_at_str:
                    continue

                try:
                    due_at = parser.parse(due_at_str)
                except (ValueError, AttributeError, TypeError):
                    continue

                # Check if reminder is within the pre-event window
                if current_time < due_at <= upcoming_threshold:
                    await self._send_pre_event_reminder(reminder)
                    _notified_reminders.add(reminder_id)
                    self._save_notified_reminders()

        except Exception as e:
            logger.error(f"Error checking pre-event reminders: {e}")

    async def _send_pre_event_reminder(self, reminder: Dict):
        """Send pre-event reminder notification"""
        try:
            title = reminder.get("title", "Untitled")
            due_at = reminder.get("dueDateTime", "")
            notes = reminder.get("notes", "")

            # Calculate time until reminder
            try:
                due_dt = parser.parse(due_at)
                time_until = due_dt - datetime.now()
                minutes = int(time_until.total_seconds() / 60)
            except:
                minutes = PRE_EVENT_REMINDER_MINUTES

            message = (
                f"⏰ **Upcoming Reminder** ({minutes} min)\n\n"
                f"📌 **{title}**\n"
                f"⏱️ Starts at: {due_at}\n"
            )
            if notes:
                message += f"📝 {notes}\n"

            message += "\n🔔 Don't miss it!"

            # Send via all enabled channels
            if self.telegram_notifier:
                await self.telegram_notifier.send_message(message)
                logger.info(f"✓ Pre-event reminder sent via Telegram: {title}")

            if self.whatsapp_notifier:
                await self.whatsapp_notifier.send_message(message)
                logger.info(f"✓ Pre-event reminder sent via WhatsApp: {title}")

        except Exception as e:
            logger.error(f"Error sending pre-event reminder: {e}")

    def _load_notified_reminders(self):
        """Load previously notified reminders from file"""
        global _notified_reminders
        try:
            if os.path.exists(_notified_reminders_file):
                with open(_notified_reminders_file, "r") as f:
                    data = json.load(f)
                    _notified_reminders = set(data.get("notified_ids", []))
                    logger.info(f"Loaded {len(_notified_reminders)} previously notified reminders")
        except Exception as e:
            logger.error(f"Error loading notified reminders: {e}")

    def _save_notified_reminders(self):
        """Save notified reminders to file (for persistence)"""
        try:
            with open(_notified_reminders_file, "w") as f:
                json.dump({"notified_ids": list(_notified_reminders)}, f, indent=2)
        except Exception as e:
            logger.error(f"Error saving notified reminders: {e}")

    def reset_daily_notifications(self):
        """Reset pre-event notifications at end of day (called at midnight)"""
        global _notified_reminders
        _notified_reminders.clear()
        self._save_notified_reminders()
        logger.info("✓ Daily notifications reset for new day")


async def main():
    """Main entry point"""
    scheduler = NotificationScheduler()

    try:
        # Initialize
        await scheduler.initialize()

        # Start
        scheduler.start()

        # Add job to reset notifications at midnight
        scheduler.scheduler.add_job(
            scheduler.reset_daily_notifications,
            CronTrigger(hour=0, minute=0, timezone="Asia/Singapore"),
            id="daily_reset",
            name="Daily Reset",
            replace_existing=True,
        )

        logger.info("💚 Notification scheduler is running. Press Ctrl+C to stop.")

        # Keep running
        while True:
            await asyncio.sleep(1)

    except KeyboardInterrupt:
        logger.info("Shutting down...")
        scheduler.stop()
        sys.exit(0)
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        scheduler.stop()
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
