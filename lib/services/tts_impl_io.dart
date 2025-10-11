import 'package:flutter_tts/flutter_tts.dart';

class TtsImpl {
  final FlutterTts _tts = FlutterTts();

  Future<void> init() async {
    try {
      await _tts.setSharedInstance(true);
    } catch (_) {}
    try {
      await _tts.setSpeechRate(0.5);
    } catch (_) {}
    try {
      await _tts.setVolume(1.0);
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
