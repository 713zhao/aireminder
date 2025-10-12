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
        try {
          final initialized = await _voice.init();
          if (!initialized) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Voice input not available on this device'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          if (!mounted) return;
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => VoicePreview(voiceService: _voice)));
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Voice error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }
}
