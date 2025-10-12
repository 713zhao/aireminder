import 'package:flutter/material.dart';
import 'dart:convert';
import '../data/hive_task_repository.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../widgets/task_form.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _repo = HiveTaskRepository();
  Task? _task;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.list();
    final found = list.where((t) => t.id == widget.taskId).toList();
    setState(() => _task = found.isNotEmpty ? found.first : null);
  }

  Future<void> _markDone() async {
    if (_task == null) return;
    await notificationService.cancelByTaskId(_task!.id);
    await _repo.delete(_task!.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _toggleDisable() async {
    if (_task == null) return;
    final now = DateTime.now();
    if (!_task!.isDisabled) {
      // disable temporarily: ask for until date/time
      final date = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 3650)));
      if (date == null) return;
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time == null) return;
      _task = Task(
        id: _task!.id,
        title: _task!.title,
        notes: _task!.notes,
        createdAt: _task!.createdAt,
        dueAt: _task!.dueAt,
        recurrence: _task!.recurrence,
        isCompleted: _task!.isCompleted,
        completedAt: _task!.completedAt,
        reminderId: _task!.reminderId,
        isDisabled: true,
        disabledUntil: DateTime(date.year, date.month, date.day, time.hour, time.minute),
      );
      // cancel current scheduled notification
      await notificationService.cancelByTaskId(_task!.id);
      await _repo.save(_task!);
    } else {
      // enable again
      _task = Task(
        id: _task!.id,
        title: _task!.title,
        notes: _task!.notes,
        createdAt: _task!.createdAt,
        dueAt: _task!.dueAt,
        recurrence: _task!.recurrence,
        isCompleted: _task!.isCompleted,
        completedAt: _task!.completedAt,
        reminderId: _task!.reminderId,
        isDisabled: false,
        disabledUntil: null,
      );
      await _repo.save(_task!);
      // reschedule if dueAt exists
      if (_task!.dueAt != null) {
        final id = NotificationService.safeNotificationId(_task!.id);
        await notificationService.scheduleNotification(
          id: id,
          title: _task!.title,
          body: _task!.notes ?? _task!.title,
          when: _task!.dueAt!,
          repeatInterval: _task!.recurrence == 'daily' ? const Duration(days: 1) : null,
          repeatCap: null,
          payload: jsonEncode({'taskId': _task!.id, 'notificationId': id}),
        );
      }
    }
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_task == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text(_task!.title), actions: [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () async {
            final res = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskForm(taskId: _task!.id)));
            if (res == true) {
              await _load();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Task updated successfully')),
                );
              }
            }
          },
        ),
      ]),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Title: ${_task!.title}'),
          const SizedBox(height: 8),
          Text('Due: ${_task!.dueAt?.toLocal().toString() ?? 'None'}'),
          const SizedBox(height: 16),
          Row(children: [
            ElevatedButton(onPressed: _markDone, child: const Text('Mark Done')),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: _toggleDisable, child: Text(_task!.isDisabled ? 'Enable' : 'Disable')),
          ]),
        ]),
      ),
    );
  }
}
