import 'package:flutter_test/flutter_test.dart';
import 'package:aireminder/services/import_export_service.dart';
import 'package:aireminder/models/task.dart';
import 'dart:convert';

void main() {
  group('ImportExportService', () {
    final service = ImportExportService.instance;

    // Sample task for testing
    Task createSampleTask({
      String id = '1',
      String title = 'Test Task',
      String? notes,
      bool isCompleted = false,
    }) {
      return Task(
        id: id,
        title: title,
        notes: notes,
        createdAt: DateTime(2026, 2, 20),
        dueAt: DateTime(2026, 2, 22),
        recurrence: 'weekly',
        isCompleted: isCompleted,
        remindBeforeMinutes: 10,
      );
    }

    group('exportToJsonString', () {
      test('should export tasks with metadata', () {
        final tasks = [
          createSampleTask(id: '1', title: 'Task 1'),
          createSampleTask(id: '2', title: 'Task 2'),
        ];

        final result = service.exportToJsonString(tasks);
        final decoded = jsonDecode(result);

        expect(decoded['metadata']['taskCount'], equals(2));
        expect(decoded['metadata']['version'], equals('1.0'));
        expect(decoded['tasks'], hasLength(2));
        expect(decoded['tasks'][0]['title'], equals('Task 1'));
      });

      test('should include all task fields', () {
        final task = createSampleTask(
          id: '123',
          title: 'Complete task',
          notes: 'Test notes',
          isCompleted: true,
        );

        final result = service.exportToJsonString([task]);
        final decoded = jsonDecode(result);
        final exportedTask = decoded['tasks'][0];

        expect(exportedTask['id'], equals('123'));
        expect(exportedTask['title'], equals('Complete task'));
        expect(exportedTask['notes'], equals('Test notes'));
        expect(exportedTask['isCompleted'], equals(true));
        expect(exportedTask['remindBeforeMinutes'], equals(10));
      });

      test('should handle empty task list', () {
        final result = service.exportToJsonString([]);
        final decoded = jsonDecode(result);

        expect(decoded['metadata']['taskCount'], equals(0));
        expect(decoded['tasks'], isEmpty);
      });
    });

    group('importFromJsonString', () {
      test('should import valid tasks', () async {
        const jsonString = '''{
          "metadata": {"version": "1.0", "taskCount": 1},
          "tasks": [
            {
              "id": "1",
              "title": "Imported task",
              "notes": null,
              "createdAt": "2026-02-20T10:00:00.000Z",
              "dueAt": "2026-02-22T18:00:00.000Z",
              "recurrence": null,
              "isCompleted": false,
              "completedAt": null,
              "reminderId": null,
              "isDisabled": false,
              "disabledUntil": null,
              "remindBeforeMinutes": 10,
              "recurrenceEndDate": null,
              "weeklyDays": null,
              "ownerId": null,
              "sharedWith": null,
              "isShared": false,
              "lastModifiedBy": null,
              "serverId": null,
              "updatedAt": null,
              "deleted": false,
              "version": 0
            }
          ]
        }''';

        final result = await service.importFromJsonString(jsonString);

        expect(result.tasks, hasLength(1));
        expect(result.tasks[0].title, equals('Imported task'));
        expect(result.tasks[0].id, equals('1'));
      });

      test('should detect missing required fields', () async {
        const jsonString = '''{
          "tasks": [
            {
              "id": "1",
              "title": "Task without createdAt"
            },
            {
              "createdAt": "2026-02-20T10:00:00.000Z",
              "title": "Task without id"
            }
          ]
        }''';

        final result = await service.importFromJsonString(jsonString);

        expect(result.tasks, isEmpty);
        expect(result.errors, isNotEmpty);
        expect(result.errors.length, greaterThanOrEqualTo(2));
      });

      test('should handle single task object (not array)', () async {
        const jsonString = '''{
          "id": "1",
          "title": "Single task",
          "notes": null,
          "createdAt": "2026-02-20T10:00:00.000Z",
          "dueAt": null,
          "recurrence": null,
          "isCompleted": false,
          "completedAt": null,
          "reminderId": null,
          "isDisabled": false,
          "disabledUntil": null,
          "remindBeforeMinutes": 10,
          "recurrenceEndDate": null,
          "weeklyDays": null,
          "ownerId": null,
          "sharedWith": null,
          "isShared": false,
          "lastModifiedBy": null,
          "serverId": null,
          "updatedAt": null,
          "deleted": false,
          "version": 0
        }''';

        final result = await service.importFromJsonString(jsonString);

        expect(result.tasks, hasLength(1));
        expect(result.tasks[0].title, equals('Single task'));
      });

      test('should collect all errors when skipInvalidTasks is true', () async {
        const jsonString = '''{
          "tasks": [
            {
              "id": "1",
              "title": "Valid task",
              "createdAt": "2026-02-20T10:00:00.000Z",
              "isCompleted": false,
              "remindBeforeMinutes": 10
            },
            {
              "id": "2"
            },
            {
              "title": "Missing id",
              "createdAt": "2026-02-20T10:00:00.000Z"
            }
          ]
        }''';

        final result = await service.importFromJsonString(
          jsonString,
          skipInvalidTasks: true,
        );

        expect(result.tasks, hasLength(1));
        expect(result.errors.length, greaterThanOrEqualTo(2));
      });

      test('should throw when skipInvalidTasks is false and error found', () async {
        const jsonString = '''{
          "tasks": [
            {
              "id": "1",
              "title": "Task"
            }
          ]
        }''';

        expect(
          () => service.importFromJsonString(
            jsonString,
            skipInvalidTasks: false,
          ),
          throwsException,
        );
      });
    });

    group('exportToCsvString', () {
      test('should export to CSV format', () {
        final tasks = [
          createSampleTask(id: '1', title: 'Buy milk', notes: 'Low-fat milk'),
          createSampleTask(id: '2', title: 'Call dentist', isCompleted: true),
        ];

        final csv = service.exportToCsvString(tasks);

        expect(csv, contains('Title,Notes,Created'));
        expect(csv, contains('Buy milk'));
        expect(csv, contains('Call dentist'));
        expect(csv, contains('Completed'));
        expect(csv, contains('Pending'));
      });

      test('should escape CSV special characters', () {
        final task = createSampleTask(
          id: '1',
          title: 'Task with "quotes"',
          notes: 'Notes, with, commas',
        );

        final csv = service.exportToCsvString([task]);

        expect(csv, contains('"Task with ""quotes"""'));
        expect(csv, contains('"Notes, with, commas"'));
      });

      test('should handle null values in CSV', () {
        final task = Task(
          id: '1',
          title: 'Minimal task',
          createdAt: DateTime(2026, 2, 20),
        );

        final csv = service.exportToCsvString([task]);

        expect(csv, contains('Minimal task'));
        expect(csv, contains('Pending')); // status
      });
    });

    group('Round-trip export/import', () {
      test('should preserve data through export and import cycle', () async {
        final originalTasks = [
          createSampleTask(
            id: '1',
            title: 'Task 1',
            notes: 'Notes for task 1',
          ),
          createSampleTask(
            id: '2',
            title: 'Task 2',
            isCompleted: true,
          ),
        ];

        // Export
        final jsonString = service.exportToJsonString(originalTasks);

        // Import
        final result = await service.importFromJsonString(jsonString);

        // Verify
        expect(result.tasks, hasLength(2));
        expect(result.errors, isEmpty);
        expect(result.tasks[0].title, equals('Task 1'));
        expect(result.tasks[0].notes, equals('Notes for task 1'));
        expect(result.tasks[1].isCompleted, equals(true));
      });
    });
  });
}
