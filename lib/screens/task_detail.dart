import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
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
    
    // Show confirmation dialog
    final confirmed = await _showMarkDoneConfirmation();
    if (!confirmed) return;
    
    // Cancel notification and delete task
    await notificationService.cancelByTaskId(_task!.id);
    await _repo.delete(_task!.id);
    
    if (!mounted) return;
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Task marked as done and deleted permanently'),
        backgroundColor: Colors.green,
      ),
    );
    
    Navigator.of(context).pop();
  }

  Future<bool> _showMarkDoneConfirmation() async {
    final isRecurring = _task?.recurrence != null && _task!.recurrence!.isNotEmpty;
    
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Mark Done'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to mark "${_task!.title}" as done?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will permanently delete the task and cannot be undone.',
              style: TextStyle(color: Colors.red),
            ),
            if (isRecurring) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Recurring Task Warning',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This is a ${_task!.recurrence} recurring task. Marking it done will delete ALL future occurrences permanently.',
                      style: TextStyle(color: Colors.orange.shade800),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isRecurring ? Colors.orange : Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(isRecurring ? 'Delete All Occurrences' : 'Mark Done'),
          ),
        ],
      ),
    ) ?? false;
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Section
            _buildSection(
              icon: Icons.title,
              title: 'Title',
              content: _task!.title,
            ),
            const SizedBox(height: 16),
            
            // Notes Section
            if (_task!.notes != null && _task!.notes!.isNotEmpty) ...[
              _buildSection(
                icon: Icons.notes,
                title: 'Notes',
                content: _task!.notes!,
              ),
              const SizedBox(height: 16),
            ],
            
            // Due Date Section
            _buildSection(
              icon: Icons.event,
              title: 'Due Date',
              content: _task!.dueAt != null 
                ? DateFormat('EEEE, MMM d, yyyy \'at\' h:mm a').format(_task!.dueAt!.toLocal())
                : 'No due date set',
            ),
            const SizedBox(height: 16),
            
            // Recurrence Section
            if (_task!.recurrence != null && _task!.recurrence!.isNotEmpty) ...[
              _buildRecurrenceSection(),
              const SizedBox(height: 16),
            ],
            
            // Reminder Section
            _buildSection(
              icon: Icons.alarm,
              title: 'Reminder',
              content: 'Remind ${_task!.remindBeforeMinutes} minutes before due time',
            ),
            const SizedBox(height: 16),
            
            // Created Date Section
            _buildSection(
              icon: Icons.schedule,
              title: 'Created',
              content: DateFormat('MMM d, yyyy \'at\' h:mm a').format(_task!.createdAt.toLocal()),
            ),
            const SizedBox(height: 16),
            
            // Status Section
            if (_task!.isDisabled) ...[
              _buildSection(
                icon: Icons.pause_circle,
                title: 'Status',
                content: _task!.disabledUntil != null
                  ? 'Disabled until ${DateFormat('MMM d, yyyy \'at\' h:mm a').format(_task!.disabledUntil!.toLocal())}'
                  : 'Currently disabled',
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
            ],
            
            // Sharing Section
            if (_task!.isShared) ...[
              _buildSharingSection(),
              const SizedBox(height: 16),
            ],
            
            // Action Buttons
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _markDone,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Mark Done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _toggleDisable,
                    icon: Icon(_task!.isDisabled ? Icons.play_circle : Icons.pause_circle),
                    label: Text(_task!.isDisabled ? 'Enable' : 'Disable'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _task!.isDisabled ? Colors.blue : Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color?.withOpacity(0.1) ?? Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color?.withOpacity(0.3) ?? Colors.blue.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color ?? Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color ?? Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecurrenceSection() {
    final recurrence = _task!.recurrence!;
    String recurrenceText = '';
    IconData recurrenceIcon = Icons.repeat;
    
    switch (recurrence.toLowerCase()) {
      case 'daily':
        recurrenceText = 'Repeats Daily';
        recurrenceIcon = Icons.calendar_view_day;
        break;
      case 'weekly':
        recurrenceIcon = Icons.calendar_view_week;
        if (_task!.weeklyDays != null && _task!.weeklyDays!.isNotEmpty) {
          final dayNames = _task!.weeklyDays!.map((d) => _getWeekdayName(d)).join(', ');
          recurrenceText = 'Repeats Weekly on $dayNames';
        } else {
          recurrenceText = 'Repeats Weekly';
        }
        break;
      case 'monthly':
        recurrenceText = 'Repeats Monthly';
        recurrenceIcon = Icons.date_range;
        break;
      default:
        recurrenceText = 'Repeats: $recurrence';
    }
    
    if (_task!.recurrenceEndDate != null) {
      final endDateStr = DateFormat('MMM d, yyyy').format(_task!.recurrenceEndDate!.toLocal());
      recurrenceText += '\nEnds on $endDateStr';
    } else {
      recurrenceText += '\nRepeats forever';
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(recurrenceIcon, size: 20, color: Colors.purple.shade700),
              const SizedBox(width: 8),
              Text(
                'Recurrence',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.purple.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            recurrenceText,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSharingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, size: 20, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Text(
                'Sharing',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_task!.ownerId != null)
            Text('Owner: ${_task!.ownerId}', style: const TextStyle(fontSize: 14)),
          if (_task!.sharedWith != null && _task!.sharedWith!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Shared with: ${_task!.sharedWith!.join(", ")}', style: const TextStyle(fontSize: 14)),
          ],
          if (_task!.lastModifiedBy != null) ...[
            const SizedBox(height: 4),
            Text('Last modified by: ${_task!.lastModifiedBy}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ],
      ),
    );
  }
  
  String _getWeekdayName(int weekday) {
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return names[weekday - 1];
  }
}
