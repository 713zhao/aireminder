/**
 * Firebase Admin SDK initialization and configuration
 */

import admin from 'firebase-admin';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

let db = null;

/**
 * Initialize Firebase Admin SDK
 * @returns {Object} Firestore database instance
 */
export function initializeFirebase() {
  if (db) {
    return db;
  }

  const projectId = process.env.FIREBASE_PROJECT_ID;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;

  if (!projectId || !privateKey || !clientEmail) {
    throw new Error(
      'Missing Firebase configuration. Please set FIREBASE_PROJECT_ID, FIREBASE_PRIVATE_KEY, and FIREBASE_CLIENT_EMAIL in .env file'
    );
  }

  // Initialize Firebase Admin SDK
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId,
      privateKey: privateKey.replace(/\\n/g, '\n'),
      clientEmail,
    }),
  });

  db = admin.firestore();
  return db;
}

/**
 * Get Firestore instance
 * @returns {Object}
 */
export function getFirestore() {
  if (!db) {
    initializeFirebase();
  }
  return db;
}

/**
 * Test Firebase connection
 * @returns {Promise<boolean>}
 */
export async function testConnection() {
  try {
    const firestore = getFirestore();
    const doc = await firestore.collection('_test').doc('_test').get();
    console.log('✓ Firebase connection successful');
    return true;
  } catch (error) {
    console.error('✗ Firebase connection failed:', error.message);
    return false;
  }
}

/**
 * Close Firebase connection
 * @returns {Promise<void>}
 */
export async function closeConnection() {
  if (db) {
    await db.terminate();
    db = null;
  }
}
