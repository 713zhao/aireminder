import 'package:hive/hive.dart';
import 'dart:convert';

/// WARNING: Passwords are stored with light obfuscation (NOT strong encryption).
/// This improves convenience (auto-fill & auto-login) but is not suitable for
/// highly sensitive environments. For stronger protection, integrate platform
/// secure storage (Keychain/Keystore) later.

/// Service to manage app settings and provide easy access throughout the app
class SettingsService {
  static late Box _box;
  // Credentials stored inside settings_box under key 'credentials'
  
  /// Initialize the settings service
  static Future<void> init() async {
    _box = Hive.box('settings_box');
  }
  
  /// Get the standalone mode setting
  static bool get standaloneMode => _box.get('standaloneMode', defaultValue: true) as bool;
  
  /// Get the default snooze duration
  static int get defaultSnooze => _box.get('defaultSnooze', defaultValue: 10) as int;
  
  /// Get the show ad bar setting
  static bool get showAdBar => _box.get('showAdBar', defaultValue: true) as bool;
  
  /// Get the voice reminders setting
  static bool get voiceReminders => _box.get('voiceReminders', defaultValue: true) as bool;
  
  /// Get the selected AI provider
  static String get aiProvider => _box.get('aiProvider', defaultValue: 'gemini') as String;
  
  /// Get the selected AI model
  static String get aiModel => _box.get('aiModel', defaultValue: 'gemini-2.5-flash') as String;
  
  /// Get the API key for the current provider
  static String get aiApiKey => _box.get('aiApiKey', defaultValue: '') as String;
  
  /// Get the Gemini API key (for backwards compatibility)
  static String get geminiApiKey => _box.get('geminiApiKey', defaultValue: '') as String;
  
  /// Get the last login email
  static String get lastLoginEmail => _box.get('lastLoginEmail', defaultValue: '') as String;

  /// Internal: fetch credential map (email -> obfuscated password)
  static Map<String, String> _credentialMap() {
    final raw = _box.get('credentials', defaultValue: const <String, String>{});
    if (raw is Map) {
      try {
        return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
      } catch (_) {
        return <String, String>{};
      }
    }
    return <String, String>{};
  }

  /// Save (or update) credential for an email
  static void saveCredential(String email, String password) {
    if (email.isEmpty || password.isEmpty) return;
    final map = _credentialMap();
    map[email] = _encrypt(password);
    _box.put('credentials', map);
  }

  /// Retrieve stored password for given email (returns empty string if none)
  static String getStoredPassword(String email) {
    if (email.isEmpty) return '';
    final map = _credentialMap();
    final enc = map[email];
    if (enc == null || enc.isEmpty) return '';
    return _decrypt(enc);
  }

  /// Simple reversible obfuscation (NOT secure encryption)
  static const _k = 'ai-reminder-local-cred-key';

  static String _encrypt(String plain) {
    final bytes = utf8.encode(plain);
    final keyBytes = utf8.encode(_k);
    final out = List<int>.generate(bytes.length, (i) => bytes[i] ^ keyBytes[i % keyBytes.length]);
    return base64Url.encode(out);
  }

  static String _decrypt(String enc) {
    try {
      final bytes = base64Url.decode(enc);
      final keyBytes = utf8.encode(_k);
      final out = List<int>.generate(bytes.length, (i) => bytes[i] ^ keyBytes[i % keyBytes.length]);
      return utf8.decode(out);
    } catch (_) {
      return '';
    }
  }
  
  /// Set standalone mode
  static void setStandaloneMode(bool value) {
    _box.put('standaloneMode', value);
  }
  
  /// Set default snooze duration
  static void setDefaultSnooze(int value) {
    _box.put('defaultSnooze', value);
  }
  
  /// Set show ad bar
  static void setShowAdBar(bool value) {
    _box.put('showAdBar', value);
  }
  
  /// Set voice reminders
  static void setVoiceReminders(bool value) {
    _box.put('voiceReminders', value);
  }
  
  /// Set AI provider
  static void setAiProvider(String value) {
    _box.put('aiProvider', value);
  }
  
  /// Set AI model
  static void setAiModel(String value) {
    _box.put('aiModel', value);
  }
  
  /// Set AI API key
  static void setAiApiKey(String value) {
    _box.put('aiApiKey', value);
  }
  
  /// Set Gemini API key (for backwards compatibility)
  static void setGeminiApiKey(String value) {
    _box.put('geminiApiKey', value);
    // Also update the new aiApiKey if current provider is Gemini
    if (aiProvider == 'gemini') {
      setAiApiKey(value);
    }
  }
  
  /// Set the last login email
  static void setLastLoginEmail(String value) {
    _box.put('lastLoginEmail', value);
  }

}