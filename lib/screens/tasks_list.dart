import 'package:flutter/material.dart';
import '../data/hive_task_repository.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../widgets/task_form.dart';

class TasksListScreen extends StatefulWidget {
  const TasksListScreen({super.key});

  @override
  State<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends State<TasksListScreen> {
  final _repo = HiveTaskRepository();
  List<Task> _tasks = [];

  Widget? _recurrenceIcon(String? rec) {
    final color = Theme.of(context).colorScheme.primary;
    if (rec == null || rec.isEmpty) return const SizedBox(width: 24);
    switch (rec) {
      case 'daily':
        return Tooltip(message: 'Repeats daily', child: Icon(Icons.calendar_view_day, size: 18, color: color));
      case 'weekly':
        return Tooltip(message: 'Repeats weekly', child: Icon(Icons.calendar_view_week, size: 18, color: color));
      case 'monthly':
        return Tooltip(message: 'Repeats monthly', child: Icon(Icons.date_range, size: 18, color: color));
      default:
        return Tooltip(message: 'Repeats', child: Icon(Icons.repeat, size: 18, color: color));
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.list();
    setState(() => _tasks = list);
  }

  String _remainingText(Task t, DateTime occurrence) {
    final diff = occurrence.difference(DateTime.now());
    if (diff.inSeconds.abs() < 60) return 'due now';
    if (diff.isNegative) {
      final dur = diff.abs();
      final days = dur.inDays;
      final hours = dur.inHours % 24;
      final mins = dur.inMinutes % 60;
      final parts = <String>[];
      if (days > 0) parts.add('$days day${days > 1 ? 's' : ''}');
      if (hours > 0) parts.add('$hours hour${hours > 1 ? 's' : ''}');
      if (mins > 0) parts.add('$mins min${mins > 1 ? 's' : ''}');
      return 'expired ${parts.join(' ')}';
    }
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final mins = diff.inMinutes % 60;
    if (days >= 1) return '${days}d';
    if (hours >= 1) return 'in ${hours}h ${mins}m';
    return 'in ${mins}m';
  }

  Future<void> _delete(Task t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text('Are you sure you want to delete this task? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    await notificationService.cancelByTaskId(t.id);
    await _repo.delete(t.id);
    await _load();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task deleted')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final res = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TaskForm()));
          if (res == true) {
            await _load();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Task created successfully')),
              );
            }
          }
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          itemCount: _tasks.length,
          itemBuilder: (context, i) {
            final t = _tasks[i];
            final occ = t.dueAt ?? t.createdAt;
            return ListTile(
              leading: _recurrenceIcon(t.recurrence),
              title: Text(t.title),
              subtitle: (t.dueAt != null)
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          Text(TimeOfDay.fromDateTime(occ).format(context), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Flexible(child: Text(_remainingText(t, occ), style: const TextStyle(fontSize: 12, color: Colors.grey))),
                        ]),
                      ],
                    )
                  : const Text('No due date'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    final res = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskForm(taskId: t.id)));
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
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _delete(t),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }
}
