import 'package:hive/hive.dart';
import 'dart:convert';
import 'models/task.dart';

void main() async {
  // Initialize Hive
  Hive.init('.');
  Hive.registerAdapter(TaskAdapter());
  
  // Open the tasks box
  final box = await Hive.openBox('tasks_box');
  
  print('Total tasks in local Hive: ${box.length}');
  print('\n--- Task IDs in local storage ---');
  for (final key in box.keys) {
    final val = box.get(key);
    if (val is String) {
      try {
        final json = jsonDecode(val);
        final task = Task.fromJson(json);
        print('ID: ${task.id}');
        print('  Title: ${task.title}');
        print('  DueAt: ${task.dueAt}');
        print('  Deleted: ${task.deleted}');
        print('');
      } catch (e) {
        print('Error parsing task $key: $e');
      }
    }
  }
  
  // Check specific task
  const targetId = '1771765574048000';
  print('\n--- Checking task $targetId ---');
  final taskVal = box.get(targetId);
  if (taskVal != null) {
    if (taskVal is String) {
      final json = jsonDecode(taskVal);
      print('Found in local Hive:');
      print(jsonEncode(json));
    }
  } else {
    print('NOT found in local Hive');
  }
  
  await Hive.close();
}
