#!/usr/bin/env python3
"""
Quick verification script to check setup status
Run this anytime to verify your configuration
"""

import sys
import os
import asyncio

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from firebase_config import initialize_firebase
from telegram_notifier import TelegramNotifier
from dotenv import load_dotenv

load_dotenv()

def check_env_vars():
    """Check all environment variables are set"""
    print("\n1. Environment Variables:")
    required = {
        "FIREBASE_PROJECT_ID": os.getenv("FIREBASE_PROJECT_ID"),
        "FIREBASE_PRIVATE_KEY": "SET" if os.getenv("FIREBASE_PRIVATE_KEY") else "NOT SET",
        "FIREBASE_CLIENT_EMAIL": os.getenv("FIREBASE_CLIENT_EMAIL"),
        "TELEGRAM_BOT_TOKEN": os.getenv("TELEGRAM_BOT_TOKEN")[:40] + "..." if os.getenv("TELEGRAM_BOT_TOKEN") else "NOT SET",
        "TELEGRAM_CHAT_ID": os.getenv("TELEGRAM_CHAT_ID"),
    }
    
    for key, value in required.items():
        status = "✓" if value and value != "NOT SET" else "✗"
        print(f"   {status} {key}: {value}")
    
    return all(v and v != "NOT SET" for v in required.values())

def check_firebase():
    """Test Firebase connection"""
    print("\n2. Firebase Connection:")
    try:
        db = initialize_firebase()
        db.collection("_test").document("_test").get()
        print("   ✓ Firebase initialized")
        print("   ✓ Firestore connected")
        return True
    except Exception as e:
        print(f"   ✗ Firebase failed: {e}")
        return False

async def check_telegram():
    """Test Telegram connection"""
    print("\n3. Telegram Connection:")
    try:
        notifier = TelegramNotifier()
        await notifier.initialize()
        print("   ✓ Telegram bot initialized")
        print("   ✓ Bot is valid and active")
        return True
    except Exception as e:
        print(f"   ✗ Telegram failed: {e}")
        return False

async def main():
    print("="*60)
    print("Daily Summary Setup Verification")
    print("="*60)
    
    env_ok = check_env_vars()
    firebase_ok = check_firebase()
    telegram_ok = await check_telegram()
    
    print("\n" + "="*60)
    if env_ok and firebase_ok and telegram_ok:
        print("✓ ALL SYSTEMS READY")
        print("You can now run: python3 notification_scheduler.py")
        return 0
    elif env_ok and firebase_ok:
        print("⚠️ FIREBASE READY - TELEGRAM NEEDS UPDATE")
        print("Update TELEGRAM_BOT_TOKEN in .env and retry")
        return 1
    else:
        print("✗ SETUP INCOMPLETE")
        return 1

if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
