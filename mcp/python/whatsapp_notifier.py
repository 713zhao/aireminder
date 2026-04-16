#!/usr/bin/env python3
"""
WhatsApp notifier using Twilio API
"""

import os
import asyncio
from typing import Optional
from dotenv import load_dotenv

# Try to import Twilio
try:
    from twilio.rest import Client
    TWILIO_AVAILABLE = True
except ImportError:
    TWILIO_AVAILABLE = False

load_dotenv()


class WhatsAppNotifier:
    """Send WhatsApp messages via Twilio"""
    
    def __init__(self):
        self.account_sid = os.getenv("TWILIO_ACCOUNT_SID")
        self.auth_token = os.getenv("TWILIO_AUTH_TOKEN")
        self.from_number = os.getenv("TWILIO_WHATSAPP_FROM")
        # Support both variable names for flexibility
        self.to_number = os.getenv("WHATSAPP_TO_NUMBER") or os.getenv("WHATSAPP_RECIPIENT_PHONE")
        # Ensure phone number has whatsapp: prefix
        if self.to_number and not self.to_number.startswith("whatsapp:"):
            self.to_number = f"whatsapp:{self.to_number}"
        self.client = None
        self.is_initialized = False
        
    async def initialize(self) -> bool:
        """Initialize WhatsApp notifier"""
        if not TWILIO_AVAILABLE:
            print("ERROR: Twilio not installed. Run: pip install twilio")
            return False
        
        if not self.account_sid or not self.auth_token:
            print("ERROR: TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN not set in .env")
            return False
        
        if not self.from_number or not self.to_number:
            print("ERROR: TWILIO_WHATSAPP_FROM and WHATSAPP_TO_NUMBER not set in .env")
            return False
        
        try:
            self.client = Client(self.account_sid, self.auth_token)
            self.is_initialized = True
            return True
        except Exception as e:
            print(f"ERROR: Failed to initialize Twilio client: {e}")
            return False
    
    async def send_message(self, message: str, media_url: Optional[str] = None) -> bool:
        """Send a WhatsApp message"""
        if not self.is_initialized or not self.client:
            print("ERROR: WhatsApp notifier not initialized")
            return False
        
        try:
            if media_url:
                msg = self.client.messages.create(
                    from_=self.from_number,
                    to=self.to_number,
                    body=message,
                    media_url=media_url
                )
            else:
                msg = self.client.messages.create(
                    from_=self.from_number,
                    to=self.to_number,
                    body=message
                )
            
            print(f"Message sent with SID: {msg.sid}")
            return True
        except Exception as e:
            print(f"ERROR: Failed to send WhatsApp message: {e}")
            return False
