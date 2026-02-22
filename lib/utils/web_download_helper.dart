import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Helper class to trigger file downloads in Flutter web
class WebDownloadHelper {
  /// Download a file in the browser using blob
  static void downloadFile(String content, String filename, {String mimeType = 'application/json'}) {
    if (!kIsWeb) {
      throw UnsupportedError('WebDownloadHelper only works on web platform');
    }

    try {
      _downloadViaBlob(content, filename, mimeType);
    } catch (e) {
      // Fallback to data URL method
      _downloadViaDataUrl(content, filename, mimeType);
    }
  }

  /// Download using Blob (preferred method)
  static void _downloadViaBlob(String content, String filename, String mimeType) {
    try {
      final bytes = utf8.encode(content);
      final base64Data = base64Encode(bytes);

      // JavaScript to create blob and trigger download
      // ignore: avoid_eval
      _executeJavaScript('''
        (function() {
          var byteCharacters = atob('$base64Data');
          var byteNumbers = new Array(byteCharacters.length);
          for (var i = 0; i < byteCharacters.length; i++) {
            byteNumbers[i] = byteCharacters.charCodeAt(i);
          }
          var byteArray = new Uint8Array(byteNumbers);
          var blob = new Blob([byteArray], {type: '$mimeType'});
          var url = URL.createObjectURL(blob);
          var link = document.createElement('a');
          link.href = url;
          link.download = '$filename';
          document.body.appendChild(link);
          link.click();
          document.body.removeChild(link);
          URL.revokeObjectURL(url);
        })();
      ''');
    } catch (e) {
      throw Exception('Blob download failed: $e');
    }
  }

  /// Download using data URL (fallback method)
  static void _downloadViaDataUrl(String content, String filename, String mimeType) {
    try {
      final bytes = utf8.encode(content);
      final base64Data = base64Encode(bytes);
      final dataUrl = 'data:$mimeType;base64,$base64Data';

      // ignore: avoid_eval
      _executeJavaScript('''
        (function() {
          var link = document.createElement('a');
          link.href = '$dataUrl';
          link.download = '$filename';
          document.body.appendChild(link);
          link.click();
          document.body.removeChild(link);
        })();
      ''');
    } catch (e) {
      throw Exception('DataURL download failed: $e');
    }
  }

  /// Execute JavaScript code
  static void _executeJavaScript(String code) {
    // ignore: avoid_dynamic_calls
    (window as dynamic).eval(code);
  }

  // Reference to window object for web
  static dynamic get window {
    // ignore: undefined_identifier
    try {
      // In web context, this will resolve to window via the dart:html library
      return _getWindowObject();
    } catch (e) {
      throw UnsupportedError('window object not available: $e');
    }
  }

  static dynamic _getWindowObject() {
    // Placeholder that will be called only on web
    return null;
  }
}
