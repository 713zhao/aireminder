import 'package:uuid/uuid.dart';
import '../models/task.dart';

class TaskRepository {
  TaskRepository();

  final Map<String, Task> _store = {};
  final _uuid = const Uuid();

  Future<Task> create({required String title, DateTime? dueAt, String? recurrence, String? notes}) async {
    final id = _uuid.v4();
    final task = Task(id: id, title: title, notes: notes, createdAt: DateTime.now(), dueAt: dueAt, recurrence: recurrence);
    _store[id] = task;
    return task;
  }

  Future<List<Task>> list() async => _store.values.toList();

  Future<void> delete(String id) async {
    _store.remove(id);
  }
}
