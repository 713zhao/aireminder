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
      if (!enabled) {
        print('TTS: Voice reminders disabled in settings');
        return;
      }
    } catch (e) {
      print('TTS: Settings error, proceeding with speech: $e');
    }
    
    try {
      print('TTS: Speaking: "$text"');
      await _impl.speak(text);
    } catch (e) {
      print('TTS: Error speaking: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    await _impl.stop();
  }

  void dispose() {}
}
