import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/voice_button.dart';
import '../services/audio_priming.dart';
import '../services/firestore_sync.dart';
import '../services/settings_service.dart';
import 'tasks_list.dart';
import 'settings.dart';
import '../widgets/task_form.dart';
import '../widgets/date_strip.dart';
import '../widgets/ad_bar.dart';
import '../widgets/tasks_for_date.dart';
import 'image_event_extractor.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _userEmail;
  StreamSubscription<String?>? _userSub;
  bool _standaloneMode = true;

  void _onDateSelected(DateTime d) {
    setState(() => _selectedDate = d);
  }

  void _updateStandaloneMode() {
    setState(() {
      _standaloneMode = SettingsService.standaloneMode;
    });
  }

  void _showCreateTaskMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Create New Task',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Create Manually'),
              subtitle: const Text('Enter task details manually'),
              onTap: () async {
                Navigator.of(context).pop();
                final res = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TaskForm()),
                );
                if (res == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task created')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_search, color: Colors.green),
              title: const Text('Extract from Image'),
              subtitle: const Text('Use AI to extract event info from photos'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ImageEventExtractorScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Initialize standalone mode setting
    _standaloneMode = SettingsService.standaloneMode;
    
    // listen for sign-in changes from the sync service
    _userSub = FirestoreSyncService.instance.userChanges.listen((email) {
      setState(() {
        _userEmail = email;
      });
    });
    // No automatic sign-in or dev auto-run: user must press the login button to sign in.
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Reminder'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TasksListScreen()));
            },
          ),
          // Hide user email and login button in standalone mode
          if (!_standaloneMode) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Text(
                  _userEmail ?? 'Not signed in',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            IconButton(
              icon: Icon(_userEmail == null ? Icons.login : Icons.logout),
              tooltip: _userEmail == null ? 'Sign in to sync' : 'Sign out',
              onPressed: () async {
                if (_userEmail == null) {
                  try {
                    await FirestoreSyncService.instance.init();
                    final res = await FirestoreSyncService.instance.signInWithGoogle();
                    if (res != null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed in for sync')));
                    }
                  } catch (e) {
                    final msg = e.toString();
                    if (msg.contains('configuration-not-found')) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign-in configuration not found. Check Firebase console and authorized domains.')));
                    } else if (msg.contains('popup-closed-by-user')) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign-in cancelled (popup closed).')));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign-in failed')));
                    }
                  }
                } else {
                  try {
                    await FirestoreSyncService.instance.signOut();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign-out failed')));
                  }
                }
              },
            ),
          ],
          // Dev controls moved to Settings (one-tap Run dev sync and hidden dev menu).
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
              _updateStandaloneMode(); // Refresh standalone mode after returning from settings
            },
          ),
          IconButton(
            tooltip: 'Enable audio',
            icon: const Icon(Icons.volume_up),
            onPressed: () {
              try {
                AudioPriming.showOverlay();
              } catch (_) {}
            },
          ),
        ],
      ),
      body: Column(children: [
        const AdBar(),
        DateStrip(initialDate: DateTime.now(), onDateSelected: _onDateSelected),
        Expanded(child: TasksForDate(date: _selectedDate)),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateTaskMenu(),
        child: const Icon(Icons.add),
      ),
      persistentFooterButtons: [
        VoiceButton(),
      ],
    );
  }

  // Removed manual sync choice dialog — sign-in automatically fetches server data.
}
