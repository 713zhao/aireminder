
import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/notification_service.dart';
import 'screens/task_detail.dart';
import 'services/app_globals.dart';
import 'data/hive_task_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Google Mobile Ads only on mobile platforms
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      await MobileAds.instance.initialize();
      print('AdMob initialized successfully');
    } catch (e) {
      print('AdMob initialization failed: $e');
    }
  }
  
  await Hive.initFlutter();
  await Hive.openBox('tasks_box');
  await Hive.openBox('tasks_backup_box');
  await Hive.openBox('settings_box');
  await notificationService.init();
  
  // Check for any overdue notifications and start voice reminders
  await _checkOverdueNotifications();
  
  runApp(const AIReminderApp());
}

Future<void> _checkOverdueNotifications() async {
  try {
    final repo = HiveTaskRepository();
    final tasks = await repo.list();
    final now = DateTime.now();
    
    for (final task in tasks) {
      if (task.dueAt != null && task.dueAt!.isBefore(now) && !task.isCompleted) {
        // Task is overdue, check if we should start voice reminder
        final overdueDuration = now.difference(task.dueAt!);
        if (overdueDuration.inMinutes <= 30) { // Only for recently overdue tasks
          final id = NotificationService.safeNotificationId(task.id);
          if (!notificationService.isRepeating(id)) {
            // Start voice reminder for overdue task
            await notificationService.startRepeatingReadout(
              id: id,
              text: 'Overdue reminder: ${task.title}',
              interval: const Duration(seconds: 30),
              capDuration: const Duration(minutes: 5),
            );
          }
        }
      }
    }
  } catch (e) {
    print('Error checking overdue notifications: $e');
  }
}

class AIReminderApp extends StatefulWidget {
  const AIReminderApp({super.key});

  @override
  State<AIReminderApp> createState() => _AIReminderAppState();
}

class _AIReminderAppState extends State<AIReminderApp> {
  @override
  void initState() {
    super.initState();
    notificationService.notificationStream.listen((payload) {
      final action = payload['action'] as String?;
      final id = payload['id']?.toString();
      if (action == 'open' && id != null) {
        navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: id)));
      } else if ((action == 'stop' || action == 'done' || action == 'snooze') && id != null) {
        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          final minutes = payload['minutes'];
          final text = action == 'stop'
              ? 'Stopped readout for task $id'
              : action == 'done'
                  ? 'Marked task $id done'
                  : 'Snoozed task $id for ${minutes ?? 'a few'} minutes';
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(text)));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
  navigatorKey: navigatorKey,
      title: 'AI Reminder',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color.fromARGB(255, 249, 250, 249), // light green background
      ),
      home: const HomeScreen(),
    );
  }
}
