// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Simple wrapper service around the `speech_to_text` plugin.
/// Provides init/start/stop and a stream of transcriptions.
class VoiceService {
  VoiceService();

  final stt.SpeechToText _stt = stt.SpeechToText();
  StreamController<String> _transcriptCtrl = StreamController.broadcast();

  /// Latest transcribed text (may be partial while listening).
  String lastTranscript = '';

  /// Whether STT is available on this device.
  bool available = false;

  /// Whether the service is currently listening.
  bool get isListening => _stt.isListening;

  /// Stream of transcription updates.
  Stream<String> get onTranscript => _transcriptCtrl.stream;

  /// Initialize the underlying STT engine and request permissions.
  Future<bool> init() async {
    try {
      available = await _stt.initialize(onStatus: _statusListener, onError: _errorListener);
      return available;
    } catch (_) {
      available = false;
      return false;
    }
  }

  void _statusListener(String status) {
    // status examples: "listening", "notListening"
  }

  void _errorListener(dynamic error) {
    // Log or surface errors via the stream as empty or special tokens if needed.
  }

  /// Start listening and emit transcriptions via [onTranscript].
  /// [listenFor] controls the maximum listen duration; [pauseFor] sets auto-pause.
  Future<void> startListening({
    Duration listenFor = const Duration(seconds: 60),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (!available) {
      final ok = await init();
      if (!ok) return;
    }

  // The partialResults parameter is deprecated in newer versions of speech_to_text
  // (SpeechListenOptions should be used). Keep using partialResults for now
  // to remain compatible with the installed package version.
  await _stt.listen(
      onResult: (dynamic result) {
        // result may be a SpeechRecognitionResult; access recognizedWords dynamically
        try {
          lastTranscript = result.recognizedWords ?? '';
        } catch (_) {
          lastTranscript = result?.toString() ?? '';
        }
        _transcriptCtrl.add(lastTranscript);
      },
      listenFor: listenFor,
      pauseFor: pauseFor,
      partialResults: true,
      localeId: null,
      onSoundLevelChange: null,
    );
  }

  /// Stop listening.
  Future<void> stopListening() async {
    if (_stt.isListening) {
      await _stt.stop();
    }
  }

  /// Dispose resources.
  void dispose() {
    _transcriptCtrl.close();
  }
}
