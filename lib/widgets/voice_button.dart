import 'package:flutter/material.dart';
import '../services/voice_service.dart';
import '../screens/voice_preview.dart';

class VoiceButton extends StatefulWidget {
  const VoiceButton({super.key});

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton> {
  final VoiceService _voice = VoiceService();

  @override
  void dispose() {
    _voice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.mic),
      label: const Text('Voice Add'),
      onPressed: () async {
        await _voice.init();
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => VoicePreview(voiceService: _voice)));
      },
    );
  }
}
