import 'package:flutter/material.dart';
import 'dart:async';
import 'package:hive/hive.dart';
import '../data/hive_task_repository.dart';
import '../models/task.dart';
import '../screens/task_detail.dart';
import '../services/notification_service.dart';

class TasksForDate extends StatefulWidget {
  final DateTime date;
  const TasksForDate({super.key, required this.date});

  @override
  State<TasksForDate> createState() => _TasksForDateState();
}

class _TasksForDateState extends State<TasksForDate> {
  final _repo = HiveTaskRepository();
  List<Task> _tasks = [];
  Timer? _tick;
  StreamSubscription<Set<int>>? _activeSub;
  StreamSubscription<BoxEvent>? _repoSub;
  Set<int> _activeIds = {};
  bool _suspendRepoReload = false;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
    try {
      _activeSub = notificationService.activeRepeatsStream.listen((s) {
        setState(() => _activeIds = s);
      });
    } catch (_) {}
    // Watch repository for changes so UI updates when tasks are added/edited/deleted
    try {
      _repoSub = _repo.watch().listen((_) => _onRepoEvent());
    } catch (_) {}
  }

  Future<void> _onRepoEvent() async {
    if (_suspendRepoReload) return;
    await _load();
  }

  @override
  void didUpdateWidget(covariant TasksForDate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!isSameDay(oldWidget.date, widget.date)) _load();
  }

  bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _load() async {
    final all = await _repo.list();
    final filtered = all.where((t) {
      if (t.dueAt == null) return false;
      return _matchesOnDate(t, widget.date);
    }).toList();
    filtered.sort((a, b) => _occurrenceForDate(a, widget.date).compareTo(_occurrenceForDate(b, widget.date)));
    setState(() => _tasks = filtered);
  }

  bool _matchesOnDate(Task t, DateTime date) {
    final due = DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day);
    final target = DateTime(date.year, date.month, date.day);
    if (!target.isAfter(due) && !isSameDay(due, target)) {
      // target before due date
      return false;
    }

    // Check if target date is after recurrence end date
    if (t.recurrenceEndDate != null) {
      final endDate = DateTime(t.recurrenceEndDate!.year, t.recurrenceEndDate!.month, t.recurrenceEndDate!.day);
      if (target.isAfter(endDate)) {
        return false;
      }
    }

    final rec = t.recurrence;
    if (rec == null || rec.isEmpty) {
      return isSameDay(t.dueAt!, date);
    }

    switch (rec) {
      case 'daily':
        return !target.isBefore(due);
      case 'weekly':
        // same weekday and not before start
        if (!target.isBefore(due) && target.weekday == due.weekday) {
          // For weekly tasks, also check if specific weekdays are selected
          if (t.weeklyDays != null && t.weeklyDays!.isNotEmpty) {
            return t.weeklyDays!.contains(target.weekday);
          }
          return true;
        }
        return false;
      case 'monthly':
        // same day-of-month (best-effort)
        if (due.day == target.day && !target.isBefore(due)) return true;
        return false;
      default:
        return isSameDay(t.dueAt!, date);
    }
  }

  DateTime _occurrenceForDate(Task t, DateTime date) {
    // Build occurrence datetime on the target date using time from original dueAt
    final time = t.dueAt!;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute, time.second, time.millisecond, time.microsecond);
  }

  Widget _recurrenceIcon(String? rec) {
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

  // kept for possible programmatic deletes; intentionally not referenced
  // ignore: unused_element
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
    await notificationService.cancel(int.tryParse(t.id) ?? 0);
    await _repo.delete(t.id);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task deleted')));
  }

  /// Called when the user swipes (dismisses) a task. We remove the item
  /// from the visible list immediately (optimistic) and perform the
  /// repository delete in the background so Dismissible is removed from
  /// the tree synchronously as required by Flutter.
  Future<void> _onSwipedDelete(Task t) async {
    // remove locally so the Dismissible is immediately removed from the tree
    setState(() {
      _tasks.removeWhere((x) => x.id == t.id);
    });
    try {
      await notificationService.cancel(int.tryParse(t.id) ?? 0);
    } catch (_) {}
    try {
      _suspendRepoReload = true;
      await _repo.delete(t.id);
      // Ensure we refresh local view after the delete completes (and after any writes propagate)
      await _load();
    } catch (_) {}
    _suspendRepoReload = false;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task deleted')));
  }

  @override
  void dispose() {
    _tick?.cancel();
    _activeSub?.cancel();
    _repoSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tasks.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.inbox, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text('No tasks for this date'),
        ]),
      );
    }

    return ListView.builder(
      itemCount: _tasks.length,
      itemBuilder: (context, i) {
        final t = _tasks[i];
        final occ = _occurrenceForDate(t, widget.date);
        return Dismissible(
          key: Key(t.id),
          direction: DismissDirection.endToStart,
          background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
          onDismissed: (_) => _onSwipedDelete(t),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Card(
              color: _activeIds.contains(int.tryParse(t.id) ?? -1) ? Theme.of(context).colorScheme.secondaryContainer : const Color(0xFFE8F5E9),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: _recurrenceIcon(t.recurrence),
                title: Row(children: [
                  Expanded(child: Text(t.title)),
                  // speaker icon for active readout
                  if (_activeIds.contains(int.tryParse(t.id) ?? -1)) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.volume_up, size: 16, color: Theme.of(context).colorScheme.primary),
                  ],
                ]),
                subtitle: (t.dueAt != null)
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(children: [
                            Text(TimeOfDay.fromDateTime(occ).format(context), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            Text(_remainingText(t, occ), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ]),
                        ],
                      )
                    : null,
                onTap: () async {
                  final id = int.tryParse(t.id) ?? 0;
                  if (_activeIds.contains(id)) {
                    // stop readout immediately
                    notificationService.stopRepeatingReadout(id);
                    setState(() => _activeIds.remove(id));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stopped readout')));
                    return;
                  }
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: t.id)));
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
