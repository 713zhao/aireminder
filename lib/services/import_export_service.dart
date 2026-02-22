import 'dart:convert';
import 'dart:io' as io show Directory, File, FileSystemException;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import '../models/task.dart';
import '../data/hive_task_repository.dart';

/// Service for importing and exporting reminders to/from JSON format
class ImportExportService {
  static final ImportExportService _instance = ImportExportService._internal();

  factory ImportExportService() => _instance;

  ImportExportService._internal();

  static ImportExportService get instance => _instance;

  /// Export metadata included in backup files
  static const String _backupVersion = '1.0';

  /// Export all tasks to a JSON string with metadata
  /// 
  /// Returns a pretty-printed JSON string containing:
  /// - metadata (timestamp, version, task count)
  /// - tasks array with all task data
  String exportToJsonString(List<Task> tasks) {
    final backup = {
      'metadata': {
        'exportedAt': DateTime.now().toIso8601String(),
        'version': _backupVersion,
        'taskCount': tasks.length,
        'appVersion': '1.3.0', // Consider getting this from pubspec
      },
      'tasks': tasks.map((t) => t.toJson()).toList(),
    };
    // Use pretty-printed JSON with 2-space indentation
    return JsonEncoder.withIndent('  ').convert(backup);
  }

  /// Export tasks to a file in the app's documents directory
  /// 
  /// On native platforms: saves to documents directory and returns file path
  /// On web: updates _lastExportedJson for UI handling
  Future<String> exportToFile(
    List<Task> tasks, {
    String? fileName,
  }) async {
    try {
      final jsonString = exportToJsonString(tasks);
      final String timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final String filename = fileName ?? 'aireminder_backup_$timestamp.json';
      
      if (kIsWeb) {
        // Web: Store for widget to handle download
        lastExportedJson = jsonString;
        lastExportFileName = filename;
        return 'Export ready: $filename';
      } else {
        // Native: Save to documents directory
        final io.Directory dir = await path_provider.getApplicationDocumentsDirectory();
        final io.File file = io.File('${dir.path}/$filename');
        await file.writeAsString(jsonString);
        return file.path;
      }
    } catch (e) {
      throw Exception('Failed to export tasks: $e');
    }
  }

  // Storage for web export
  static String? lastExportedJson;
  static String? lastExportFileName;

  /// Import tasks from a JSON string
  /// 
  /// Validates the JSON structure and checks for required fields.
  /// Returns list of imported tasks and list of any import errors.
  Future<({List<Task> tasks, List<String> errors})> importFromJsonString(
    String jsonString, {
    bool skipInvalidTasks = true,
  }) async {
    try {
      final decoded = jsonDecode(jsonString);

      final tasks = <Task>[];
      final errors = <String>[];

      // Handle both direct task arrays and backup format with metadata
      List<dynamic> tasksList = [];
      
      if (decoded is Map) {
        if (decoded.containsKey('tasks')) {
          // New backup format with metadata
          final tasksData = decoded['tasks'];
          if (tasksData is List) {
            tasksList = tasksData;
          }
        } else if (decoded.containsKey('id')) {
          // Single task object
          tasksList = [decoded];
        }
      } else if (decoded is List) {
        // Direct array of tasks
        tasksList = decoded;
      } else {
        throw FormatException('Invalid JSON format: expected object or array');
      }

      for (int i = 0; i < tasksList.length; i++) {
        try {
          final taskData = tasksList[i];
          if (taskData is! Map) {
            errors.add('Task $i: Invalid format (expected object)');
            continue;
          }

          final Map<String, dynamic> taskMap = Map<String, dynamic>.from(taskData);
          
          // Validate required fields
          if (!taskMap.containsKey('id') || taskMap['id'] == null) {
            errors.add('Task $i: Missing required field "id"');
            if (!skipInvalidTasks) throw Exception('Missing id');
            continue;
          }
          
          if (!taskMap.containsKey('title') || taskMap['title'] == null) {
            errors.add('Task $i: Missing required field "title"');
            if (!skipInvalidTasks) throw Exception('Missing title');
            continue;
          }

          if (!taskMap.containsKey('createdAt') || taskMap['createdAt'] == null) {
            errors.add('Task $i: Missing required field "createdAt"');
            if (!skipInvalidTasks) throw Exception('Missing createdAt');
            continue;
          }

          try {
            final task = Task.fromJson(taskMap);
            tasks.add(task);
          } catch (e) {
            errors.add('Task $i (${taskMap['title']}): Parse error: $e');
            if (!skipInvalidTasks) throw Exception('Failed to parse task: $e');
          }
        } catch (e) {
          errors.add('Task $i: Unexpected error: $e');
          if (!skipInvalidTasks) rethrow;
        }
      }

      return (tasks: tasks, errors: errors);
    } catch (e) {
      throw Exception('Failed to import tasks: $e');
    }
  }

  /// Import tasks from a file
  /// 
  /// Reads the file content and processes it using importFromJsonString
  /// On web: file is a PlatformFile, on native: file is io.File
  Future<({List<Task> tasks, List<String> errors})> importFromFile(
    dynamic file, {
    bool skipInvalidTasks = true,
  }) async {
    try {
      String content;
      
      if (kIsWeb) {
        // Web: file is a PlatformFile from file_picker
        if (file is Map && file['bytes'] != null) {
          // PlatformFile has bytes
          content = utf8.decode(file['bytes'] as List<int>);
        } else {
          throw Exception('Unable to read file');
        }
      } else {
        // Native: file is io.File
        final ioFile = file as io.File;
        if (!await ioFile.exists()) {
          throw io.FileSystemException('File not found: ${ioFile.path}');
        }
        content = await ioFile.readAsString();
      }
      
      return await importFromJsonString(content, skipInvalidTasks: skipInvalidTasks);
    } catch (e) {
      throw Exception('Failed to import from file: $e');
    }
  }

  /// Merge imported tasks with existing tasks in the repository
  /// 
  /// Options for handling duplicates:
  /// - 'skip': Keep existing tasks (do nothing)
  /// - 'replace': Overwrite existing tasks
  /// - 'merge': Add new ones, skip existing
  Future<({int imported, int skipped, List<String> errors})> mergeTasksIntoRepository(
    HiveTaskRepository repository,
    List<Task> importedTasks, {
    String duplicateHandling = 'skip',
    bool updateTimestamps = true,
  }) async {
    try {
      final existingTasks = await repository.list();
      final existingIds = {for (var t in existingTasks) t.id};
      
      int imported = 0;
      int skipped = 0;
      final errors = <String>[];

      for (final task in importedTasks) {
        try {
          final isExisting = existingIds.contains(task.id);

          if (isExisting && duplicateHandling == 'skip') {
            skipped++;
            continue;
          }

          // Update timestamps if importing fresh data
          if (updateTimestamps && !isExisting) {
            task.updatedAt = DateTime.now();
          }

          await repository.save(task);
          imported++;
        } catch (e) {
          errors.add('Failed to import task ${task.id}: $e');
        }
      }

      return (imported: imported, skipped: skipped, errors: errors);
    } catch (e) {
      throw Exception('Failed to merge tasks: $e');
    }
  }

  /// Create a timestamped backup file in documents directory
  /// 
  /// This is useful for automatic or manual backup operations
  Future<String> createBackup(
    List<Task> tasks, {
    String? customLabel,
  }) async {
    final label = customLabel ?? DateTime.now().toIso8601String().split('T')[0];
    final filename = 'aireminder_backup_$label.json';
    return await exportToFile(tasks, fileName: filename);
  }

  /// Get list of backup files in the documents directory
  /// 
  /// Returns list of backup file paths sorted by date (newest first)
  /// Note: Returns empty list on web platform
  Future<List<io.File>> listBackups() async {
    try {
      if (kIsWeb) {
        // Web doesn't support local file system
        return [];
      }
      
      final io.Directory dir = await path_provider.getApplicationDocumentsDirectory();
      final files = dir
          .listSync()
          .whereType<io.File>()
          .where((f) => f.path.contains('aireminder_backup_') && f.path.endsWith('.json'))
          .toList();
      
      // Sort by creation time (newest first)
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      return files;
    } catch (e) {
      throw Exception('Failed to list backups: $e');
    }
  }

  /// Export to CSV format for spreadsheet viewing
  /// 
  /// Exports task summary data as CSV (simpler format than JSON)
  String exportToCsvString(List<Task> tasks) {
    final buffer = StringBuffer();
    
    // CSV Header with time information
    buffer.writeln('Title,Notes,Created Date Time,Due Date Time,Status,Completed Date Time,Recurrence,Reminder Time (min)');
    
    // CSV Data rows
    for (final task in tasks) {
      final escapeCsv = (String? value) {
        if (value == null) return '';
        // Escape quotes and wrap in quotes if contains comma, quote, or newline
        final escaped = value.replaceAll('"', '""');
        if (escaped.contains(',') || escaped.contains('"') || escaped.contains('\n')) {
          return '"$escaped"';
        }
        return escaped;
      };

      // Format DateTime with time
      final createdDateTime = task.createdAt.toIso8601String().replaceFirst('T', ' ').substring(0, 16);
      final dueDateTime = task.dueAt != null 
          ? task.dueAt!.toIso8601String().replaceFirst('T', ' ').substring(0, 16)
          : '';
      final completedDateTime = task.completedAt != null
          ? task.completedAt!.toIso8601String().replaceFirst('T', ' ').substring(0, 16)
          : '';

      buffer.writeln([
        escapeCsv(task.title),
        escapeCsv(task.notes),
        createdDateTime,
        dueDateTime,
        task.isCompleted ? 'Completed' : 'Pending',
        completedDateTime,
        escapeCsv(task.recurrence),
        task.remindBeforeMinutes.toString(),
      ].join(','));
    }
    
    return buffer.toString();
  }

  /// Export to CSV file
  Future<String> exportToCsvFile(
    List<Task> tasks, {
    String? fileName,
  }) async {
    try {
      final csvString = exportToCsvString(tasks);
      final String timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final String filename = fileName ?? 'aireminder_export_$timestamp.csv';
      
      if (kIsWeb) {
        // Web: Store for widget to handle download
        lastExportedCsv = csvString;
        lastExportFileName = filename;
        return 'Export ready: $filename';
      } else {
        // Native: Save to documents directory
        final io.Directory dir = await path_provider.getApplicationDocumentsDirectory();
        final io.File file = io.File('${dir.path}/$filename');
        await file.writeAsString(csvString);
        return file.path;
      }
    } catch (e) {
      throw Exception('Failed to export to CSV: $e');
    }
  }

  /// Generate a blank CSV template for creating new reminders
  /// 
  /// Returns a CSV string with headers and a few example rows
  String generateCsvTemplate() {
    final buffer = StringBuffer();
    
    // CSV Header with time information
    buffer.writeln('Title,Notes,Created Date Time,Due Date Time,Status,Completed Date Time,Recurrence,Reminder Time (min)');
    
    // Instructions as comments
    buffer.writeln('# Instructions:');
    buffer.writeln('# - Title: Task name (required)');
    buffer.writeln('# - Notes: Additional details');
    buffer.writeln('# - Created Date Time: Start date and time (YYYY-MM-DD HH:mm or just YYYY-MM-DD)');
    buffer.writeln('# - Due Date Time: When task is due (YYYY-MM-DD HH:mm or just YYYY-MM-DD)');
    buffer.writeln('# - Status: "Pending" or "Completed"');
    buffer.writeln('# - Completed Date Time: When completed (YYYY-MM-DD HH:mm or just YYYY-MM-DD)');
    buffer.writeln('# - Recurrence: "daily", "weekly", "monthly", "yearly" or leave blank');
    buffer.writeln('# - Reminder Time (min): Minutes before due date to remind (e.g., 15=15 min before)');
    buffer.writeln('');
    
    // Example rows with time information
    buffer.writeln('Buy groceries,Milk and eggs needed,2026-02-22 09:00,2026-02-23 18:00,Pending,,weekly,15');
    buffer.writeln('Team meeting,Quarterly review,2026-02-22 10:00,2026-02-24 14:30,Pending,,monthly,30');
    buffer.writeln('Fix bug #123,Login page issue,2026-02-22 08:30,2026-02-25 17:00,Pending,,daily,10');
    buffer.writeln('Call doctor,Annual checkup,2026-02-15 09:00,2026-02-28 15:00,Completed,2026-02-20 15:30,,');
    buffer.writeln('Pay rent,Monthly rent payment,2026-02-22,2026-03-01 23:59,Pending,,monthly,1440');
    
    return buffer.toString();
  }

  /// Export template to a file in the app's documents directory
  /// 
  /// On native platforms: saves to documents directory and returns file path
  /// On web: updates _lastExportedCsv for UI handling
  Future<String> exportTemplateToFile() async {
    try {
      final csvString = generateCsvTemplate();
      final String timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final String filename = 'aireminder_template_$timestamp.csv';
      
      if (kIsWeb) {
        // Web: Store for widget to handle download
        lastExportedCsv = csvString;
        lastExportFileName = filename;
        return 'Template ready: $filename';
      } else {
        // Native: Save to documents directory
        final io.Directory dir = await path_provider.getApplicationDocumentsDirectory();
        final io.File file = io.File('${dir.path}/$filename');
        await file.writeAsString(csvString);
        return file.path;
      }
    } catch (e) {
      throw Exception('Failed to export template: $e');
    }
  }

  // Storage for web export
  static String? lastExportedCsv;
}
