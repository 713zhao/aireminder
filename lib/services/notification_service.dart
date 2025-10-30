import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:flutter/material.dart';
import 'repeat_controller.dart';
import 'tts_service.dart';
import '../data/hive_task_repository.dart';
import 'package:hive/hive.dart';
import 'dart:convert';
import 'app_globals.dart';

class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  
  /// Convert a task ID string to a safe 32-bit notification ID
  /// Uses hash code to ensure consistent mapping while staying within Android's limits
  static int safeNotificationId(String taskId) {
    // Use hashCode to convert string to int, then ensure it's positive and within 32-bit range
    final hash = taskId.hashCode;
    // Ensure positive and within 32-bit signed integer range
    return hash.abs() % 2147483647; // Max value for 32-bit signed int
  }
  final Map<int, RepeatController> _activeRepeats = {};
  final TtsService _tts = TtsService();
  final Map<int, Timer> _scheduledTimers = {};
  final StreamController<Map<String, dynamic>> _payloadStream = StreamController.broadcast();
  final StreamController<Set<int>> _activeRepeatsStream = StreamController<Set<int>>.broadcast();

  Future<void> init() async {
    // Initialize timezone data for scheduled notifications
  tzdata.initializeTimeZones();
    // Initialize local notifications
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings();
    await _fln.initialize(
      const InitializationSettings(android: android, iOS: iOS),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    await _tts.init();
  }
  /// Schedules a notification at [when] (local device time). Also schedules an in-app Timer
  /// fallback to start repeating readout if the app is running at that time.
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    Duration? repeatInterval,
    Duration? repeatCap,
    String? payload,
  }) async {
    final now = DateTime.now();
    final delay = when.difference(now);
    
    // Debug timezone information
    print('Notification Debug:');
    print('  - Current time: ${now.toString()} (${now.timeZoneName} ${now.timeZoneOffset})');
    print('  - Scheduled time: ${when.toString()}');
    print('  - Delay: ${delay.inMinutes} minutes');
    print('  - Local timezone: ${tz.local.name}');
    
    // Check if the scheduled time is in the past
    if (delay.isNegative) {
      print('Notification: Task due time is in the past, showing immediate notification and starting voice');
      // Show immediate notification for overdue task
      await showImmediate(id, 'Overdue: $title', body, payload: payload);
      // Start voice readout immediately
      await startRepeatingReadout(
        id: id, 
        text: 'Overdue reminder: $body', 
        interval: repeatInterval ?? const Duration(seconds: 20), 
        capDuration: repeatCap ?? const Duration(minutes: 5)
      );
      return;
    }

    // Schedule future notification
    try {
      final tz.TZDateTime tzWhen = tz.TZDateTime.from(when, tz.local);
      
      await _fln.zonedSchedule(
        id,
        title,
        body,
        tzWhen,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'todo_channel',
            'Todos',
            channelDescription: 'AI reminders',
            actions: <AndroidNotificationAction>[
              const AndroidNotificationAction('stop', 'Stop Readout'),
              const AndroidNotificationAction('snooze_5', 'Snooze 5m'),
              const AndroidNotificationAction('snooze_10', 'Snooze 10m'),
              const AndroidNotificationAction('snooze_30', 'Snooze 30m'),
              const AndroidNotificationAction('snooze_default', 'Snooze'),
              const AndroidNotificationAction('done', 'Mark Done'),
            ],
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: null,
      );
      
      print('Notification: Scheduled for ${when.toString()} (in ${delay.inMinutes} minutes)');
    } catch (e) {
      print('Failed to schedule notification: $e');
      // If scheduling fails, show immediate notification as fallback
      await showImmediate(id, title, body, payload: payload);
    }

    // In-app fallback: schedule a Timer to start repeating readout at the same time
    _scheduledTimers[id]?.cancel();
    _scheduledTimers[id] = Timer(delay, () {
      startRepeatingReadout(id: id, text: body, interval: repeatInterval ?? const Duration(seconds: 20), capDuration: repeatCap);
    });
  }

  Future<void> showImmediate(int id, String title, String body, {String? payload}) async {
    await _fln.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'todo_channel',
          'Todos',
          channelDescription: 'AI reminders',
  actions: <AndroidNotificationAction>[
    const AndroidNotificationAction('stop', 'Stop Readout'),
    const AndroidNotificationAction('snooze_5', 'Snooze 5m'),
    const AndroidNotificationAction('snooze_10', 'Snooze 10m'),
    const AndroidNotificationAction('snooze_30', 'Snooze 30m'),
    const AndroidNotificationAction('snooze_default', 'Snooze'),
    const AndroidNotificationAction('done', 'Mark Done'),
      ],
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  void _onNotificationResponse(NotificationResponse response) async {
    try {
      final payload = response.payload;
      String? taskId;
      int? notificationId;
      if (payload != null && payload.isNotEmpty) {
        final Map<String, dynamic> p = jsonDecode(payload);
        taskId = p['taskId']?.toString();
        notificationId = p['notificationId'] is int ? p['notificationId'] as int : int.tryParse(p['notificationId']?.toString() ?? '') ?? 0;
        
        // Legacy format support - if new format not found, try old format
        if (taskId == null && p['id'] != null) {
          taskId = p['id'].toString();
          notificationId = safeNotificationId(taskId);
        }
      }
      final actionId = response.actionId;
      if (actionId == 'stop' && notificationId != null) {
        stopRepeatingReadout(notificationId);
        // also emit to UI with task ID for business logic
        _payloadStream.add({'action': 'stop', 'id': taskId});
      } else if ((actionId == 'snooze_5' || actionId == 'snooze_10' || actionId == 'snooze_30' || actionId == 'snooze_default') && taskId != null && notificationId != null) {
        try {
          final repo = HiveTaskRepository();
          final tasks = await repo.list();
          final found = tasks.where((t) => t.id == taskId).toList();
          if (found.isNotEmpty) {
            final task = found.first;
            int minutes = 10;
            if (actionId == 'snooze_5') minutes = 5;
            if (actionId == 'snooze_10') minutes = 10;
            if (actionId == 'snooze_30') minutes = 30;
            if (actionId == 'snooze_default') {
              try {
                final settings = Hive.box('settings_box');
                minutes = settings.get('defaultSnooze', defaultValue: 10) as int;
              } catch (_) {
                minutes = 10;
              }
            }
            final snoozeDuration = Duration(minutes: minutes);
            final snoozeAt = DateTime.now().add(snoozeDuration);
            // schedule a new notification with same text
            await scheduleNotification(
              id: notificationId,
              title: task.title,
              body: task.notes ?? task.title,
              when: snoozeAt,
              repeatInterval: null,
              repeatCap: null,
              payload: jsonEncode({'taskId': taskId, 'notificationId': notificationId}),
            );
            _payloadStream.add({'action': 'snooze', 'id': taskId, 'minutes': minutes});
          }
        } catch (_) {}
      } else if (actionId == 'done' && taskId != null && notificationId != null) {
        // stop readout and delete or mark done in repo
        stopRepeatingReadout(notificationId);
        final repo = HiveTaskRepository();
        await repo.delete(taskId);
        await _fln.cancel(notificationId);
        _payloadStream.add({'action': 'done', 'id': taskId});
      } else if (response.notificationResponseType == NotificationResponseType.selectedNotification) {
        // notification tapped - maybe open app or show details (handled by UI)
        if (payload != null && payload.isNotEmpty) {
          final Map<String, dynamic> p = jsonDecode(payload);
          _payloadStream.add({'action': 'open', ...p});
        }
      }
    } catch (_) {
      // ignore errors
    }
  }

  /// Stream of payload events from notification interactions.
  Stream<Map<String, dynamic>> get notificationStream => _payloadStream.stream;

  Future<void> startRepeatingReadout({
    required int id,
    required String text,
    Duration interval = const Duration(seconds: 20),
    Duration? capDuration,
    int? maxRepeats,
  }) async {
    // Stop existing if any
    stopRepeatingReadout(id);

    // Check user preference for voice reminders. If disabled, keep a controller
    // but perform no TTS so the app will only rely on the visual/local notification.
    bool voiceEnabled = true;
    try {
      final settings = Hive.box('settings_box');
      voiceEnabled = settings.get('voiceReminders', defaultValue: true) as bool;
    } catch (_) {
      voiceEnabled = true;
    }

    final controller = RepeatController(
      interval: interval,
      capDuration: capDuration,
      maxRepeats: maxRepeats,
      onTick: () async {
        if (voiceEnabled) {
          await _tts.speak(text);
        } else {
          // Voice disabled: show a short visual toast (SnackBar) so user still gets a cue.
          try {
            final ctx = navigatorKey.currentContext;
            if (ctx != null) {
              ScaffoldMessenger.of(ctx).clearSnackBars();
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } catch (_) {}
        }
      },
    );

    _activeRepeats[id] = controller;
    controller.start();
    // notify listeners about change
    _activeRepeatsStream.add(_activeRepeats.keys.toSet());
  }

  void stopRepeatingReadout(int id) {
    final c = _activeRepeats.remove(id);
    c?.stop();
    _tts.stop();
    _activeRepeatsStream.add(_activeRepeats.keys.toSet());
  }

  /// Stream of currently active repeating readout ids.
  Stream<Set<int>> get activeRepeatsStream => _activeRepeatsStream.stream;

  /// Whether a repeating readout is currently active for [id].
  bool isRepeating(int id) => _activeRepeats.containsKey(id);

  Future<void> cancel(int id) async {
    stopRepeatingReadout(id);
    await _fln.cancel(id);
  }
  
  /// Cancel notification using task ID string (converts to safe notification ID)
  Future<void> cancelByTaskId(String taskId) async {
    final safeId = safeNotificationId(taskId);
    stopRepeatingReadout(safeId);
    await _fln.cancel(safeId);
  }
}

final notificationService = NotificationService();
