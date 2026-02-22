"""
Firebase Admin SDK initialization and configuration
"""

import os
import json
from typing import Optional, Any
import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

_db: Optional[Any] = None


def initialize_firebase() -> Any:
    """
    Initialize Firebase Admin SDK
    
    Returns:
        Firestore database instance
    """
    global _db
    
    if _db:
        return _db
    
    project_id = os.getenv("FIREBASE_PROJECT_ID")
    private_key = os.getenv("FIREBASE_PRIVATE_KEY")
    client_email = os.getenv("FIREBASE_CLIENT_EMAIL")
    
    if not all([project_id, private_key, client_email]):
        raise ValueError(
            "Missing Firebase configuration. Please set FIREBASE_PROJECT_ID, "
            "FIREBASE_PRIVATE_KEY, and FIREBASE_CLIENT_EMAIL in .env file"
        )
    
    # Create service account cert dict
    service_account_info = {
        "type": "service_account",
        "project_id": project_id,
        "private_key_id": "key-id",
        "private_key": private_key.replace("\\n", "\n"),
        "client_email": client_email,
        "client_id": "client-id",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    }
    
    # Initialize Firebase if not already done
    if not firebase_admin._apps:
        cred = credentials.Certificate(service_account_info)
        firebase_admin.initialize_app(cred)
    
    _db = firestore.client()
    return _db


def get_firestore() -> Any:
    """
    Get Firestore instance, initializing if necessary
    
    Returns:
        Firestore database instance
    """
    global _db
    
    if _db is None:
        initialize_firebase()
    
    return _db


async def test_connection() -> bool:
    """
    Test Firebase connection
    
    Returns:
        True if connection successful
    """
    try:
        db = get_firestore()
        # Try to get a test document
        db.collection("_test").document("_test").get()
        print("✓ Firebase connection successful")
        return True
    except Exception as error:
        print(f"✗ Firebase connection failed: {error}")
        return False


def close_connection() -> None:
    """
    Close Firebase connection
    """
    global _db
    
    if _db:
        _db._client.close()
        _db = None
