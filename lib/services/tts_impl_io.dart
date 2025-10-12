import 'package:flutter_tts/flutter_tts.dart';

class TtsImpl {
  final FlutterTts _tts = FlutterTts();

  Future<void> init() async {
    try {
      print('TTS: Initializing flutter_tts...');
      await _tts.setSharedInstance(true);
      print('TTS: Set shared instance');
    } catch (e) {
      print('TTS: Error setting shared instance: $e');
    }
    try {
      await _tts.setSpeechRate(0.5);
      print('TTS: Set speech rate to 0.5');
    } catch (e) {
      print('TTS: Error setting speech rate: $e');
    }
    try {
      await _tts.setVolume(1.0);
      print('TTS: Set volume to 1.0');
    } catch (e) {
      print('TTS: Error setting volume: $e');
    }
    
    // Test if TTS engines are available
    try {
      final engines = await _tts.getEngines;
      print('TTS: Available engines: $engines');
    } catch (e) {
      print('TTS: Error getting engines: $e');
    }
    
    try {
      final voices = await _tts.getVoices;
      print('TTS: Available voices: ${voices?.length ?? 0} voices');
    } catch (e) {
      print('TTS: Error getting voices: $e');
    }
  }

  Future<void> speak(String text) async {
    try {
      print('TTS Engine: Speaking "$text"');
      await _tts.speak(text);
      print('TTS Engine: Speech completed');
    } catch (e) {
      print('TTS Engine: Speech error: $e');
      throw Exception('TTS failed: $e');
    }
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
