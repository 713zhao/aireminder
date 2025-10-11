import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/audio_priming.dart';

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
  // debug-only auto-run removed

  @override
  void initState() {
    super.initState();
    _box = Hive.box('settings_box');
  _defaultSnooze = _box.get('defaultSnooze', defaultValue: 10) as int;
  _showAdBar = _box.get('showAdBar', defaultValue: true) as bool;
  _voiceReminders = _box.get('voiceReminders', defaultValue: true) as bool;
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

  // offlineOnly setting removed; offline handling uses backup by default.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
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
          // Offline-only toggle removed. App uses backup and server sync behavior by policy.
          const SizedBox(height: 8),
          // Auto-run dev sync removed from settings
          const SizedBox(height: 12),
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
