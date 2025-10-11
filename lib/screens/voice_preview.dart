import 'package:flutter/material.dart';
import '../services/voice_service.dart';
import '../services/voice_parser.dart';
import '../data/hive_task_repository.dart';
import '../services/notification_service.dart';

final _repo = HiveTaskRepository();

class VoicePreview extends StatefulWidget {
  final VoiceService voiceService;
  const VoicePreview({super.key, required this.voiceService});

  @override
  State<VoicePreview> createState() => _VoicePreviewState();
}

class _VoicePreviewState extends State<VoicePreview> {
  String _transcript = '';

  @override
  void initState() {
    super.initState();
    widget.voiceService.onTranscript.listen((t) {
      setState(() {
        _transcript = t;
      });
    });
    widget.voiceService.startListening(listenFor: const Duration(seconds: 30));
  }

  @override
  void dispose() {
    widget.voiceService.stopListening();
    super.dispose();
  }

  void _showParsed() {
    final res = VoiceParser.parse(_transcript);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Parsed Task'),
        content: Text(res.toString()),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          TextButton(
            onPressed: () async {
              // Save task
              final task = await _repo.create(title: res.title, dueAt: res.dueAt, recurrence: res.recurrence);
              // Schedule notification if due date exists
                if (task.dueAt != null) {
                final id = int.tryParse(task.id) ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);
                final payload = '{"id": $id}';
                await notificationService.scheduleNotification(id: id, title: task.title, body: task.title, when: task.dueAt!, repeatCap: const Duration(minutes: 5), payload: payload);
              }
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task saved')));
            },
            child: const Text('Confirm & Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Preview')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Speak now...'),
            const SizedBox(height: 12),
            Expanded(child: SingleChildScrollView(child: Text(_transcript.isEmpty ? '...' : _transcript))),
            ElevatedButton(onPressed: _showParsed, child: const Text('Show parsed preview')),
          ],
        ),
      ),
    );
  }
}
