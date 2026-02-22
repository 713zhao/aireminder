/// Example usage of the ImportExportService
/// 
/// This file demonstrates common patterns for using the import/export feature
/// in the AI Reminder app.

import 'dart:io';
import '../services/import_export_service.dart';
import '../data/hive_task_repository.dart';
import '../models/task.dart';

/// Example 1: Simple export to file
Future<void> exampleSimpleExport() async {
  final service = ImportExportService.instance;
  final repo = HiveTaskRepository();
  
  // Get all tasks
  final tasks = await repo.list();
  
  // Export to file
  final filePath = await service.exportToFile(tasks);
  print('✓ Tasks exported to: $filePath');
}

/// Example 2: Export with custom filename
Future<void> exampleExportWithCustomName() async {
  final service = ImportExportService.instance;
  final repo = HiveTaskRepository();
  
  final tasks = await repo.list();
  final filePath = await service.exportToFile(
    tasks,
    fileName: 'my_reminders_backup.json',
  );
  print('✓ Exported to: $filePath');
}

/// Example 3: Create dated backup
Future<void> exampleCreateDatedBackup() async {
  final service = ImportExportService.instance;
  final repo = HiveTaskRepository();
  
  final tasks = await repo.list();
  final label = 'daily-backup'; // Will create: aireminder_backup_daily-backup.json
  final filePath = await service.createBackup(tasks, customLabel: label);
  print('✓ Backup created: $filePath');
}

/// Example 4: Export to CSV for spreadsheet
Future<void> exampleExportCsv() async {
  final service = ImportExportService.instance;
  final repo = HiveTaskRepository();
  
  final tasks = await repo.list();
  final filePath = await service.exportToCsvFile(tasks);
  print('✓ CSV exported to: $filePath');
}

/// Example 5: Import from JSON string
Future<void> exampleImportFromString() async {
  final service = ImportExportService.instance;
  
  // This would typically come from a file picker UI
  const jsonString = '''
  {
    "metadata": {
      "exportedAt": "2026-02-22T10:00:00",
      "version": "1.0",
      "taskCount": 2,
      "appVersion": "1.3.0"
    },
    "tasks": [
      {
        "id": "1",
        "title": "Buy milk",
        "notes": "2% milk",
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
      }
    ]
  }
  ''';
  
  final result = await service.importFromJsonString(jsonString);
  print('✓ Found ${result.tasks.length} tasks');
  if (result.errors.isNotEmpty) {
    print('⚠ Errors: ${result.errors}');
  }
}

/// Example 6: Import from file and merge
Future<void> exampleImportAndMerge() async {
  final service = ImportExportService.instance;
  final repo = HiveTaskRepository();
  
  // In real app, this comes from file picker
  final backupFile = File('/path/to/backup.json');
  
  try {
    // Step 1: Read and validate
    final result = await service.importFromFile(backupFile);
    print('✓ Read ${result.tasks.length} tasks from backup');
    
    if (result.errors.isNotEmpty) {
      print('⚠ Import errors: ${result.errors.length}');
      result.errors.forEach(print);
    }
    
    // Step 2: Merge into repository
    final mergeResult = await service.mergeTasksIntoRepository(
      repo,
      result.tasks,
      duplicateHandling: 'skip', // or 'replace'
      updateTimestamps: true,
    );
    
    print('✓ Import complete:');
    print('  - Imported: ${mergeResult.imported}');
    print('  - Skipped: ${mergeResult.skipped}');
    if (mergeResult.errors.isNotEmpty) {
      print('  - Errors: ${mergeResult.errors.length}');
    }
  } catch (e) {
    print('✗ Import failed: $e');
  }
}

/// Example 7: List available backups
Future<void> exampleListBackups() async {
  final service = ImportExportService.instance;
  
  final backups = await service.listBackups();
  print('✓ Found ${backups.length} backup files:');
  
  for (final backup in backups) {
    final stat = backup.statSync();
    print('  - ${backup.path}');
    print('    Modified: ${stat.modified}');
    print('    Size: ${stat.size} bytes');
  }
}

/// Example 8: Complete workflow - Backup before sync
Future<void> exampleCompleteBackupWorkflow() async {
  final service = ImportExportService.instance;
  final repo = HiveTaskRepository();
  
  try {
    print('Starting backup workflow...');
    
    // Get all current tasks
    final tasks = await repo.list();
    print('Found ${tasks.length} tasks');
    
    // Create timestamped backup
    final timestamp = DateTime.now().toIso8601String().split('T')[0];
    final backupPath = await service.createBackup(
      tasks,
      customLabel: 'pre-sync-$timestamp',
    );
    print('✓ Backup created: $backupPath');
    
    // Also create CSV for human review
    final csvPath = await service.exportToCsvFile(tasks);
    print('✓ CSV export: $csvPath');
    
    // List all backups
    final allBackups = await service.listBackups();
    print('✓ Total backups available: ${allBackups.length}');
    
  } catch (e) {
    print('✗ Backup failed: $e');
  }
}

/// Example 9: Import with error handling
Future<void> exampleImportWithErrorHandling() async {
  final service = ImportExportService.instance;
  final repo = HiveTaskRepository();
  
  try {
    // Simulate reading from file
    const problemJson = '''
    {
      "metadata": {"version": "1.0", "taskCount": 3},
      "tasks": [
        {
          "id": "1",
          "title": "Valid task",
          "createdAt": "2026-02-20T10:00:00.000Z"
        },
        {
          "id": "2",
          "title": "Missing createdAt"
        },
        {
          "id": "3"
        }
      ]
    }
    ''';
    
    final result = await service.importFromJsonString(problemJson);
    
    print('Import results:');
    print('  Valid tasks: ${result.tasks.length}');
    print('  Issues found: ${result.errors.length}');
    
    if (result.errors.isNotEmpty) {
      print('\nDetails:');
      result.errors.forEach((err) => print('  - $err'));
    }
    
    // Even with errors, can still import valid ones
    if (result.tasks.isNotEmpty) {
      final merged = await service.mergeTasksIntoRepository(
        repo,
        result.tasks,
      );
      print('\nImported: ${merged.imported} valid tasks');
    }
    
  } catch (e) {
    print('Fatal error: $e');
  }
}

/// Example 10: Export selected tasks only
Future<void> exampleExportFiltered() async {
  final service = ImportExportService.instance;
  final repo = HiveTaskRepository();
  
  // Get all tasks
  var allTasks = await repo.list();
  
  // Filter: only pending tasks (not completed)
  final filteredTasks = allTasks.where((t) => !t.isCompleted).toList();
  
  // Export filtered list
  final filePath = await service.exportToFile(filteredTasks);
  print('✓ Exported ${filteredTasks.length} pending tasks to: $filePath');
  
  // Or filter by date range
  final now = DateTime.now();
  final nextWeek = now.add(const Duration(days: 7));
  final upcomingTasks = allTasks.where((t) {
    if (t.dueAt == null) return false;
    return t.dueAt!.isAfter(now) && t.dueAt!.isBefore(nextWeek);
  }).toList();
  
  final upcomingPath = await service.exportToFile(upcomingTasks);
  print('✓ Exported ${upcomingTasks.length} upcoming tasks to: $upcomingPath');
}
