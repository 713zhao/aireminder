
import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/notification_service.dart';
import 'screens/task_detail.dart';
import 'services/app_globals.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('tasks_box');
  await Hive.openBox('tasks_backup_box');
  await Hive.openBox('settings_box');
  await notificationService.init();
  runApp(const TodoReminderApp());
}

class TodoReminderApp extends StatefulWidget {
  const TodoReminderApp({super.key});

  @override
  State<TodoReminderApp> createState() => _TodoReminderAppState();
}

class _TodoReminderAppState extends State<TodoReminderApp> {
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
      title: 'Todo Reminder App',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color.fromARGB(255, 249, 250, 249), // light green background
      ),
      home: const HomeScreen(),
    );
  }
}
