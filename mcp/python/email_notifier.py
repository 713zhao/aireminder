#!/usr/bin/env python3
"""
Email Notification Integration
Sends reminders via email using SMTP
"""

import os
import logging
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import Optional
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)


class EmailNotifier:
    """Handles Email notifications via SMTP"""

    def __init__(self):
        self.smtp_server = os.getenv("SMTP_SERVER", "smtp.gmail.com")
        self.smtp_port = int(os.getenv("SMTP_PORT", "587"))
        self.sender_email = os.getenv("SENDER_EMAIL")
        self.sender_password = os.getenv("SENDER_PASSWORD")
        self.recipient_email = os.getenv("USER_ID")

        if not self.sender_email:
            raise ValueError("SENDER_EMAIL not configured in .env")
        if not self.sender_password:
            raise ValueError("SENDER_PASSWORD not configured in .env")
        if not self.recipient_email:
            raise ValueError("USER_ID (recipient email) not configured in .env")

    async def send_message(self, message: str, subject: str = "Reminder Alert") -> bool:
        """
        Send an email message
        
        Args:
            message: Email body text
            subject: Email subject line
            
        Returns:
            True if sent successfully, False otherwise
        """
        try:
            # Create message
            msg = MIMEMultipart()
            msg["From"] = self.sender_email
            msg["To"] = self.recipient_email
            msg["Subject"] = subject

            # Add body
            msg.attach(MIMEText(message, "plain"))

            # Send email
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.starttls()
                server.login(self.sender_email, self.sender_password)
                server.send_message(msg)

            logger.info(f"Email sent successfully to {self.recipient_email}")
            return True

        except smtplib.SMTPAuthenticationError as e:
            logger.error(f"Email authentication failed: {e}")
            return False
        except smtplib.SMTPException as e:
            logger.error(f"SMTP error occurred: {e}")
            return False
        except Exception as e:
            logger.error(f"Failed to send email: {e}")
            return False

    async def send_reminders_summary(self, reminders: list, date: str) -> bool:
        """
        Send a formatted summary of reminders via email
        
        Args:
            reminders: List of reminder dictionaries
            date: Date string for the summary
            
        Returns:
            True if sent successfully, False otherwise
        """
        try:
            # Format reminders
            reminder_text = f"📋 Reminders for {date}:\n\n"
            
            if not reminders:
                reminder_text += "No reminders scheduled for today.\n"
            else:
                for i, reminder in enumerate(reminders, 1):
                    title = reminder.get("title", "Untitled")
                    time = reminder.get("time", "Unknown time")
                    reminder_text += f"{i}. {title}\n   ⏰ {time}\n"

            subject = f"Daily Reminders - {date}"
            return await self.send_message(reminder_text, subject)

        except Exception as e:
            logger.error(f"Failed to send reminders summary: {e}")
            return False
