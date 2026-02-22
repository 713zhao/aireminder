# Import/Export Feature - Integration Guide

## Overview
I've created a complete import/export system for your AI Reminder app with the following components:

### Files Created
1. **`lib/services/import_export_service.dart`** - Core service with all export/import logic
2. **`lib/widgets/import_export_widget.dart`** - Ready-to-use UI widget for settings
3. **Updated `pubspec.yaml`** - Added required dependencies

### Features
✅ **Export** - Download tasks as JSON or CSV  
✅ **Import** - Upload backup files with validation  
✅ **Merge Control** - Choose how to handle duplicate task IDs  
✅ **Error Handling** - Detailed error reporting during import  
✅ **File Management** - Works with system file picker  
✅ **CSV Export** - Bonus format for spreadsheet viewing  

---

## How to Integrate

### Step 1: Update Dependencies
Run this command in your project root:
```bash
flutter pub get
```

This installs the new packages:
- `file_picker: ^8.0.0` - System file picker
- `share_plus: ^10.0.0` - Share/export functionality

### Step 2: Add Widget to Settings Screen
Edit `lib/screens/settings.dart` and add these imports at the top:

```dart
import '../widgets/import_export_widget.dart';
```

Then add this code in the `_SettingsScreenState` class (in the build method, after the "Clear All Data" button, around line 628):

```dart
const SizedBox(height: 8),
Text(
  'Backup and restore your tasks locally.',
  style: TextStyle(
    color: Colors.grey[600],
    fontSize: 12,
  ),
),
const SizedBox(height: 20),
// ===================== IMPORT/EXPORT SECTION =====================
ImportExportWidget(
  repository: HiveTaskRepository(),
  onTasksImported: () {
    // Optional: Trigger UI refresh if needed
    // For example, refresh the task list in home screen
    setState(() {});
  },
),
```

### Step 3: That's it!
You now have a complete import/export system in your Settings screen.

---

## Using the Feature

### For Users: Exporting Tasks
1. Go to Settings
2. Scroll to "Backup & Restore"
3. Click "Export Tasks (JSON)" or "Export as CSV"
4. File is saved to app documents directory
5. Optional: Share the file or open file location

### For Users: Importing Tasks
1. Go to Settings  
2. Click "Import Tasks (JSON)"
3. Select a backup JSON file
4. Review the import preview (shows count and any errors)
5. Choose how to handle duplicates:
   - **Keep Existing** - Skip tasks that already exist
   - **Replace** - Overwrite existing tasks
6. Done! Tasks are imported into your reminder list

---

## API Reference

### ImportExportService Methods

#### Export Methods
```dart
// Export to JSON string
String exportToJsonString(List<Task> tasks)

// Export to JSON file
Future<String> exportToFile(List<Task> tasks, {String? fileName})

// Export to CSV for spreadsheets
String exportToCsvString(List<Task> tasks)
Future<String> exportToCsvFile(List<Task> tasks, {String? fileName})

// Create timestamped backup
Future<String> createBackup(List<Task> tasks, {String? customLabel})
```

#### Import Methods
```dart
// Import from JSON string with validation
Future<({List<Task> tasks, List<String> errors})> importFromJsonString(
  String jsonString,
  {bool skipInvalidTasks = true}
)

// Import from file
Future<({List<Task> tasks, List<String> errors})> importFromFile(
  File file,
  {bool skipInvalidTasks = true}
)
```

#### Merge Methods
```dart
// Merge imported tasks into repository
Future<({int imported, int skipped, List<String> errors})> mergeTasksIntoRepository(
  HiveTaskRepository repository,
  List<Task> importedTasks,
  {String duplicateHandling = 'skip'} // 'skip' or 'replace'
)
```

#### Utility
```dart
// List all backup files in documents directory
Future<List<File>> listBackups()
```

---

## Advanced Usage Examples

### Example 1: Programmatic Export (e.g., in home screen)
```dart
final service = ImportExportService.instance;
final repo = HiveTaskRepository();
final tasks = await repo.list();

// Export and get file path
final filePath = await service.exportToFile(tasks);
print('Exported to: $filePath');

// Or share directly
final jsonString = service.exportToJsonString(tasks);
```

### Example 2: Auto-Backup on App Close
Add to your main app widget:
```dart
@override
void dispose() {
  // Create backup before exit
  _createAutomaticBackup();
  super.dispose();
}

Future<void> _createAutomaticBackup() async {
  final repo = HiveTaskRepository();
  final tasks = await repo.list();
  final label = DateTime.now().toIso8601String().split('T')[0];
  await ImportExportService.instance.createBackup(tasks, customLabel: label);
}
```

### Example 3: Restore from Backup in Code
```dart
final service = ImportExportService.instance;
final repo = HiveTaskRepository();

// Read from file
final file = File('/path/to/backup.json');
final result = await service.importFromFile(file);

// Merge into repository
final mergeResult = await service.mergeTasksIntoRepository(
  repo,
  result.tasks,
  duplicateHandling: 'replace',
);

print('Imported: ${mergeResult.imported}');
print('Skipped: ${mergeResult.skipped}');
if (mergeResult.errors.isNotEmpty) {
  print('Errors: ${mergeResult.errors}');
}
```

---

## File Format Structure

### JSON Backup Format
```json
{
  "metadata": {
    "exportedAt": "2026-02-22T10:30:45",
    "version": "1.0",
    "taskCount": 5,
    "appVersion": "1.3.0"
  },
  "tasks": [
    {
      "id": "1234567890",
      "title": "Buy groceries",
      "notes": "Milk, eggs, bread",
      "createdAt": "2026-02-20T10:00:00.000Z",
      "dueAt": "2026-02-22T18:00:00.000Z",
      "recurrence": "weekly",
      "isCompleted": false,
      "completedAt": null,
      "reminderId": 1,
      "isDisabled": false,
      "disabledUntil": null,
      "remindBeforeMinutes": 10,
      "recurrenceEndDate": "2026-12-31T23:59:59.000Z",
      "weeklyDays": [1, 3, 5],
      "ownerId": "user@example.com",
      "sharedWith": ["friend@example.com"],
      "isShared": true,
      "lastModifiedBy": "user@example.com",
      "serverId": null,
      "updatedAt": "2026-02-21T14:30:00.000Z",
      "deleted": false,
      "version": 1
    }
  ]
}
```

### CSV Format
```csv
Title,Notes,Created Date,Due Date,Status,Completed Date,Recurrence,Reminder Time (min)
Buy groceries,Milk eggs bread,2026-02-20,2026-02-22,Pending,,weekly,10
Call mom,,2026-02-21,2026-02-28,Completed,2026-02-21,,10
```

---

## Error Handling

The import process gracefully handles:
- Missing or invalid JSON
- Missing required fields (id, title, createdAt)
- Invalid date formats
- Duplicate task IDs
- Malformed data entries

During import, users see:
- Count of valid tasks found
- List of validation errors
- Option to proceed or cancel

---

## Troubleshooting

### "File not found" error
- Ensure the backup file exists
- Check file permissions
- Try selecting the file through the file picker UI

### Import shows "0 tasks found"
- Verify JSON format is correct
- Check that file contains at least one task
- Ensure required fields (id, title, createdAt) are present

### Share not working
- Install `share_plus` package dependencies
- Make sure target device/platform supports sharing

---

## Next Steps (Optional Enhancements)

1. **Auto-backup scheduling** - Scheduled background backups to cloud
2. **Cloud sync** - Auto-sync with Google Drive or Dropbox
3. **Restore from cloud** - UI for listing cloud backups
4. **Version history** - Keep multiple versions with restore points
5. **Encryption** - Encrypt sensitive data in backups
6. **Selective export** - Export only specific tasks/date ranges
7. **Merge comparison** - Preview conflicts before importing

---

## Support

For questions about the import/export feature:
- Check error messages in the UI
- Review the service implementation in `import_export_service.dart`
- Test with the example JSON format provided above
