import 'dart:async';
import 'package:hive/hive.dart';
import 'tts_impl.dart';

class TtsService {
  TtsService();

  final TtsImpl _impl = TtsImpl();

  Future<void> init() async {
    await _impl.init();
  }

  Future<void> speak(String text) async {
    // Respect global user preference for voice reminders. If disabled, do nothing.
    try {
      final settings = Hive.box('settings_box');
      final enabled = settings.get('voiceReminders', defaultValue: true) as bool;
      if (!enabled) return;
    } catch (_) {
      // If settings can't be read, fall back to speaking.
    }
    await _impl.speak(text);
  }

  Future<void> stop() async {
    await _impl.stop();
  }

  void dispose() {}
}
