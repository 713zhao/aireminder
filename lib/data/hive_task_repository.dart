import 'package:hive/hive.dart';
import 'dart:convert';
import '../models/task.dart';
import '../services/firestore_sync.dart';
// Firestore sync operations are manual; repository no longer auto-pushes.

class HiveTaskRepository {
  HiveTaskRepository()
      : _box = Hive.box('tasks_box'),
        _backup = Hive.box('tasks_backup_box');

  final Box _box;
  final Box _backup;

  /// Stream of box events so UI can listen for changes.
  Stream<BoxEvent> watch() => _box.watch();

  Task? _taskFromStored(dynamic val) {
    try {
      if (val == null) return null;
      if (val is Task) return val;
      if (val is String) {
        final decoded = jsonDecode(val);
        if (decoded is Map) return Task.fromJson(Map<String, dynamic>.from(decoded));
      }
      if (val is Map) {
        return Task.fromJson(Map<String, dynamic>.from(val));
      }
    } catch (_) {}
    return null;
  }

  Future<Task> create({
    required String title,
    DateTime? dueAt,
    String? recurrence,
    String? notes,
    int remindBeforeMinutes = 10,
    DateTime? recurrenceEndDate,
    List<int>? weeklyDays,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final task = Task(
      id: id,
      title: title,
      notes: notes,
      createdAt: DateTime.now(),
      dueAt: dueAt,
      recurrence: recurrence,
      remindBeforeMinutes: remindBeforeMinutes,
      recurrenceEndDate: recurrenceEndDate,
      weeklyDays: weeklyDays,
    );
    await _box.put(id, jsonEncode(task.toJson()));
    try {
      // auto-push removed: signed-in users fetch server data; uploads are manual
    } catch (_) {}
    // store a local backup copy
    try {
      await _backup.put(task.id, jsonEncode(task.toJson()));
      await _backup.put('backup_last_updated', DateTime.now().toIso8601String());
    } catch (_) {}
    return task;
  }

  Future<List<Task>> list() async {
    final List<Task> out = [];
    for (final val in _box.values) {
      try {
        final t = _taskFromStored(val);
        if (t != null && !t.deleted) out.add(t);
      } catch (_) {}
    }
    return out;
  }

  Future<void> delete(String id) async {
    try {
      // Check if user is signed in to determine delete strategy
      bool useHardDelete = true;
      try {
        useHardDelete = !FirestoreSyncService.instance.isSignedIn;
      } catch (_) {
        // If we can't check sign-in status, default to hard delete for offline safety
        useHardDelete = true;
      }

      final val = _box.get(id);
      final t = _taskFromStored(val);
      
      if (useHardDelete) {
        // Offline user: perform hard delete (actually remove from box)
        await _box.delete(id);
        try {
          await _backup.delete(id);
          await _backup.put('backup_last_updated', DateTime.now().toIso8601String());
        } catch (_) {}
      } else {
        // Signed-in user: use tombstone for server sync
        if (t != null) {
          t.deleted = true;
          await _box.put(id, jsonEncode(t.toJson()));
          try {
            await _backup.delete(id);
            await _backup.put('backup_last_updated', DateTime.now().toIso8601String());
          } catch (_) {}
        } else {
          await _box.delete(id);
          try {
            await _backup.delete(id);
            await _backup.put('backup_last_updated', DateTime.now().toIso8601String());
          } catch (_) {}
        }
      }
    } catch (_) {
      // Fallback: always try hard delete if anything fails
      try { await _box.delete(id); } catch (_) {}
    }
  }

  /// Save or overwrite a task using its id. Used for undoing deletes.
  Future<void> save(Task task) async {
    await _box.put(task.id, jsonEncode(task.toJson()));
    try {
      // auto-push removed
    } catch (_) {}
    try {
      await _backup.put(task.id, jsonEncode(task.toJson()));
      await _backup.put('backup_last_updated', DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Restore tasks from the local backup into the active tasks box.
  Future<void> restoreFromBackup() async {
    for (final val in _backup.values) {
      try {
        final Map<String, dynamic> j = jsonDecode(val as String);
        final t = Task.fromJson(j);
        await _box.put(t.id, jsonEncode(t.toJson()));
      } catch (_) {}
    }
  }
}
