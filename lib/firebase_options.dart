// Generated placeholder for Firebase options.
// Replace the values below with your Firebase project's config.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyC8N7gA8uFhu98mYre1cFqXBHDBDyN35Xg",
    authDomain: "reminder-cd1c5.firebaseapp.com",
    projectId: "reminder-cd1c5",
    storageBucket: "reminder-cd1c5.firebasestorage.app",
    messagingSenderId: "169294947687",
    appId: "1:169294947687:web:491911ff4ac28b7a76bbc2",
    measurementId: "G-X68FKQ4CSY"
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyC8N7gA8uFhu98mYre1cFqXBHDBDyN35Xg",
    appId: "1:169294947687:android:abc123def456android",
    messagingSenderId: "169294947687",
    projectId: "reminder-cd1c5",
    storageBucket: "reminder-cd1c5.firebasestorage.app",
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyC8N7gA8uFhu98mYre1cFqXBHDBDyN35Xg",
    appId: "1:169294947687:ios:abc123def456ios",
    messagingSenderId: "169294947687",
    projectId: "reminder-cd1c5",
    storageBucket: "reminder-cd1c5.firebasestorage.app",
    iosBundleId: 'com.aireminder',
  );
}

// Legacy support for existing code
const FirebaseOptions firebaseOptions = FirebaseOptions(
  apiKey: "AIzaSyC8N7gA8uFhu98mYre1cFqXBHDBDyN35Xg",
  authDomain: "reminder-cd1c5.firebaseapp.com",
  projectId: "reminder-cd1c5",
  storageBucket: "reminder-cd1c5.firebasestorage.app",
  messagingSenderId: "169294947687",
  appId: "1:169294947687:web:491911ff4ac28b7a76bbc2",
  measurementId: "G-X68FKQ4CSY"
);
