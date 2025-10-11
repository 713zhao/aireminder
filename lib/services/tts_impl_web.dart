// The `dart:html` import is currently used for a small browser TTS fallback.
// Lint suggests using package:web and dart:js_interop; keep this simple fallback
// for now and ignore the deprecation lint until we migrate to js_interop.
// ignore_for_file: deprecated_member_use

import 'dart:html' as html;

class TtsImpl {
  Future<void> init() async {
    // nothing to init for browser speechSynthesis
  }

  Future<void> speak(String text) async {
    try {
      final utterance = html.SpeechSynthesisUtterance(text);
  html.window.speechSynthesis?.speak(utterance);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
  html.window.speechSynthesis?.cancel();
    } catch (_) {}
  }
}
