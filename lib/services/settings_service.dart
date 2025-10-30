import 'package:hive/hive.dart';

/// Service to manage app settings and provide easy access throughout the app
class SettingsService {
  static late Box _box;
  
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
  
  /// Get the Gemini API key
  static String get geminiApiKey => _box.get('geminiApiKey', defaultValue: '') as String;
  
  /// Get the automatic family sync setting (only for online users)
  static bool get autoSyncFamily => _box.get('autoSyncFamily', defaultValue: true) as bool;
  
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
  
  /// Set Gemini API key
  static void setGeminiApiKey(String value) {
    _box.put('geminiApiKey', value);
  }
  
  /// Set automatic family sync
  static void setAutoSyncFamily(bool value) {
    _box.put('autoSyncFamily', value);
  }
}