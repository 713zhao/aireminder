#!/usr/bin/env python3
"""
Telegram diagnostic tool to debug token issues
"""
import asyncio
import sys
import os
from dotenv import load_dotenv

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from telegram import Bot
from telegram.error import InvalidToken, TelegramError

load_dotenv()

async def diagnose():
    token = os.getenv("TELEGRAM_BOT_TOKEN")
    chat_id = os.getenv("TELEGRAM_CHAT_ID")
    
    print("=" * 60)
    print("Telegram Diagnostic Tool")
    print("=" * 60)
    print(f"\nToken: {token[:30]}...")
    print(f"Chat ID: {chat_id}\n")
    
    # Test 1: Bot initialization
    print("1. Bot Initialization:")
    try:
        bot = Bot(token=token)
        print("   ✓ Bot object created")
    except Exception as e:
        print(f"   ✗ Failed: {e}")
        return
    
    # Test 2: Get bot info
    print("\n2. Get Bot Info (getMe):")
    try:
        me = await bot.get_me()
        print(f"   ✓ Bot name: @{me.username}")
        print(f"   ✓ Bot ID: {me.id}")
        print(f"   ✓ Is bot: {me.is_bot}")
    except InvalidToken as e:
        print(f"   ✗ Invalid token: {e}")
        return
    except TelegramError as e:
        print(f"   ✗ Telegram error: {e}")
        error_str = str(e)
        if "401" in error_str or "Unauthorized" in error_str:
            print("   Note: 401 Unauthorized - token may be revoked")
        return
    except Exception as e:
        print(f"   ✗ Unexpected error: {e}")
        return
    
    # Test 3: Send test message
    print("\n3. Send Test Message:")
    try:
        msg = await bot.send_message(
            chat_id=chat_id,
            text="✓ Telegram diagnostic test - SUCCESS!"
        )
        print(f"   ✓ Message sent successfully")
        print(f"   ✓ Message ID: {msg.message_id}")
    except Exception as e:
        print(f"   ✗ Failed: {e}")
        return
    
    print("\n" + "=" * 60)
    print("✓ ALL TELEGRAM TESTS PASSED")
    print("=" * 60)

asyncio.run(diagnose())
