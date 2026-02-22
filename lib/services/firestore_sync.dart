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
  DateTime? _lastSuspensionTime;
  
  // Track recently pushed tasks to prevent duplicates
  final Set<String> _recentlyPushedTasks = <String>{};

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
        if (_suspendLocalPush) {
          // Check if suspension has been active for too long (failsafe)
          if (_lastSuspensionTime != null && 
              DateTime.now().difference(_lastSuspensionTime!).inSeconds > 10) {
            print('[FirestoreSync] Suspension timeout exceeded, re-enabling push');
            _suspendLocalPush = false;
            _lastSuspensionTime = null;
          } else {
            print('[FirestoreSync] Skipping push during server sync (suspension active): ${event.key}');
            return;
          }
        }
        if (!_initialized || _auth?.currentUser == null) return;
        
        final taskId = event.key.toString();
        
        // Prevent duplicate pushes for the same task within a short time window
        if (_recentlyPushedTasks.contains(taskId)) {
          print('[FirestoreSync] Skipping duplicate push (recently pushed): $taskId');
          return;
        }
        
        try {
          if (event.deleted) {
            // local delete -> delete remote doc
            final uid = _auth!.currentUser!.uid;
            print('[FirestoreSync] Pushing delete for task: $taskId');
            try {
              // Delete from owner's collection
              await _fs!.collection('users').doc(uid).collection('tasks').doc(taskId).delete();
            } catch (_) {}
            try {
              // Also delete from shared_tasks collection
              await _fs!.collection('shared_tasks').doc(taskId).delete();
            } catch (_) {}
          } else {
            final val = event.value as String?;
            if (val == null) return;
            try {
              final Map<String, dynamic> j = jsonDecode(val);
              final t = Task.fromJson(j);
              final currentUserEmail = _auth?.currentUser?.email;
              
              // Check if this is a shared task that we don't own
              final isSharedTaskWeReceived = t.isShared && t.ownerId != null && t.ownerId != currentUserEmail;
              
              if (isSharedTaskWeReceived) {
                print('[FirestoreSync] Skipping push for shared task we received: $taskId (owner: ${t.ownerId})');
                return;
              }
              
              // Mark as recently pushed to prevent loops
              _recentlyPushedTasks.add(taskId);
              
              // Check if task is marked as deleted (tombstone from signed-in delete)
              if (t.deleted) {
                print('[FirestoreSync] Deleting task marked as deleted: $taskId');
                final uid = _auth!.currentUser!.uid;
                bool deletedSuccessfully = false;
                
                try {
                  // Delete from owner's collection
                  await _fs!.collection('users').doc(uid).collection('tasks').doc(taskId).delete();
                  deletedSuccessfully = true;
                } catch (e) {
                  print('[FirestoreSync] Failed to delete from users collection: $e');
                }
                
                try {
                  // Also delete from shared_tasks collection
                  await _fs!.collection('shared_tasks').doc(taskId).delete();
                } catch (e) {
                  print('[FirestoreSync] Failed to delete from shared_tasks: $e');
                }
                
                // Only hard-delete from local Hive if Firebase deletion succeeded
                if (deletedSuccessfully) {
                  try {
                    await Hive.box('tasks_box').delete(taskId);
                    print('[FirestoreSync] Hard-deleted local tombstone: $taskId');
                  } catch (e) {
                    print('[FirestoreSync] Failed to hard-delete local tombstone: $e');
                  }
                }
              } else {
                print('[FirestoreSync] Pushing update for task: $taskId (user-initiated, owner: ${t.ownerId})');
                // Push the task to Firestore (creates/updates)
                await pushTask(t);
              }
              
              // Remove from recently pushed after a delay
              Future.delayed(const Duration(seconds: 2), () {
                _recentlyPushedTasks.remove(taskId);
              });
              
            } catch (_) {
              // value not JSON or parse failed: ignore (likely remote write)
              _recentlyPushedTasks.remove(taskId);
            }
          }
        } catch (_) {
          _recentlyPushedTasks.remove(taskId);
        }
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
        // Push any pending local changes to server before syncing from remote
        try {
          unawaited(_syncOnSignIn());
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
      throw Exception('firebase-not-initialized');
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
        // Mobile platforms: Enhanced compatibility for Huawei and other devices
        print('[FirestoreSync] Attempting mobile Google sign-in...');
        
        // Method 1: Try Firebase GoogleAuthProvider with enhanced Huawei compatibility
        try {
          final provider = fb_auth.GoogleAuthProvider();
          provider.addScope('email');
          provider.addScope('profile');
          
          // Add custom parameters for better Huawei compatibility
          provider.setCustomParameters({
            'prompt': 'select_account',
            'hd': '', // Allow any domain
            'include_granted_scopes': 'true',
          });
          
          print('[FirestoreSync] Trying GoogleAuthProvider for Huawei compatibility...');
          final userCred = await _auth!.signInWithProvider(provider);
          final email = userCred.user?.email;
          
          _userController.add(email);
          _statusController.add('idle');
          
          print('[FirestoreSync] Google sign-in success via provider: $email');
          return {'email': email};
          
        } catch (providerError) {
          print('[FirestoreSync] Provider method failed: $providerError');
          
          // Method 2: Try with different provider configuration for Huawei
          try {
            print('[FirestoreSync] Trying alternative provider config for Huawei...');
            final provider = fb_auth.GoogleAuthProvider();
            // Minimal scopes for Huawei compatibility
            provider.addScope('openid');
            provider.addScope('email');
            
            final userCred = await _auth!.signInWithProvider(provider);
            final email = userCred.user?.email;
            
            _userController.add(email);
            _statusController.add('idle');
            
            print('[FirestoreSync] Google sign-in success via alternative config: $email');
            return {'email': email};
            
          } catch (altError) {
            print('[FirestoreSync] Alternative method also failed: $altError');
            
            // Method 3: Try popup method as final fallback
            try {
              print('[FirestoreSync] Trying popup method as final fallback...');
              final provider = fb_auth.GoogleAuthProvider();
              final userCred = await _auth!.signInWithPopup(provider);
              final email = userCred.user?.email;
              
              _userController.add(email);
              _statusController.add('idle');
              
              print('[FirestoreSync] Google sign-in success via popup: $email');
              return {'email': email};
              
            } catch (popupError) {
              print('[FirestoreSync] All methods failed on this device');
              
              // Provide specific error messages for different scenarios
              String errorDetail = providerError.toString();
              if (errorDetail.contains('network') || errorDetail.contains('connectivity')) {
                throw Exception('network-error');
              } else if (errorDetail.contains('cancelled') || errorDetail.contains('user-cancelled')) {
                throw Exception('popup-closed-by-user');
              } else if (errorDetail.contains('huawei') || errorDetail.contains('hms')) {
                throw Exception('huawei-device-restriction');
              } else {
                throw Exception('google-signin-not-available-on-device');
              }
            }
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
              ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(SnackBar(content: Text('Restored local backup (${ts ?? 'unknown time'})')));
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
            ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(SnackBar(content: Text('Restored local backup (${ts ?? 'unknown time'})')));
          }
        } catch (_) {}
      } catch (_) {}
      rethrow;
    }
  }

  /// Sign in with email and password (works on all devices)
  Future<Map<String, dynamic>?> signInWithEmail(String email, String password) async {
    if (!_initialized) {
      throw Exception('firebase-not-initialized');
    }

    try {
      _statusController.add('signing-in');
      print('[FirestoreSync] Attempting email/password sign-in for: $email');
      
      final userCred = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final userEmail = userCred.user?.email;
      _userController.add(userEmail);
      _statusController.add('idle');
      
      print('[FirestoreSync] Email sign-in success: $userEmail');
      return {'email': userEmail};
    } catch (e) {
      _statusController.add('error');
      print('[FirestoreSync] Email sign-in failed: $e');
      rethrow;
    }
  }

  /// Create account with email and password
  Future<Map<String, dynamic>?> createAccountWithEmail(String email, String password) async {
    if (!_initialized) {
      throw Exception('firebase-not-initialized');
    }

    try {
      _statusController.add('signing-in');
      print('[FirestoreSync] Creating account for: $email');
      
      final userCred = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final userEmail = userCred.user?.email;
      final uid = userCred.user?.uid;
      
      // Create user document in Firestore
      if (uid != null && userEmail != null) {
        await _fs!.collection('users').doc(uid).set({
          'email': userEmail,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        }, firestore.SetOptions(merge: true));
        
        print('[FirestoreSync] Created Firestore user document for: $userEmail');
      }
      
      _userController.add(userEmail);
      _statusController.add('idle');
      
      print('[FirestoreSync] Account creation success: $userEmail');
      return {'email': userEmail};
    } catch (e) {
      _statusController.add('error');
      print('[FirestoreSync] Account creation failed: $e');
      rethrow;
    }
  }

  /// Sign in anonymously (no Google account required)
  Future<Map<String, dynamic>?> signInAnonymously() async {
    if (!_initialized) {
      throw Exception('firebase-not-initialized');
    }

    try {
      _statusController.add('signing-in');
      final userCred = await _auth!.signInAnonymously();
      final uid = userCred.user?.uid;
      final label = 'anonymous-user';
      _userController.add(label);
      _statusController.add('idle');
      print('[FirestoreSync] Anonymous sign-in success: $uid');
      return {'email': label, 'uid': uid};
    } catch (e) {
      _statusController.add('error');
      print('[FirestoreSync] Anonymous sign-in failed: $e');
      rethrow;
    }
  }

  /// Use offline mode (no authentication, local storage only)
  Future<Map<String, dynamic>?> useOfflineMode() async {
    _userController.add('offline-user@local');
    _statusController.add('idle');
    
    // Restore local backup when going offline
    try {
      final repo = HiveTaskRepository();
      await repo.restoreFromBackup();
      final b = Hive.box('tasks_backup_box');
      final ts = b.get('backup_last_updated') as String?;
      print('[FirestoreSync] Using offline mode, restored backup from: ${ts ?? 'unknown time'}');
    } catch (e) {
      print('[FirestoreSync] Offline mode activated, no backup available: $e');
    }
    
    return {'email': 'offline-user@local'};
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

  /// Manually sync family tasks (useful when auto-sync is disabled)
  Future<void> syncFamilyTasks() async {
    if (!_initialized || _auth?.currentUser == null) {
      throw Exception('Not signed in or Firebase not initialized');
    }
    
    try {
      print('[FirestoreSync] Manual family sync started');
      final userEmail = _auth!.currentUser!.email!;
      final box = Hive.box('tasks_box');
      
      // Get shared tasks manually
      final indexSnap = await _fs!
          .collection('sharing_index')
          .doc(userEmail)
          .collection('shared_tasks')
          .get();
      
      _suspendLocalPush = true;
      _lastSuspensionTime = DateTime.now();
      
      try {
        print('[FirestoreSync] Manual sync: Processing ${indexSnap.docs.length} shared task references');
        
        int updatedCount = 0;
        for (final indexDoc in indexSnap.docs) {
          try {
            final taskId = indexDoc.data()['taskId'] as String;
            
            // Get the latest version from shared_tasks collection
            final sharedTaskDoc = await _fs!.collection('shared_tasks').doc(taskId).get();
            if (sharedTaskDoc.exists) {
              final data = Map<String, dynamic>.from(sharedTaskDoc.data() as Map);
              data['id'] = data['id'] ?? sharedTaskDoc.id;
              final task = Task.fromJson(data);
              
              // Only process shared tasks that we don't own
              if (task.ownerId != userEmail) {
                // Check if it's actually different from local version
                final existingVal = box.get(task.id) as String?;
                final newJson = jsonEncode(task.toJson());
                
                if (task.deleted) {
                  await box.delete(task.id);
                  print('[FirestoreSync] Manual sync: Removed shared task: ${task.title}');
                  updatedCount++;
                } else if (existingVal != newJson) {
                  await box.put(task.id, newJson);
                  print('[FirestoreSync] Manual sync: Updated shared task: ${task.title} (from: ${task.ownerId})');
                  updatedCount++;
                }
              }
            }
          } catch (e) {
            print('[FirestoreSync] Error in manual sync: $e');
          }
        }
        
        _statusController.add('family-synced');
        print('[FirestoreSync] Manual family sync completed: $updatedCount tasks updated');
        
      } finally {
        Future.delayed(const Duration(milliseconds: 2000), () {
          _suspendLocalPush = false;
          _lastSuspensionTime = null;
          print('[FirestoreSync] Re-enabled local push after manual family sync');
        });
      }
    } catch (e) {
      _statusController.add('error');
      print('[FirestoreSync] Manual family sync failed: $e');
      throw Exception('Failed to sync family tasks: $e');
    }
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
    final allTasks = await fetchAllUserTasks(); // Fetch both owned and shared tasks
    // Clear local box then write all tasks
    _suspendLocalPush = true;
    try {
      await box.clear();
      for (final t in allTasks) {
        await box.put(t.id, jsonEncode(t.toJson()));
      }
    } finally {
      _suspendLocalPush = false;
    }
    _statusController.add('synced-from-server');
  }

  /// Sync local changes with server on sign-in.
  /// This method pushes any local changes to the server first, then performs a merge with remote data.
  Future<void> _syncOnSignIn() async {
    if (!_initialized || _auth?.currentUser == null) return;
    
    print('[FirestoreSync] Starting sign-in sync...');
    
    try {
      final box = Hive.box('tasks_box');
      final currentUserEmail = _auth?.currentUser?.email;
      
      // Step 1: Fetch remote tasks
      final remoteTasks = await fetchAllUserTasks();
      final remoteTasksMap = {for (var t in remoteTasks) t.id: t};
      
      // Step 2: Process local tasks - push updates if newer than remote
      _suspendLocalPush = true;
      try {
        for (final val in box.values) {
          try {
            final Map<String, dynamic> j = jsonDecode(val as String);
            final localTask = Task.fromJson(j);
            
            // Check if this is a task owned by current user or a local-only task
            final isOwnedByCurrentUser = localTask.ownerId == null || localTask.ownerId == currentUserEmail;
            
            if (isOwnedByCurrentUser) {
              final remoteTask = remoteTasksMap[localTask.id];
              
              if (remoteTask == null) {
                // Local task doesn't exist on server - push it
                print('[FirestoreSync] Pushing new local task to server: ${localTask.id}');
                await pushTask(localTask);
              } else {
                // Task exists on both - compare versions/timestamps
                final localUpdated = localTask.updatedAt ?? localTask.createdAt;
                final remoteUpdated = remoteTask.updatedAt ?? remoteTask.createdAt;
                
                if (localUpdated.isAfter(remoteUpdated)) {
                  // Local is newer - push to server
                  print('[FirestoreSync] Pushing updated local task to server: ${localTask.id}');
                  await pushTask(localTask);
                } else {
                  print('[FirestoreSync] Remote task is newer or same: ${localTask.id}');
                }
              }
            }
          } catch (e) {
            print('[FirestoreSync] Error processing local task during sync: $e');
          }
        }
      } finally {
        _suspendLocalPush = false;
      }
      
      // Step 3: Fetch updated remote data and merge with local
      final updatedRemoteTasks = await fetchAllUserTasks();
      _suspendLocalPush = true;
      try {
        for (final remoteTask in updatedRemoteTasks) {
          // Upsert remote tasks into local storage
          await box.put(remoteTask.id, jsonEncode(remoteTask.toJson()));
        }
      } finally {
        _suspendLocalPush = false;
      }
      
      _statusController.add('synced');
      print('[FirestoreSync] Sign-in sync completed successfully');
      
    } catch (e) {
      print('[FirestoreSync] Error during sign-in sync: $e');
      _statusController.add('sync-error');
    }
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
    final userEmail = _auth!.currentUser!.email;
    
    // Set ownership and modification info
    final taskData = t.toJson();
    if (taskData['ownerId'] == null) {
      taskData['ownerId'] = userEmail;
    }
    taskData['lastModifiedBy'] = userEmail;
    taskData['updatedAt'] = DateTime.now().toIso8601String();
    
    // Save to owner's collection
    final col = _fs!.collection('users').doc(uid).collection('tasks');
    await col.doc(t.id).set(taskData, firestore.SetOptions(merge: true));
    
    // ALWAYS save to shared tasks collection (for both shared and non-shared tasks)
    // This allows the MCP server to query all user tasks from a single collection
    final sharedTasksCol = _fs!.collection('shared_tasks');
    await sharedTasksCol.doc(t.id).set(taskData, firestore.SetOptions(merge: true));
    
    // If task is shared, also update sharing index for each shared user
    if (t.isShared && t.sharedWith != null && t.sharedWith!.isNotEmpty) {
      for (final sharedEmail in t.sharedWith!) {
        final sharingIndexCol = _fs!.collection('sharing_index').doc(sharedEmail).collection('shared_tasks');
        await sharingIndexCol.doc(t.id).set({
          'taskId': t.id,
          'ownerId': t.ownerId,
          'title': t.title,
          'updatedAt': taskData['updatedAt'],
        }, firestore.SetOptions(merge: true));
      }
    }
    
    try {
      // ignore: avoid_print
      print('[FirestoreSync] pushed task ${t.id} for uid=$uid, shared=${t.isShared}');
    } catch (_) {}
  }

  StreamSubscription? _remoteSub;
  StreamSubscription? _sharedSub;

  /// Restart sync listeners (useful when settings change)
  void restartSyncListeners() {
    if (!_initialized || _auth?.currentUser == null) return;
    
    print('[FirestoreSync] Restarting sync listeners with updated settings');
    
    // Restart listeners with current settings
    _startListening(_auth!.currentUser!.uid);
  }

  void _startListening(String uid) {
    _remoteSub?.cancel();
    _sharedSub?.cancel();
    final box = Hive.box('tasks_box');
    
    // Listen to user's own tasks
    _remoteSub = _fs!
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .snapshots()
        .listen((snap) async {
      await _processTaskUpdates(snap, box, 'own');
    }, onError: (e) {
      _handleListenError(e);
    });
    
    // Listen to shared tasks (tasks shared WITH the user)
    final userEmail = _auth!.currentUser!.email;
    if (userEmail != null) {
      print('[FirestoreSync] Setting up shared task listener');
      _sharedSub = _fs!
          .collection('sharing_index')
          .doc(userEmail)
          .collection('shared_tasks')
          .snapshots()
          .listen((indexSnap) async {
        // Batch process shared task changes to reduce sync storms
        _suspendLocalPush = true;
        _lastSuspensionTime = DateTime.now();
        
        try {
          print('[FirestoreSync] Processing ${indexSnap.docs.length} shared task references');
          
          for (final indexDoc in indexSnap.docs) {
            try {
              final taskId = indexDoc.data()['taskId'] as String;
              
              // Get the latest version from shared_tasks collection
              final sharedTaskDoc = await _fs!.collection('shared_tasks').doc(taskId).get();
              if (sharedTaskDoc.exists) {
                final data = Map<String, dynamic>.from(sharedTaskDoc.data() as Map);
                data['id'] = data['id'] ?? sharedTaskDoc.id;
                final task = Task.fromJson(data);
                
                // Only process shared tasks that we don't own
                if (task.ownerId != userEmail) {
                  // Check if it's actually different from local version
                  final existingVal = box.get(task.id) as String?;
                  final newJson = jsonEncode(task.toJson());
                  
                  if (task.deleted) {
                    await box.delete(task.id);
                    print('[FirestoreSync] Removed shared task: ${task.title}');
                  } else if (existingVal != newJson) {
                    await box.put(task.id, newJson);
                    print('[FirestoreSync] Updated shared task: ${task.title} (from: ${task.ownerId})');
                  }
                } else {
                  print('[FirestoreSync] Skipping own task in shared collection: ${task.title}');
                }
              }
            } catch (e) {
              print('[FirestoreSync] Error processing shared task: $e');
            }
          }
        } finally {
          // Extended delay for shared task processing to prevent loops
          Future.delayed(const Duration(milliseconds: 3000), () {
            _suspendLocalPush = false;
            _lastSuspensionTime = null;
            print('[FirestoreSync] Re-enabled local push after shared task batch sync');
          });
        }
      }, onError: (e) {
        _handleListenError(e);
      });
    }
  }

  Future<void> _processTaskUpdates(firestore.QuerySnapshot snap, dynamic box, String source) async {
    // Only process actual changes, not the initial snapshot load
    final hasChanges = snap.docChanges.isNotEmpty;
    if (!hasChanges && snap.docs.isNotEmpty) {
      print('[FirestoreSync] $source: Skipping initial snapshot (${snap.docs.length} docs)');
      return;
    }
    
    _statusController.add('remote-updates');
    print('[FirestoreSync] $source tasks updates: ${snap.docChanges.length} actual changes');

    // Only suspend for the duration of this update batch
    _suspendLocalPush = true;
    _lastSuspensionTime = DateTime.now();
    try {
      // Process only the changed documents, not all documents
      for (final change in snap.docChanges) {
        try {
          final doc = change.doc;
          final Map<String, dynamic> data = Map<String, dynamic>.from(doc.data() as Map? ?? {});
          
          if (data.isEmpty && change.type == firestore.DocumentChangeType.removed) {
            // Document was deleted
            await box.delete(doc.id);
            print('[FirestoreSync] Removed local task: ${doc.id}');
            continue;
          }
          
          // Ensure id field is present for Task parsing
          data['id'] = data['id'] ?? doc.id;
          final task = Task.fromJson(data);
          
          switch (change.type) {
            case firestore.DocumentChangeType.added:
              print('[FirestoreSync] Added remote task: ${task.id}');
              break;
            case firestore.DocumentChangeType.modified:
              print('[FirestoreSync] Modified remote task: ${task.id}');
              break;
            case firestore.DocumentChangeType.removed:
              print('[FirestoreSync] Removed remote task: ${task.id}');
              await box.delete(task.id);
              continue;
          }
          
          if (task.deleted) {
            // If remote marks deleted, remove locally
            await box.delete(task.id);
          } else {
            // Check if this is actually different from what we have locally
            final existingVal = box.get(task.id) as String?;
            final newJson = jsonEncode(task.toJson());
            
            if (existingVal != newJson) {
              await box.put(task.id, newJson);
              print('[FirestoreSync] Updated local task: ${task.id}');
            } else {
              print('[FirestoreSync] Skipping identical task: ${task.id}');
            }
          }
        } catch (e) {
          print('[FirestoreSync] Error processing remote change: $e');
        }
      }
    } finally {
      // Longer delay to prevent immediate re-triggering, especially for shared tasks
      Future.delayed(const Duration(milliseconds: 2000), () {
        _suspendLocalPush = false;
        _lastSuspensionTime = null;
        print('[FirestoreSync] Re-enabled local push after server sync (${source})');
      });
    }
  }

  void _handleListenError(dynamic e) {
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
          ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(SnackBar(content: Text('Restored local backup (${ts ?? 'unknown time'})')));
        }
      } catch (_) {}
    } catch (_) {}
  }

  /// Returns the signed-in user's email (if available) or null.
  String? get currentUserEmail => _auth?.currentUser?.email;

  /// Whether a user is currently signed in.
  bool get isSignedIn => _auth?.currentUser != null;

  /// Test Firestore permissions by trying to read/write to user's collection
  Future<bool> testFirestorePermissions() async {
    if (!_initialized || _auth?.currentUser == null) {
      return false;
    }

    try {
      final uid = _auth!.currentUser!.uid;
      final userEmail = _auth!.currentUser!.email!;
      
      print('[FirestoreSync] Testing permissions for user $userEmail (uid: $uid)');
      
      // Test 1: User's own tasks collection
      final testDoc = _fs!.collection('users').doc(uid).collection('tasks').doc('permission_test');
      await testDoc.set({
        'test': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
      final doc = await testDoc.get();
      await testDoc.delete();
      
      if (!doc.exists) {
        print('[FirestoreSync] Failed to write/read own tasks collection');
        return false;
      }
      
      // Test 2: Shared tasks collection
      final sharedTestDoc = _fs!.collection('shared_tasks').doc('permission_test');
      await sharedTestDoc.set({
        'ownerId': userEmail,
        'test': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
      final sharedDoc = await sharedTestDoc.get();
      await sharedTestDoc.delete();
      
      if (!sharedDoc.exists) {
        print('[FirestoreSync] Failed to write/read shared_tasks collection');
        return false;
      }
      
      // Test 3: Sharing index
      final indexTestDoc = _fs!.collection('sharing_index').doc(userEmail).collection('shared_tasks').doc('permission_test');
      await indexTestDoc.set({
        'test': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
      final indexDoc = await indexTestDoc.get();
      await indexTestDoc.delete();
      
      if (!indexDoc.exists) {
        print('[FirestoreSync] Failed to write/read sharing_index collection');
        return false;
      }
      
      print('[FirestoreSync] All permission tests passed');
      return true;
    } catch (e) {
      print('[FirestoreSync] Permission test failed: $e');
      return false;
    }
  }

  /// Debug method to check what sharing data exists for a task
  Future<void> debugTaskSharing(String taskId) async {
    if (!_initialized || _auth?.currentUser == null) return;
    
    try {
      print('[FirestoreSync] 🔍 DEBUG: Checking sharing data for task $taskId');
      
      // Check shared_tasks collection
      final sharedTaskDoc = await _fs!.collection('shared_tasks').doc(taskId).get();
      if (sharedTaskDoc.exists) {
        final data = sharedTaskDoc.data()!;
        print('[FirestoreSync] - Shared task data: owner=${data['ownerId']}, sharedWith=${data['sharedWith']}');
      } else {
        print('[FirestoreSync] - Task NOT found in shared_tasks collection');
      }
      
      // Check sharing index - who has access to this task
      final indexQuery = await _fs!.collectionGroup('shared_tasks')
          .where('taskId', isEqualTo: taskId)
          .get();
      
      print('[FirestoreSync] - Sharing index entries: ${indexQuery.docs.length}');
      for (final doc in indexQuery.docs) {
        final data = doc.data();
        final recipientEmail = doc.reference.parent.parent!.id;
        print('[FirestoreSync]   • Shared with: $recipientEmail (owner: ${data['ownerId']})');
      }
    } catch (e) {
      print('[FirestoreSync] Debug error: $e');
    }
  }

  /// Share a task with family members by email
  Future<void> shareTaskWithEmails(String taskId, List<String> emails) async {
    if (!_initialized || _auth?.currentUser == null) {
      throw Exception('Not signed in or Firebase not initialized');
    }

    try {
      final uid = _auth!.currentUser!.uid;
      final userEmail = _auth!.currentUser!.email!;
      
      print('[FirestoreSync] Starting task sharing...');
      print('[FirestoreSync] - Task ID: $taskId');
      print('[FirestoreSync] - Sharing from: $userEmail (uid: $uid)');
      print('[FirestoreSync] - Target emails: $emails');
      
      // Validate emails first
      final validEmails = emails.where((email) => 
        email.isNotEmpty && 
        email.contains('@') && 
        email != userEmail // Don't share with ourselves!
      ).toList();
      
      if (validEmails.isEmpty) {
        throw Exception('No valid recipient emails provided (cannot share with yourself)');
      }
      
      print('[FirestoreSync] - Valid target emails: $validEmails');
      
      // Get the task from user's collection
      final taskDoc = await _fs!.collection('users').doc(uid).collection('tasks').doc(taskId).get();
      if (!taskDoc.exists) {
        throw Exception('Task not found');
      }
      
      final taskData = Map<String, dynamic>.from(taskDoc.data()!);
      
      // Ensure all required fields are set
      taskData['isShared'] = true;
      taskData['sharedWith'] = validEmails; // Use validated emails only
      taskData['ownerId'] = userEmail; // Always set current user as owner
      taskData['lastModifiedBy'] = userEmail;
      taskData['updatedAt'] = DateTime.now().toIso8601String();
      
      print('[FirestoreSync] Task prepared for sharing:');
      print('[FirestoreSync] - Title: ${taskData['title']}');
      print('[FirestoreSync] - Owner: ${taskData['ownerId']}');
      print('[FirestoreSync] - SharedWith: ${taskData['sharedWith']}');
      
      // Use batch writes for better consistency
      final batch = _fs!.batch();
      
      // Update the task in owner's collection
      final ownerTaskRef = _fs!.collection('users').doc(uid).collection('tasks').doc(taskId);
      batch.set(ownerTaskRef, taskData, firestore.SetOptions(merge: true));
      
      // Add to shared tasks collection
      final sharedTaskRef = _fs!.collection('shared_tasks').doc(taskId);
      batch.set(sharedTaskRef, taskData, firestore.SetOptions(merge: true));
      
      // Update sharing index for each shared user
      for (final sharedEmail in validEmails) {
        print('[FirestoreSync] Creating sharing index entry for: $sharedEmail');
        
        // Create index entry for the person we're sharing WITH (not ourselves)
        final sharingIndexRef = _fs!.collection('sharing_index').doc(sharedEmail).collection('shared_tasks').doc(taskId);
        batch.set(sharingIndexRef, {
          'taskId': taskId,
          'ownerId': userEmail, // Owner is the person sharing (us)
          'ownerEmail': userEmail,
          'title': taskData['title'],
          'updatedAt': taskData['updatedAt'],
          'sharedBy': userEmail,
          'sharedWith': sharedEmail, // The person this is shared with
        }, firestore.SetOptions(merge: true));
      }
      
      // Commit all changes atomically
      print('[FirestoreSync] Committing batch write for task sharing...');
      await batch.commit();
      
      _statusController.add('task-shared');
      print('[FirestoreSync] ✅ Task $taskId successfully shared with ${validEmails.length} users: $validEmails');
      
      // Debug: Check what was actually created
      await debugTaskSharing(taskId);
    } catch (e) {
      _statusController.add('error');
      print('[FirestoreSync] Error sharing task: $e');
      
      String errorMessage = 'Failed to share task';
      
      if (e is firestore.FirebaseException) {
        print('[FirestoreSync] FirebaseException code: ${e.code}, message: ${e.message}');
        
        switch (e.code) {
          case 'permission-denied':
            errorMessage = 'Permission denied. Please check Firestore security rules are updated.';
            break;
          case 'not-found':
            errorMessage = 'Task not found or no longer exists.';
            break;
          case 'unavailable':
            errorMessage = 'Service temporarily unavailable. Please try again.';
            break;
          case 'unauthenticated':
            errorMessage = 'Authentication required. Please sign in again.';
            break;
          default:
            errorMessage = 'Firebase error: ${e.message}';
        }
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      }
      
      throw Exception(errorMessage);
    }
  }

  /// Remove sharing for a task
  Future<void> unshareTask(String taskId) async {
    if (!_initialized || _auth?.currentUser == null) {
      throw Exception('Not signed in or Firebase not initialized');
    }

    try {
      final uid = _auth!.currentUser!.uid;
      final userEmail = _auth!.currentUser!.email!;
      
      // Get the task to see who it was shared with
      final taskDoc = await _fs!.collection('users').doc(uid).collection('tasks').doc(taskId).get();
      if (!taskDoc.exists) {
        throw Exception('Task not found');
      }
      
      final taskData = Map<String, dynamic>.from(taskDoc.data()!);
      final sharedWith = taskData['sharedWith'] as List<dynamic>?;
      
      // Update task to remove sharing
      taskData['isShared'] = false;
      taskData['sharedWith'] = null;
      taskData['lastModifiedBy'] = userEmail;
      taskData['updatedAt'] = DateTime.now().toIso8601String();
      
      // Use batch writes for consistency
      final batch = _fs!.batch();
      
      // Update the task in owner's collection
      final ownerTaskRef = _fs!.collection('users').doc(uid).collection('tasks').doc(taskId);
      batch.set(ownerTaskRef, taskData, firestore.SetOptions(merge: true));
      
      // Remove from shared tasks collection
      final sharedTaskRef = _fs!.collection('shared_tasks').doc(taskId);
      batch.delete(sharedTaskRef);
      
      // Remove from sharing index for each previously shared user
      if (sharedWith != null) {
        for (final sharedEmail in sharedWith) {
          print('[FirestoreSync] Removing sharing index entry for: $sharedEmail');
          final sharingIndexRef = _fs!.collection('sharing_index').doc(sharedEmail.toString()).collection('shared_tasks').doc(taskId);
          batch.delete(sharingIndexRef);
        }
      }
      
      // Commit all changes atomically
      await batch.commit();
      
      _statusController.add('task-unshared');
      print('[FirestoreSync] Task $taskId unshared');
    } catch (e) {
      _statusController.add('error');
      String errorMessage = 'Failed to unshare task';
      
      if (e.toString().contains('permission-denied')) {
        errorMessage = 'Permission denied. You may not have rights to unshare this task.';
      } else if (e.toString().contains('not-found')) {
        errorMessage = 'Task not found or already unshared.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      }
      
      throw Exception(errorMessage);
    }
  }

  /// Get tasks shared with current user
  Future<List<Task>> fetchSharedTasks() async {
    if (!_initialized || _auth?.currentUser == null) return [];
    
    try {
      final userEmail = _auth!.currentUser!.email!;
      final out = <Task>[];
      
      print('[FirestoreSync] Fetching shared tasks for user: $userEmail');
      
      // Get list of shared tasks from sharing index where current user is the recipient
      final sharingIndex = await _fs!.collection('sharing_index').doc(userEmail).collection('shared_tasks').get();
      
      print('[FirestoreSync] Found ${sharingIndex.docs.length} sharing index entries for $userEmail');
      
      // Fetch each shared task from the shared_tasks collection
      for (final indexDoc in sharingIndex.docs) {
        try {
          final indexData = indexDoc.data();
          final taskId = indexData['taskId'] as String;
          final ownerEmail = indexData['ownerId'] as String?;
          
          print('[FirestoreSync] Loading shared task $taskId owned by $ownerEmail');
          
          final sharedTaskDoc = await _fs!.collection('shared_tasks').doc(taskId).get();
          
          if (sharedTaskDoc.exists) {
            final data = Map<String, dynamic>.from(sharedTaskDoc.data() as Map);
            data['id'] = data['id'] ?? sharedTaskDoc.id;
            
            // Only include tasks where current user is NOT the owner (tasks shared WITH us)
            if (data['ownerId'] != userEmail) {
              final task = Task.fromJson(data);
              out.add(task);
              print('[FirestoreSync] Added shared task: ${task.title} (owner: ${task.ownerId})');
            } else {
              print('[FirestoreSync] Skipping own task: ${data['title']}');
            }
          }
        } catch (e) {
          print('[FirestoreSync] Error loading shared task: $e');
        }
      }
      
      print('[FirestoreSync] Fetched ${out.length} shared tasks for $userEmail');
      return out;
    } catch (e) {
      print('[FirestoreSync] Error fetching shared tasks: $e');
      return [];
    }
  }

  /// Get all tasks (owned + shared) for the current user
  Future<List<Task>> fetchAllUserTasks() async {
    final userEmail = _auth?.currentUser?.email;
    
    final ownTasks = await fetchRemoteTasks();
    final sharedTasks = await fetchSharedTasks();
    
    print('[FirestoreSync] Own tasks: ${ownTasks.length}, Shared tasks: ${sharedTasks.length}');
    
    // Combine and deduplicate (in case a task appears in both lists)
    final allTasks = <String, Task>{};
    
    // Add owned tasks
    for (final task in ownTasks) {
      allTasks[task.id] = task;
      print('[FirestoreSync] Added own task: ${task.title}');
    }
    
    // Add shared tasks (only if not already owned by current user)
    for (final task in sharedTasks) {
      if (task.ownerId != userEmail) {
        allTasks[task.id] = task;
        print('[FirestoreSync] Added shared task: ${task.title} (owner: ${task.ownerId})');
      } else {
        print('[FirestoreSync] Skipping shared task that we own: ${task.title}');
      }
    }
    
    print('[FirestoreSync] Total unique tasks: ${allTasks.length}');
    return allTasks.values.toList();
  }

  /// Update a shared task (can be called by any user with access)
  Future<void> updateSharedTask(Task task) async {
    if (!_initialized || _auth?.currentUser == null) return;
    
    final userEmail = _auth!.currentUser!.email!;
    
    // Update the task with modification info
    final taskData = task.toJson();
    taskData['lastModifiedBy'] = userEmail;
    taskData['updatedAt'] = DateTime.now().toIso8601String();
    
    // Update in shared_tasks collection
    await _fs!.collection('shared_tasks').doc(task.id).set(taskData, firestore.SetOptions(merge: true));
    
    // Also update in owner's collection if we know who the owner is
    if (task.ownerId != null) {
      try {
        // Find the owner's UID from their email
        final ownerQuery = await _fs!.collection('users').where('email', isEqualTo: task.ownerId).limit(1).get();
        if (ownerQuery.docs.isNotEmpty) {
          final ownerUid = ownerQuery.docs.first.id;
          await _fs!.collection('users').doc(ownerUid).collection('tasks').doc(task.id).set(taskData, firestore.SetOptions(merge: true));
        }
      } catch (e) {
        print('[FirestoreSync] Could not update owner copy: $e');
      }
    }
    
    print('[FirestoreSync] Updated shared task ${task.id} by $userEmail');
  }

  /// Clear all online data for the current user.
  /// WARNING: This permanently deletes all tasks from the user's Firestore collection.
  Future<void> clearAllOnlineData() async {
    if (!_initialized || _auth?.currentUser == null) {
      throw Exception('Not signed in or Firebase not initialized');
    }

    try {
      final uid = _auth!.currentUser!.uid;
      final batch = _fs!.batch();
      
      // Get all documents in the user's tasks collection
      final snapshot = await _fs!.collection('users').doc(uid).collection('tasks').get();
      
      // Add all documents to batch for deletion
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Execute the batch delete
      await batch.commit();
      
      _statusController.add('cleared-online-data');
    } catch (e) {
      _statusController.add('error');
      throw Exception('Failed to clear online data: $e');
    }
  }
}
