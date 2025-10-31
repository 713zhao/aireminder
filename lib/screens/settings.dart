import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/audio_priming.dart';
import '../services/firestore_sync.dart';

import '../data/hive_task_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Box _box;
  int _defaultSnooze = 10;
  bool _showAdBar = true;
  bool _voiceReminders = true;
  bool _standaloneMode = true;
  String _geminiApiKey = '';
  final _geminiApiKeyController = TextEditingController();
  // debug-only auto-run removed

  @override
  void initState() {
    super.initState();
    _box = Hive.box('settings_box');
  _defaultSnooze = _box.get('defaultSnooze', defaultValue: 10) as int;
  _showAdBar = _box.get('showAdBar', defaultValue: true) as bool;
  _voiceReminders = _box.get('voiceReminders', defaultValue: true) as bool;
  _standaloneMode = _box.get('standaloneMode', defaultValue: true) as bool;
  _geminiApiKey = _box.get('geminiApiKey', defaultValue: '') as String;
  _geminiApiKeyController.text = _geminiApiKey;
  }

  @override
  void dispose() {
    _geminiApiKeyController.dispose();
    super.dispose();
  }

  void _setDefaultSnooze(int minutes) {
    setState(() => _defaultSnooze = minutes);
    _box.put('defaultSnooze', minutes);
  }

  // autoSync setting removed; sync behavior is automatic for signed-in users.

  void _setShowAdBar(bool v) {
    setState(() => _showAdBar = v);
    _box.put('showAdBar', v);
  }

  void _setVoiceReminders(bool v) {
    setState(() => _voiceReminders = v);
    _box.put('voiceReminders', v);
  }

  void _setStandaloneMode(bool v) {
    setState(() => _standaloneMode = v);
    _box.put('standaloneMode', v);
  }

  void _setGeminiApiKey(String value) {
    setState(() => _geminiApiKey = value);
    _box.put('geminiApiKey', value);
  }

  Future<void> _clearAllData() async {
    // Show confirmation dialog
    final confirmed = await _showClearDataConfirmation();
    if (!confirmed) return;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('Clearing all data...')),
            ],
          ),
        ),
      );

      // Clear local data
      final repo = HiveTaskRepository();
      await repo.clearAllLocalData();

      // Clear all Hive boxes (tasks, backup, settings)
      await Hive.box('tasks_box').clear();
      await Hive.box('tasks_backup_box').clear();
      await Hive.box('settings_box').clear();

      // Clear all notifications (cancel individual notifications would need task iteration)

      // Clear online data if user is signed in
      try {
        final syncService = FirestoreSyncService.instance;
        if (syncService.isSignedIn) {
          await syncService.clearAllOnlineData();
        }
      } catch (e) {
        // Continue even if online clearing fails
        print('Failed to clear online data: $e');
      }

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data cleared successfully. App will restart.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Exit the app after a brief delay
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showClearDataConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Clear All Data'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• All tasks and reminders'),
            Text('• All settings and preferences'),
            Text('• All backup data'),
            Text('• All online synced data (if signed in)'),
            SizedBox(height: 16),
            Text(
              'This action cannot be undone!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All Data'),
          ),
        ],
      ),
    ) ?? false;
  }

  // offlineOnly setting removed; offline handling uses backup by default.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Default Snooze Duration'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ChoiceChip(
              label: const Text('5m'),
              selected: _defaultSnooze == 5,
              onSelected: (_) => _setDefaultSnooze(5),
            ),
            ChoiceChip(
              label: const Text('10m'),
              selected: _defaultSnooze == 10,
              onSelected: (_) => _setDefaultSnooze(10),
            ),
            ChoiceChip(
              label: const Text('15m'),
              selected: _defaultSnooze == 15,
              onSelected: (_) => _setDefaultSnooze(15),
            ),
            ChoiceChip(
              label: const Text('30m'),
              selected: _defaultSnooze == 30,
              onSelected: (_) => _setDefaultSnooze(30),
            ),
          ]),
          const SizedBox(height: 20),
          // Automatic sync UI removed; signed-in users fetch server data automatically.
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text('Show advertisement bar')),
            Switch(value: _showAdBar, onChanged: (v) => _setShowAdBar(v)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text('Voice reminders (speak reminder)')),
            Switch(value: _voiceReminders, onChanged: (v) => _setVoiceReminders(v)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Standalone Mode'),
                  Text(
                    'Hide login button and work offline only',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Switch(value: _standaloneMode, onChanged: (v) => _setStandaloneMode(v)),
          ]),
          const SizedBox(height: 8),
          const SizedBox(height: 20),
          // ===================== AI CONFIGURATION SECTION =====================
          const Text(
            'AI Configuration',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Google Gemini API Key',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _geminiApiKeyController,
                    decoration: InputDecoration(
                      hintText: 'Enter API key...',
                      border: OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(Icons.save, size: 20),
                        onPressed: () {
                          _setGeminiApiKey(_geminiApiKeyController.text);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('API key saved')),
                          );
                        },
                      ),
                    ),
                    obscureText: true,
                    onChanged: (value) => _setGeminiApiKey(value),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Required for image analysis. Get from Google AI Studio.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // ===================== DATA MANAGEMENT SECTION =====================
          const Text(
            'Data Management',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _clearAllData,
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            label: const Text('Clear All Data'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Permanently delete all tasks, settings, and data. This action cannot be undone.',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          // Debug run button removed
          ElevatedButton(
            onPressed: () {
              try {
                AudioPriming.reset();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audio priming reset')));
              } catch (_) {}
            },
            child: const Text('Reset audio priming'),
          ),
        ]),
      ),
    );
  }
}
