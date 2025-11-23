import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:async';
import '../services/audio_priming.dart';
import '../services/firestore_sync.dart';
import 'family_sharing_screen.dart';
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
  String _aiProvider = 'gemini';
  String _aiModel = 'gemini-2.5-flash';
  String _aiApiKey = '';
  bool _aiConfigExpanded = false;
  final _geminiApiKeyController = TextEditingController();
  final _aiApiKeyController = TextEditingController();
  String? _userEmail;
  StreamSubscription<String?>? _userSub;
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
  _aiProvider = _box.get('aiProvider', defaultValue: 'gemini') as String;
  _aiModel = _box.get('aiModel', defaultValue: 'gemini-2.5-flash') as String;
  _aiApiKey = _box.get('aiApiKey', defaultValue: _geminiApiKey) as String;
  _geminiApiKeyController.text = _geminiApiKey;
  _aiApiKeyController.text = _aiApiKey;
  
  // Get current user email
  _userEmail = FirestoreSyncService.instance.currentUserEmail;
  
  // Listen for user sign-in changes
  _userSub = FirestoreSyncService.instance.userChanges.listen((email) {
    if (mounted) {
      setState(() {
        _userEmail = email;
      });
    }
  });
  }

  @override
  void dispose() {
    _geminiApiKeyController.dispose();
    _aiApiKeyController.dispose();
    _userSub?.cancel();
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

  void _setAiProvider(String value) {
    setState(() {
      _aiProvider = value;
      // Set default model for the provider
      _aiModel = _getDefaultModelForProvider(value);
      // Migrate API key if switching from Gemini
      if (value == 'gemini' && _aiApiKey.isEmpty && _geminiApiKey.isNotEmpty) {
        _aiApiKey = _geminiApiKey;
        _aiApiKeyController.text = _aiApiKey;
      } else if (value != 'gemini') {
        _aiApiKey = '';
        _aiApiKeyController.text = '';
      }
    });
    _box.put('aiProvider', value);
    _box.put('aiModel', _aiModel);
    _box.put('aiApiKey', _aiApiKey);
  }

  void _setAiModel(String value) {
    setState(() => _aiModel = value);
    _box.put('aiModel', value);
  }

  void _setAiApiKey(String value) {
    setState(() => _aiApiKey = value);
    _box.put('aiApiKey', value);
    // Also update Gemini API key if current provider is Gemini
    if (_aiProvider == 'gemini') {
      _geminiApiKey = value;
      _geminiApiKeyController.text = value;
      _box.put('geminiApiKey', value);
    }
  }

  String _getDefaultModelForProvider(String provider) {
    switch (provider) {
      case 'gemini':
        return 'gemini-2.5-flash';
      case 'openai':
        return 'gpt-4o-mini';
      case 'deepseek':
        return 'deepseek-chat';
      case 'qianwen':
        return 'qwen-turbo';
      default:
        return 'gemini-1.5-flash';
    }
  }

  List<String> _getModelsForProvider(String provider) {
    switch (provider) {
      case 'gemini':
        return [
          'gemini-2.5-flash',
          'gemini-1.5-flash',
          'gemini-1.5-pro',
          'gemini-2.0-flash-exp',
          'gemini-1.0-pro',
        ];
      case 'openai':
        return [
          'gpt-4o-mini',
          'gpt-4o',
          'gpt-4-turbo',
          'gpt-3.5-turbo',
        ];
      case 'deepseek':
        return [
          'deepseek-chat',
          'deepseek-coder',
          'deepseek-reasoner',
        ];
      case 'qianwen':
        return [
          'qwen-turbo',
          'qwen-plus',
          'qwen-max',
          'qwen-coder-turbo',
        ];
      default:
        return ['gemini-2.5-flash'];
    }
  }

  String _getProviderDisplayName(String provider) {
    switch (provider) {
      case 'gemini':
        return 'Google Gemini';
      case 'openai':
        return 'OpenAI';
      case 'deepseek':
        return 'DeepSeek';
      case 'qianwen':
        return 'Qianwen (Alibaba)';
      default:
        return provider;
    }
  }

  String _getApiKeyHint(String provider) {
    switch (provider) {
      case 'gemini':
        return 'Get from Google AI Studio (ai.google.dev)';
      case 'openai':
        return 'Get from OpenAI Platform (platform.openai.com)';
      case 'deepseek':
        return 'Get from DeepSeek Platform (platform.deepseek.com)';
      case 'qianwen':
        return 'Get from Alibaba Cloud Console';
      default:
        return 'Enter your API key';
    }
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
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _aiConfigExpanded = !_aiConfigExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.smart_toy, color: Colors.blue),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Configuration',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Configure AI provider and model for image analysis',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _aiConfigExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_aiConfigExpanded) ...[
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  
                  // AI Provider Selection
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Provider',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _aiProvider,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'gemini', child: Text('Google Gemini')),
                            DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
                            DropdownMenuItem(value: 'deepseek', child: Text('DeepSeek')),
                            DropdownMenuItem(value: 'qianwen', child: Text('Qianwen (Alibaba)')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              _setAiProvider(value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // AI Model Selection
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Model',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _getModelsForProvider(_aiProvider).contains(_aiModel) ? _aiModel : _getModelsForProvider(_aiProvider).first,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _getModelsForProvider(_aiProvider)
                              .map((model) => DropdownMenuItem(value: model, child: Text(model)))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              _setAiModel(value);
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Popular models are pre-selected. You can edit or change as needed.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // API Key Configuration
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_getProviderDisplayName(_aiProvider)} API Key',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _aiApiKeyController,
                          decoration: InputDecoration(
                            hintText: 'Enter your API key...',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.save, size: 20),
                              onPressed: () {
                                _setAiApiKey(_aiApiKeyController.text);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('API key saved')),
                                );
                              },
                            ),
                          ),
                          obscureText: true,
                          onChanged: (value) => _setAiApiKey(value),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Required for AI-powered image analysis. ${_getApiKeyHint(_aiProvider)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
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
          // ===================== ACCOUNT SECTION =====================
          if (!_standaloneMode) ...[
            const Text(
              'Account',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            // User email display
            if (_userEmail != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Signed in as:',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            _userEmail!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            
            // Family Sharing Button
            if (_userEmail != null && _userEmail != 'offline-user@local')
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FamilySharingScreen()),
                  );
                },
                icon: const Icon(Icons.people, color: Colors.white),
                label: const Text('Family Sharing'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            const SizedBox(height: 8),
            
            // Sign Out Button
            ElevatedButton.icon(
              onPressed: _userEmail == null ? null : () async {
                try {
                  await FirestoreSyncService.instance.signOut();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Signed out successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Sign-out failed: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.logout),
              label: Text(_userEmail == null ? 'Not Signed In' : 'Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _userEmail == null ? Colors.grey : Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 20),
          ],
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
