import 'dart:async';
import 'package:hive/hive.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/app_globals.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../firebase_options.dart' as fo;
import '../models/task.dart';
import '../data/hive_task_repository.dart';

/// FirestoreSyncService
/// - Initializes Firebase (using generated firebase_options when available)
/// - Provides Google Sign-In + Firebase Auth integration
/// - Pushes individual tasks to a user's collection and listens for remote updates
/// - Falls back to a no-op mode when Firebase initialization fails so the app
///   can still run locally (useful for debugging and CI)
class FirestoreSyncService {
  FirestoreSyncService._private();
  static final FirestoreSyncService instance = FirestoreSyncService._private();

  final StreamController<String?> _userController = StreamController.broadcast();
  final StreamController<String> _statusController = StreamController.broadcast();

  Stream<String?> get userChanges => _userController.stream;
  Stream<String> get statusChanges => _statusController.stream;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  firestore.FirebaseFirestore? _fs;
  fb_auth.FirebaseAuth? _auth;
  bool _suspendLocalPush = false;

  Future<void> init() async {
    // Try to initialize Firebase with platform-specific options first, then fallback.
    try {
      await firebase_core.Firebase.initializeApp(options: fo.DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      try {
        await firebase_core.Firebase.initializeApp(options: fo.firebaseOptions);
      } catch (e2) {
        try {
          await firebase_core.Firebase.initializeApp();
        } catch (_) {
          _statusController.add('no-firebase');
          _initialized = false;
          return;
        }
      }
    }

    // Wire up Firebase instances
    _fs = firestore.FirebaseFirestore.instance;
    _auth = fb_auth.FirebaseAuth.instance;
    _initialized = true;
    _statusController.add('initialized');

    // Watch local Hive box for user-initiated changes and push them to server when signed-in.
    try {
      final box = Hive.box('tasks_box');
      box.watch().listen((event) async {
        // If we're programmatically applying server data, skip pushing back to server.
        if (_suspendLocalPush) return;
        if (!_initialized || _auth?.currentUser == null) return;
        try {
          if (event.deleted) {
            // local delete -> delete remote doc
            final uid = _auth!.currentUser!.uid;
            try {
              await _fs!.collection('users').doc(uid).collection('tasks').doc(event.key.toString()).delete();
            } catch (_) {}
          } else {
            final val = event.value as String?;
            if (val == null) return;
            try {
              final Map<String, dynamic> j = jsonDecode(val);
              final t = Task.fromJson(j);
              // Push the task to Firestore (creates/updates)
              await pushTask(t);
            } catch (_) {
              // value not JSON or parse failed: ignore (likely remote write)
            }
          }
        } catch (_) {}
      });
    } catch (_) {}

    // Listen for auth state changes and surface the email (or null)
    _auth!.authStateChanges().listen((fb_auth.User? u) {
      _userController.add(u?.email);
      _statusController.add('idle');
      // Debug logging
      try {
        // ignore: avoid_print
        print('[FirestoreSync] authStateChange: ${u?.email}');
      } catch (_) {}
      if (u != null) {
        // Start listening to remote changes for this user
          try {
            // Log the uid for easier debugging
            // ignore: avoid_print
            print('[FirestoreSync] signed-in uid: ${u.uid}');
          } catch (_) {}
          _startListening(u.uid);
        // After sign-in, always pull the canonical copy from the server and overwrite local storage.
        try {
          // Replace local data with server data in background
          unawaited(overwriteLocalWithRemote());
        } catch (_) {}
      }
    });
  }

  /// Performs a lightweight sign-in used for testing and to unlock Firestore.
  ///
  /// If Firebase failed to initialize, this falls back to a demo user. If
  /// Firebase is available we use anonymous auth so the app can exercise
  /// protected Firestore paths during development without OAuth setup.
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    if (!_initialized) {
      // fallback: emit demo user for UI flows
      _userController.add('demo@example.com');
      _statusController.add('idle');
      return {'email': 'demo@example.com'};
    }

    try {
      _statusController.add('signing-in');
      if (kIsWeb) {
        // Use the browser popup flow on web which requires the OAuth client
        // to be configured in the Firebase console (Authorized domains).
        final provider = fb_auth.GoogleAuthProvider();
        final userCred = await _auth!.signInWithPopup(provider);
        final email = userCred.user?.email;
        _userController.add(email);
        _statusController.add('idle');
        _statusController.add('idle');
        try {
          // ignore: avoid_print
          print('[FirestoreSync] signIn success: $email');
        } catch (_) {}
        return {'email': email};
      } else {
        // Mobile platforms: Use Google Sign-In with Firebase Auth
        try {
          // For now, use Google Auth Provider directly without google_sign_in package
          // This requires the user to sign in through Firebase's built-in Google provider
          final provider = fb_auth.GoogleAuthProvider();
          provider.addScope('email');
          provider.setCustomParameters({'login_hint': 'user@example.com'});
          
          // This will use the system's Google account picker on Android
          final userCred = await _auth!.signInWithProvider(provider);
          final email = userCred.user?.email;
          _userController.add(email);
          _statusController.add('idle');
          
          print('[FirestoreSync] Google sign-in success: $email');
          return {'email': email};
        } catch (googleError) {
          print('[FirestoreSync] Google sign-in failed, trying anonymous: $googleError');
          
          // Fallback to anonymous sign-in if Google sign-in fails
          try {
            final userCred = await _auth!.signInAnonymously();
            final uid = userCred.user?.uid;
            final label = 'anonymous-user';
            _userController.add(label);
            _statusController.add('idle');
            print('[FirestoreSync] Anonymous fallback success: $uid');
            return {'email': label, 'uid': uid};
          } catch (anonymousError) {
            // If both fail, work offline
            print('[FirestoreSync] All sign-in methods failed, working offline');
            _userController.add('offline-user@local');
            _statusController.add('idle');
            return {'email': 'offline-user@local'};
          }
        }
      }
    } on fb_auth.FirebaseAuthException catch (e) {
      _statusController.add('error');
      try {
        // ignore: avoid_print
        print('[FirestoreSync] signIn error (FirebaseAuthException): ${e.code} ${e.message}');
      } catch (_) {}
      // Map a couple of well-known errors to clearer messages
      if (e.code == 'configuration-not-found') {
        throw Exception('configuration-not-found');
      }
      if (e.code == 'popup-closed-by-user') {
        throw Exception('popup-closed-by-user');
      }
      if (e.code == 'admin-restricted-operation') {
        // Firebase auth not properly configured - work in offline mode
        print('[FirestoreSync] Firebase auth not configured, working offline');
        _userController.add('offline-user@local');
        _statusController.add('idle');
        return {'email': 'offline-user@local'};
      }
      // For network-related failures, restore local backup so the app can work offline
      try {
        if (e.code.contains('network') || e.code.contains('offline')) {
          final repo = HiveTaskRepository();
          unawaited(repo.restoreFromBackup());
          try {
            final b = Hive.box('tasks_backup_box');
            final ts = b.get('backup_last_updated') as String?;
            final ctx = navigatorKey.currentContext;
            if (ctx != null) {
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Restored local backup (${ts ?? 'unknown time'})')));
            }
          } catch (_) {}
        }
      } catch (_) {}
      rethrow;
    } catch (e) {
      _statusController.add('error');
      try {
        // ignore: avoid_print
        print('[FirestoreSync] signIn error: $e');
      } catch (_) {}
      // Generic failures (likely network): restore local backup so user can continue offline
      try {
        final repo = HiveTaskRepository();
        unawaited(repo.restoreFromBackup());
        try {
          final b = Hive.box('tasks_backup_box');
          final ts = b.get('backup_last_updated') as String?;
          final ctx = navigatorKey.currentContext;
          if (ctx != null) {
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Restored local backup (${ts ?? 'unknown time'})')));
          }
        } catch (_) {}
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!_initialized) {
      _userController.add(null);
      _statusController.add('idle');
      return;
    }
    await _auth?.signOut();
    _userController.add(null);
    // Restore local backup on sign-out so offline data is available
    try {
      final repo = HiveTaskRepository();
      await repo.restoreFromBackup();
    } catch (_) {}
    _statusController.add('idle');
  }

  Future<void> syncNow() async {
    if (!_initialized || _auth?.currentUser == null) return;
    // For now, this is a light-weight manual trigger. Full bi-directional
    // sync and conflict resolution would be added later.
    // We could fetch remote docs here in future; for now, mark synced.
    _statusController.add('synced');
  }

  /// Fetch all remote tasks for the signed-in user.
  Future<List<Task>> fetchRemoteTasks() async {
    final out = <Task>[];
    if (!_initialized || _auth?.currentUser == null) return out;
    final uid = _auth!.currentUser!.uid;
    final snap = await _fs!.collection('users').doc(uid).collection('tasks').get();
    for (final doc in snap.docs) {
      try {
        final Map<String, dynamic> data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = data['id'] ?? doc.id;
        final t = Task.fromJson(data);
        out.add(t);
      } catch (_) {}
    }
    return out;
  }

  /// Overwrite local Hive storage with the server copy for the signed-in user.
  Future<void> overwriteLocalWithRemote() async {
    if (!_initialized || _auth?.currentUser == null) return;
    final box = Hive.box('tasks_box');
    final remote = await fetchRemoteTasks();
    // Clear local box then write remote tasks
    _suspendLocalPush = true;
    try {
      await box.clear();
      for (final t in remote) {
        await box.put(t.id, jsonEncode(t.toJson()));
      }
    } finally {
      _suspendLocalPush = false;
    }
    _statusController.add('synced-from-server');
  }

  /// Push all local tasks to Firestore (overwrites remote documents by id).
  Future<void> pushAllLocalToServer() async {
    if (!_initialized || _auth?.currentUser == null) return;
    final box = Hive.box('tasks_box');
    for (final val in box.values) {
      try {
        final Map<String, dynamic> j = jsonDecode(val as String);
        final t = Task.fromJson(j);
        await pushTask(t);
      } catch (_) {}
    }
    // After pushing, refresh local data from server to ensure canonical state
    final remote = await fetchRemoteTasks();
    // Upsert remote to local
    for (final t in remote) {
      await box.put(t.id, jsonEncode(t.toJson()));
    }
    _statusController.add('pushed-local-to-server');
  }

  Future<void> pushTask(Task t) async {
    if (!_initialized || _auth?.currentUser == null) return;
    final uid = _auth!.currentUser!.uid;
    final col = _fs!.collection('users').doc(uid).collection('tasks');
    final data = t.toJson();
    // Use task.id as document id to simplify mapping
    await col.doc(t.id).set(data, firestore.SetOptions(merge: true));
    try {
      // ignore: avoid_print
      print('[FirestoreSync] pushed task ${t.id} for uid=$uid');
    } catch (_) {}
  }

  StreamSubscription? _remoteSub;

  void _startListening(String uid) {
    _remoteSub?.cancel();
    final box = Hive.box('tasks_box');
    _remoteSub = _fs!
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .snapshots()
        .listen((snap) async {
      _statusController.add('remote-updates');
      try {
        // ignore: avoid_print
        print('[FirestoreSync] remote updates: ${snap.docChanges.length} changes');
      } catch (_) {}

      // Iterate all documents in the snapshot and upsert into local Hive box.
      // Prevent local watcher from echoing these server-applied writes back to Firestore
      _suspendLocalPush = true;
      try {
        for (final doc in snap.docs) {
          try {
            final Map<String, dynamic> data = Map<String, dynamic>.from(doc.data() as Map);
            // Ensure id field is present for Task parsing
            data['id'] = data['id'] ?? doc.id;
            final task = Task.fromJson(data);
            if (task.deleted) {
              // If remote marks deleted, remove locally
              await box.delete(task.id);
            } else {
              // Upsert local storage without triggering auto-push flows. Store as JSON so repository can parse.
              await box.put(task.id, jsonEncode(task.toJson()));
            }
          } catch (e) {
            // ignore parse errors for individual docs
            try {
              // ignore: avoid_print
              print('[FirestoreSync] remote doc parse error: $e');
            } catch (_) {}
          }
        }
      } finally {
        _suspendLocalPush = false;
      }
    }, onError: (e) {
      _statusController.add('error');
      // On listener errors (often network issues), restore local backup so app remains usable offline
      try {
        final repo = HiveTaskRepository();
        unawaited(repo.restoreFromBackup());
        try {
          final b = Hive.box('tasks_backup_box');
          final ts = b.get('backup_last_updated') as String?;
          final ctx = navigatorKey.currentContext;
          if (ctx != null) {
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Restored local backup (${ts ?? 'unknown time'})')));
          }
        } catch (_) {}
      } catch (_) {}
    });
  }

  /// Returns the signed-in user's email (if available) or null.
  String? get currentUserEmail => _auth?.currentUser?.email;

  /// Whether a user is currently signed in.
  bool get isSignedIn => _auth?.currentUser != null;
}
