#!/usr/bin/env python3
"""
Telegram Notification Integration
Sends reminders via Telegram bot
"""

import os
import logging
from typing import Optional
from telegram import Bot
from telegram.error import TelegramError
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)


class TelegramNotifier:
    """Handles Telegram notifications"""

    def __init__(self):
        self.bot_token = os.getenv("TELEGRAM_BOT_TOKEN")
        self.chat_id = os.getenv("TELEGRAM_CHAT_ID")
        self.bot: Optional[Bot] = None

        if not self.bot_token:
            raise ValueError("TELEGRAM_BOT_TOKEN not configured in .env")
        if not self.chat_id:
            raise ValueError("TELEGRAM_CHAT_ID not configured in .env")

    async def initialize(self):
        """Initialize Telegram bot"""
        try:
            self.bot = Bot(token=self.bot_token)
            # Test connection
            me = await self.bot.get_me()
            logger.info(f"✓ Telegram bot connected: @{me.username}")
        except TelegramError as e:
            logger.error(f"Telegram initialization failed: {e}")
            raise

    async def send_message(self, message: str, parse_mode: str = "Markdown") -> bool:
        """
        Send a message via Telegram

        Args:
            message: Message text (supports Markdown formatting)
            parse_mode: "Markdown" or "HTML"

        Returns:
            True if successful, False otherwise
        """
        if not self.bot:
            logger.error("Telegram bot not initialized")
            return False

        try:
            await self.bot.send_message(
                chat_id=self.chat_id,
                text=message,
                parse_mode=parse_mode,
            )
            return True
        except TelegramError as e:
            logger.error(f"Error sending Telegram message: {e}")
            return False

    async def send_photo(self, photo_url: str, caption: str = "") -> bool:
        """
        Send a photo via Telegram

        Args:
            photo_url: URL of the photo
            caption: Optional caption text

        Returns:
            True if successful, False otherwise
        """
        if not self.bot:
            logger.error("Telegram bot not initialized")
            return False

        try:
            await self.bot.send_photo(
                chat_id=self.chat_id,
                photo=photo_url,
                caption=caption,
                parse_mode="Markdown",
            )
            return True
        except TelegramError as e:
            logger.error(f"Error sending Telegram photo: {e}")
            return False

    async def send_document(self, document_url: str, caption: str = "") -> bool:
        """
        Send a document via Telegram

        Args:
            document_url: URL of the document
            caption: Optional caption text

        Returns:
            True if successful, False otherwise
        """
        if not self.bot:
            logger.error("Telegram bot not initialized")
            return False

        try:
            await self.bot.send_document(
                chat_id=self.chat_id,
                document=document_url,
                caption=caption,
                parse_mode="Markdown",
            )
            return True
        except TelegramError as e:
            logger.error(f"Error sending Telegram document: {e}")
            return False
