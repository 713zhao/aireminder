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
          channelDescription: 'Todo reminders',
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

    // In-app fallback: if app is running, schedule a Timer to start repeating readout at the same time
    final now = DateTime.now();
    final delay = when.difference(now);
    if (delay.isNegative) {
      // If time already passed, trigger immediately
      startRepeatingReadout(id: id, text: body, interval: repeatInterval ?? const Duration(seconds: 20), capDuration: repeatCap);
    } else {
      _scheduledTimers[id]?.cancel();
      _scheduledTimers[id] = Timer(delay, () {
        startRepeatingReadout(id: id, text: body, interval: repeatInterval ?? const Duration(seconds: 20), capDuration: repeatCap);
      });
    }
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
          channelDescription: 'Todo reminders',
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
      int? id;
      if (payload != null && payload.isNotEmpty) {
        final Map<String, dynamic> p = jsonDecode(payload);
        id = p['id'] is int ? p['id'] as int : int.tryParse(p['id']?.toString() ?? '');
      }
      final actionId = response.actionId;
      if (actionId == 'stop' && id != null) {
        stopRepeatingReadout(id);
        // also emit to UI
        _payloadStream.add({'action': 'stop', 'id': id});
      } else if ((actionId == 'snooze_5' || actionId == 'snooze_10' || actionId == 'snooze_30' || actionId == 'snooze_default') && id != null) {
        try {
          final repo = HiveTaskRepository();
          final tasks = await repo.list();
          final found = tasks.where((t) => t.id == id.toString()).toList();
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
              id: id,
              title: task.title,
              body: task.notes ?? task.title,
              when: snoozeAt,
              repeatInterval: null,
              repeatCap: null,
              payload: jsonEncode({'id': id}),
            );
            _payloadStream.add({'action': 'snooze', 'id': id, 'minutes': minutes});
          }
        } catch (_) {}
      } else if (actionId == 'done' && id != null) {
        // stop readout and delete or mark done in repo
        stopRepeatingReadout(id);
        final repo = HiveTaskRepository();
        await repo.delete(id.toString());
        await _fln.cancel(id);
        _payloadStream.add({'action': 'done', 'id': id});
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
}

final notificationService = NotificationService();
