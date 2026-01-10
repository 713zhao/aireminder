import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../data/hive_task_repository.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../services/firestore_sync.dart';

class TaskForm extends StatefulWidget {
  final String? taskId;
  final String? initialTitle;
  final String? initialNotes;
  final DateTime? initialDueAt;
  final String? initialRecurrence;
  final Set<int>? initialWeeklyDays;
  final DateTime? initialRecurrenceEndDate;
  
  const TaskForm({
    super.key, 
    this.taskId, 
    this.initialTitle,
    this.initialNotes,
    this.initialDueAt,
    this.initialRecurrence,
    this.initialWeeklyDays,
    this.initialRecurrenceEndDate,
  });

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _dueAt;
  String _recurrence = 'none';
  int _remindBeforeMinutes = 10;
  DateTime? _recurrenceEndDate;
  Set<int> _weeklyDays = {};

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    
    // Set initial values if provided
    if (widget.initialTitle != null) {
      _titleCtrl.text = widget.initialTitle!;
    }
    if (widget.initialNotes != null) {
      _notesCtrl.text = widget.initialNotes!;
    }
    if (widget.initialDueAt != null) {
      _dueAt = widget.initialDueAt;
    }
    if (widget.initialRecurrence != null) {
      _recurrence = widget.initialRecurrence!;
    }
    if (widget.initialWeeklyDays != null) {
      _weeklyDays = widget.initialWeeklyDays!;
    }
    if (widget.initialRecurrenceEndDate != null) {
      _recurrenceEndDate = widget.initialRecurrenceEndDate;
    }
    
    if (widget.taskId != null) {
      // load and prefill existing task
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final repo = HiveTaskRepository();
        final all = await repo.list();
        final existingList = all.where((t) => t.id == widget.taskId).toList();
        if (existingList.isNotEmpty) {
          final existing = existingList.first;
          _titleCtrl.text = existing.title;
          _notesCtrl.text = existing.notes ?? '';
          _dueAt = existing.dueAt;
          _recurrence = existing.recurrence ?? 'none';
          _remindBeforeMinutes = existing.remindBeforeMinutes;
          _recurrenceEndDate = existing.recurrenceEndDate;
          _weeklyDays = existing.weeklyDays?.toSet() ?? {};
          // Auto-select current weekday if it's a new weekly task
          if (_recurrence == 'weekly' && _dueAt != null && _weeklyDays.isEmpty) {
            _weeklyDays = {_dueAt!.weekday};
          }
          if (mounted) setState(() {});
        }
      });
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: now.subtract(const Duration(days: 1)), // Allow yesterday for flexibility
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _dueAt != null ? TimeOfDay.fromDateTime(_dueAt!) : TimeOfDay.now(),
    );
    if (time == null) return;
    
    final selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    
    // Warn if selected time is in the past
    if (selectedDateTime.isBefore(now)) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Past Due Date'),
          content: Text(
            'The selected time (${DateFormat.yMd().add_jm().format(selectedDateTime)}) is in the past. '
            'This task will be marked as overdue and voice reminders will start immediately.\n\n'
            'Do you want to continue?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      
      if (shouldProceed != true) return;
    }
    
    setState(() {
      _dueAt = selectedDateTime;
      // Auto-select current weekday for weekly recurrence
      if (_recurrence == 'weekly') {
        _weeklyDays = {_dueAt!.weekday};
      }
    });
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _recurrenceEndDate ?? (_dueAt ?? DateTime.now()).add(const Duration(days: 30)),
      firstDate: _dueAt ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date != null) {
      setState(() {
        _recurrenceEndDate = DateTime(date.year, date.month, date.day, 23, 59, 59);
      });
    }
  }

  void _onRecurrenceChanged(String? value) {
    setState(() {
      _recurrence = value ?? 'none';
      if (_recurrence == 'weekly' && _dueAt != null) {
        // Auto-select current weekday for weekly recurrence
        _weeklyDays = {_dueAt!.weekday};
      } else if (_recurrence == 'none') {
        _recurrenceEndDate = null;
        _weeklyDays.clear();
      }
    });
  }

  String _weekdayName(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[weekday - 1];
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      final repo = HiveTaskRepository();
      Task? newOrUpdated;
      
      if (widget.taskId == null) {
        // Creating new task
        newOrUpdated = await repo.create(
          title: _titleCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          dueAt: _dueAt,
          recurrence: _recurrence == 'none' ? null : _recurrence,
          remindBeforeMinutes: _remindBeforeMinutes,
          recurrenceEndDate: _recurrenceEndDate,
          weeklyDays: _weeklyDays.isEmpty ? null : _weeklyDays.toList(),
        );
      } else {
        // Updating existing task
        final all = await repo.list();
        final existing = all.firstWhere((t) => t.id == widget.taskId, orElse: () => throw StateError('task not found'));
        // Set modification info when updating
        String? lastModifiedBy;
        try {
          if (FirestoreSyncService.instance.isSignedIn) {
            lastModifiedBy = FirestoreSyncService.instance.currentUserEmail;
          }
        } catch (_) {}
        
        final updated = Task(
          id: existing.id,
          title: _titleCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          createdAt: existing.createdAt,
          dueAt: _dueAt,
          recurrence: _recurrence == 'none' ? null : _recurrence,
          isCompleted: existing.isCompleted,
          completedAt: existing.completedAt,
          reminderId: existing.reminderId,
          remindBeforeMinutes: _remindBeforeMinutes,
          recurrenceEndDate: _recurrenceEndDate,
          weeklyDays: _weeklyDays.isEmpty ? null : _weeklyDays.toList(),
          ownerId: existing.ownerId, // Preserve original owner
          sharedWith: existing.sharedWith, // Preserve sharing settings
          isShared: existing.isShared,
          lastModifiedBy: lastModifiedBy,
        );
        await repo.save(updated);
        newOrUpdated = updated;
      }

      // Schedule notification if task has due date
      if (newOrUpdated.dueAt != null) {
        try {
          final id = NotificationService.safeNotificationId(newOrUpdated.id);
          final reminderTime = newOrUpdated.dueAt!.subtract(Duration(minutes: newOrUpdated.remindBeforeMinutes));
          await notificationService.scheduleNotification(
            id: id,
            title: newOrUpdated.title,
            body: newOrUpdated.notes ?? newOrUpdated.title,
            when: reminderTime,
            repeatInterval: newOrUpdated.recurrence == 'daily' ? const Duration(days: 1) : null,
            repeatCap: null,
            payload: jsonEncode({'taskId': newOrUpdated.id, 'notificationId': id}),
          );
        } catch (e) {
          // Log notification error but don't prevent task save
          print('Failed to schedule notification: $e');
        }
      }

      // Navigate back with success
      if (!mounted) return;
      Navigator.of(context).pop(true);
      
    } catch (e) {
      // Show error message and stay on form
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save task: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.taskId == null ? 'Create Task' : 'Edit Task')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Title required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(_dueAt != null ? 'Due: ${DateFormat.yMd().add_jm().format(_dueAt!.toLocal())}' : 'No due date'),
                  ),
                  TextButton(onPressed: _pickDateTime, child: const Text('Pick')),
                ],
              ),
              const SizedBox(height: 12),
              // Remind Before Time input
              Row(
                children: [
                  Expanded(
                    child: Text('Remind Before: $_remindBeforeMinutes minutes'),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      initialValue: _remindBeforeMinutes.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minutes',
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onChanged: (v) {
                        final parsed = int.tryParse(v);
                        if (parsed != null && parsed >= 0) {
                          setState(() => _remindBeforeMinutes = parsed);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _recurrence,
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('One Time (no repeat)')),
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                ],
                onChanged: _onRecurrenceChanged,
                decoration: const InputDecoration(labelText: 'Recurrence'),
              ),
              const SizedBox(height: 12),
              // End Date for recurring tasks
              if (_recurrence != 'none') ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(_recurrenceEndDate != null
                          ? 'End Date: ${DateFormat.yMd().format(_recurrenceEndDate!.toLocal())}'
                          : 'No end date (repeats forever)'),
                    ),
                    TextButton(onPressed: _pickEndDate, child: const Text('Pick')),
                    if (_recurrenceEndDate != null)
                      TextButton(
                        onPressed: () => setState(() => _recurrenceEndDate = null),
                        child: const Text('Clear'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              // Weekly days selection
              if (_recurrence == 'weekly') ...[
                const Text('Select days:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: List.generate(7, (index) {
                    final weekday = index + 1; // 1=Monday, 7=Sunday
                    final isSelected = _weeklyDays.contains(weekday);
                    return FilterChip(
                      label: Text(_weekdayName(weekday)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _weeklyDays.add(weekday);
                          } else {
                            _weeklyDays.remove(weekday);
                          }
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
  }
}
