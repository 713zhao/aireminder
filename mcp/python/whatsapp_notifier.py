#!/usr/bin/env python3
"""
WhatsApp Notification Integration
Sends reminders via WhatsApp (using Twilio or WhatsApp Business API)

Supports two methods:
1. Twilio (easier setup, recommended)
2. WhatsApp Business API (more advanced)
"""

import os
import logging
from typing import Optional
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)


class WhatsAppNotifier:
    """Handles WhatsApp notifications"""

    def __init__(self):
        self.method = os.getenv("WHATSAPP_METHOD", "twilio").lower()
        self.enabled = os.getenv("ENABLE_WHATSAPP", "true").lower() == "true"

        if self.method == "twilio":
            self._init_twilio()
        elif self.method == "business":
            self._init_business_api()
        else:
            raise ValueError(f"Unknown WhatsApp method: {self.method}")

        self.client = None

    def _init_twilio(self):
        """Initialize Twilio WhatsApp integration"""
        try:
            from twilio.rest import Client

            self.account_sid = os.getenv("TWILIO_ACCOUNT_SID")
            self.auth_token = os.getenv("TWILIO_AUTH_TOKEN")
            self.from_number = os.getenv("TWILIO_WHATSAPP_FROM")
            self.to_number = os.getenv("WHATSAPP_RECIPIENT_PHONE")

            if not all([self.account_sid, self.auth_token, self.from_number, self.to_number]):
                raise ValueError("Missing Twilio WhatsApp credentials in .env")

            self.client_class = Client
            self.method_name = "twilio"
            logger.info("✓ Twilio WhatsApp notifier configured")

        except ImportError:
            logger.error("twilio package not installed. Install with: pip install twilio")
            raise

    def _init_business_api(self):
        """Initialize WhatsApp Business API integration"""
        try:
            import requests

            self.api_url = os.getenv("WHATSAPP_BUSINESS_API_URL")
            self.business_phone_id = os.getenv("WHATSAPP_BUSINESS_PHONE_ID")
            self.business_access_token = os.getenv("WHATSAPP_BUSINESS_ACCESS_TOKEN")
            self.recipient_phone = os.getenv("WHATSAPP_RECIPIENT_PHONE")

            if not all([
                self.api_url,
                self.business_phone_id,
                self.business_access_token,
                self.recipient_phone,
            ]):
                raise ValueError("Missing WhatsApp Business API credentials in .env")

            self.requests = requests
            self.method_name = "business"
            logger.info("✓ WhatsApp Business API notifier configured")

        except ImportError:
            logger.error("requests package not installed. Install with: pip install requests")
            raise

    async def initialize(self):
        """Initialize WhatsApp connection"""
        try:
            if self.method == "twilio":
                self.client = self.client_class(self.account_sid, self.auth_token)
                logger.info("✓ Twilio WhatsApp connection initialized")
            elif self.method == "business":
                logger.info("✓ WhatsApp Business API connection ready")

        except Exception as e:
            logger.error(f"WhatsApp initialization failed: {e}")
            raise

    async def send_message(self, message: str) -> bool:
        """
        Send a message via WhatsApp

        Args:
            message: Message text

        Returns:
            True if successful, False otherwise
        """
        if not self.enabled:
            logger.warning("WhatsApp notifications disabled")
            return False

        try:
            if self.method == "twilio":
                return await self._send_twilio(message)
            elif self.method == "business":
                return await self._send_business_api(message)
        except Exception as e:
            logger.error(f"Error sending WhatsApp message: {e}")
            return False

    async def _send_twilio(self, message: str) -> bool:
        """Send via Twilio"""
        try:
            msg = self.client.messages.create(
                from_=self.from_number,
                body=message,
                to=self.to_number,
            )
            logger.info(f"✓ WhatsApp message sent via Twilio (SID: {msg.sid})")
            return True
        except Exception as e:
            logger.error(f"Twilio error: {e}")
            return False

    async def _send_business_api(self, message: str) -> bool:
        """Send via WhatsApp Business API"""
        try:
            url = (
                f"{self.api_url}/{self.business_phone_id}/messages"
            )

            headers = {
                "Authorization": f"Bearer {self.business_access_token}",
                "Content-Type": "application/json",
            }

            payload = {
                "messaging_product": "whatsapp",
                "recipient_type": "individual",
                "to": self.recipient_phone,
                "type": "text",
                "text": {"body": message},
            }

            response = self.requests.post(url, json=payload, headers=headers)

            if response.status_code == 200:
                logger.info("✓ WhatsApp message sent via Business API")
                return True
            else:
                logger.error(
                    f"WhatsApp Business API error: "
                    f"{response.status_code} - {response.text}"
                )
                return False

        except Exception as e:
            logger.error(f"WhatsApp Business API error: {e}")
            return False

    async def send_template_message(
        self, template_name: str, parameters: list = None
    ) -> bool:
        """
        Send a template message (WhatsApp Business API only)

        Args:
            template_name: Name of the pre-approved template
            parameters: List of parameter values

        Returns:
            True if successful, False otherwise
        """
        if self.method != "business":
            logger.warning("Template messages only supported with Business API")
            return False

        try:
            url = (
                f"{self.api_url}/{self.business_phone_id}/messages"
            )

            headers = {
                "Authorization": f"Bearer {self.business_access_token}",
                "Content-Type": "application/json",
            }

            payload = {
                "messaging_product": "whatsapp",
                "to": self.recipient_phone,
                "type": "template",
                "template": {
                    "name": template_name,
                    "language": {"code": "en_US"},
                },
            }

            if parameters:
                payload["template"]["parameters"] = {"body": {"parameters": parameters}}

            response = self.requests.post(url, json=payload, headers=headers)

            if response.status_code == 200:
                logger.info(f"✓ WhatsApp template message sent: {template_name}")
                return True
            else:
                logger.error(
                    f"WhatsApp template error: "
                    f"{response.status_code} - {response.text}"
                )
                return False

        except Exception as e:
            logger.error(f"Error sending template message: {e}")
            return False
