
@JS()
library audio_priming_web;

import 'dart:js_interop';

@JS('resetAudioPriming')
external void _resetAudioPriming();

@JS('showAudioOverlay')
external void _showAudioOverlay();

class AudioPriming {
  static void reset() {
    try {
      _resetAudioPriming();
    } catch (_) {}
  }

  static void showOverlay() {
    try {
      _showAudioOverlay();
    } catch (_) {}
  }
}
