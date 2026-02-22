import 'dart:io' as io;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:js/js.dart' as js;
import 'package:js/js_util.dart' as js_util;
import '../services/import_export_service.dart';
import '../data/hive_task_repository.dart';
import '../models/task.dart';
import 'package:file_picker/file_picker.dart';

/// Widget for managing task import/export operations
class ImportExportWidget extends StatefulWidget {
  final HiveTaskRepository repository;
  final VoidCallback onTasksImported;

  const ImportExportWidget({
    Key? key,
    required this.repository,
    required this.onTasksImported,
  }) : super(key: key);

  @override
  State<ImportExportWidget> createState() => _ImportExportWidgetState();
}

class _ImportExportWidgetState extends State<ImportExportWidget> {
  final _service = ImportExportService.instance;
  bool _isLoading = false;
  String? _statusMessage;
  bool _isError = false;

  void _showMessage(String message, {bool isError = false}) {
    setState(() {
      _statusMessage = message;
      _isError = isError;
    });
    
    // Auto-hide message after 3 seconds if not an error
    if (!isError) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _statusMessage = null);
        }
      });
    }
  }

  Future<void> _exportTasks() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await widget.repository.list();
      final filePath = await _service.exportToFile(tasks);
      
      if (kIsWeb) {
        // On web, show download dialog
        _showWebExportDialog(
          ImportExportService.lastExportedJson ?? '[]',
          ImportExportService.lastExportFileName ?? 'backup.json',
        );
      } else {
        _showMessage('Tasks exported successfully! File saved to:\n$filePath');
        if (mounted) {
          _showExportMenu(filePath, tasks);
        }
      }
    } catch (e) {
      _showMessage('Export failed: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showWebExportDialog(String jsonContent, String filename) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Your Backup'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your tasks backup is ready!'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  filename,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '📋 Preview (first 500 chars):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: SelectableText(
                    jsonContent.length > 500
                        ? '${jsonContent.substring(0, 500)}...'
                        : jsonContent,
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _triggerWebDownload(jsonContent, filename);
            },
            icon: const Icon(Icons.download),
            label: const Text('Download File'),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerWebDownload(String content, String filename) async {
    try {
      if (kIsWeb) {
        // On web, use JavaScript to download
        await _downloadFileOnWeb(content, filename);
      } else {
        // On native platforms, use FilePicker to choose save location
        await _downloadFileOnNative(content, filename);
      }
      _showMessage('✅ File saved successfully!');
    } catch (e) {
      print('Download error: $e');
      _showMessage('Save failed: $e', isError: true);
    }
  }

  Future<void> _downloadFileOnWeb(String content, String filename) async {
    try {
      final bytes = utf8.encode(content);
      final base64Data = base64Encode(bytes);
      
      // Use JavaScript to create and download the file on web
      _triggerBrowserDownload(filename, base64Data);
      
      // Add a small delay to ensure download starts
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print('Web download failed: $e');
      rethrow;
    }
  }

  Future<void> _downloadFileOnNative(String content, String filename) async {
    try {
      // Native: Let user choose save location with FilePicker
      final result = await FilePicker.platform.saveFile(
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['json'],
        lockParentWindow: true,
      );

      if (result == null) {
        throw 'Save cancelled by user';
      }

      // Write the file
      final file = io.File(result);
      await file.writeAsString(content);
    } catch (e) {
      print('Native download failed: $e');
      rethrow;
    }
  }

  void _triggerBrowserDownload(String filename, String base64Data) {
    if (!kIsWeb) {
      print('_triggerBrowserDownload should only be called on web');
      return;
    }
    
    try {
      // Create a simple data URL download using a script tag approach
      final dataUrl = 'data:application/json;base64,$base64Data';
      
      // Use a simple JavaScript string that we'll execute
      _executeDownloadJs(filename, dataUrl);
      
      print('✅ Download triggered for: $filename');
    } catch (e) {
      print('Browser download error: $e');
      throw 'Failed to download file on web: $e';
    }
  }

  void _executeDownloadJs(String filename, String dataUrl) {
    try {
      // Use the js package to execute the download code
      _downloadViaJs(filename, dataUrl);
    } catch (e) {
      print('JS execution failed: $e');
      rethrow;
    }
  }

  void _downloadViaJs(String filename, String dataUrl) {
    if (!kIsWeb) return;
    
    try {
      // Call a JavaScript function directly using js_util
      // ignore: avoid_dynamic_calls
      js_util.callMethod(js_util.globalThis, 'eval', [
        '''
        (function() {
          var link = document.createElement('a');
          link.href = '$dataUrl';
          link.download = '$filename';
          link.style.display = 'none';
          document.body.appendChild(link);
          link.click();
          document.body.removeChild(link);
        })();
        '''
      ]);
      print('✅ Download initiated');
    } catch (e) {
      print('Download via JS failed: $e');
      rethrow;
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await widget.repository.list();
      final csvContent = _service.exportToCsvString(tasks);
      
      if (kIsWeb) {
        // On web, show download dialog (same as JSON)
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
        final filename = 'aireminder_backup_$timestamp.csv';
        
        if (mounted) {
          _showCsvExportDialog(csvContent, filename);
        }
      } else {
        // On native, use file picker
        final filePath = await _service.exportToCsvFile(tasks);
        _showMessage('Tasks exported to CSV: $filePath');
      }
    } catch (e) {
      _showMessage('CSV export failed: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showCsvExportDialog(String csvContent, String filename) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download CSV Backup'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your tasks CSV export is ready!'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  filename,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '📋 Preview (first 500 chars):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: SelectableText(
                    csvContent.length > 500
                        ? '${csvContent.substring(0, 500)}...'
                        : csvContent,
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _triggerCsvDownload(csvContent, filename);
            },
            icon: const Icon(Icons.download),
            label: const Text('Download File'),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerCsvDownload(String content, String filename) async {
    try {
      if (kIsWeb) {
        // On web, use JavaScript to download
        await _downloadCsvOnWeb(content, filename);
      } else {
        // On native platforms, use FilePicker to choose save location
        await _downloadCsvOnNative(content, filename);
      }
      _showMessage('✅ CSV file saved successfully!');
    } catch (e) {
      print('CSV download error: $e');
      _showMessage('Save failed: $e', isError: true);
    }
  }

  Future<void> _downloadCsvOnWeb(String content, String filename) async {
    try {
      final bytes = utf8.encode(content);
      final base64Data = base64Encode(bytes);
      
      // Use JavaScript to create and download the CSV file on web
      _triggerCsvBrowserDownload(filename, base64Data);
      
      // Add a small delay to ensure download starts
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print('Web CSV download failed: $e');
      rethrow;
    }
  }

  Future<void> _downloadCsvOnNative(String content, String filename) async {
    try {
      // Native: Let user choose save location with FilePicker
      final result = await FilePicker.platform.saveFile(
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: ['csv'],
        lockParentWindow: true,
      );

      if (result == null) {
        throw 'Save cancelled by user';
      }

      // Write the file
      final file = io.File(result);
      await file.writeAsString(content);
    } catch (e) {
      print('Native CSV download failed: $e');
      rethrow;
    }
  }

  void _triggerCsvBrowserDownload(String filename, String base64Data) {
    if (!kIsWeb) {
      print('_triggerCsvBrowserDownload should only be called on web');
      return;
    }
    
    try {
      // Create JavaScript code for CSV download
      final jsCode = '''
      (function() {
        var link = document.createElement('a');
        link.href = 'data:text/csv;base64,$base64Data';
        link.download = '$filename';
        link.style.display = 'none';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
      })();
      ''';
      
      // Execute the download
      _downloadViaCsvJs(jsCode);
      
      print('✅ CSV download triggered for: $filename');
    } catch (e) {
      print('CSV browser download error: $e');
      throw 'Failed to download CSV file on web: $e';
    }
  }

  void _downloadViaCsvJs(String jsCode) {
    if (!kIsWeb) return;
    
    try {
      // Call a JavaScript function directly using js_util
      // ignore: avoid_dynamic_calls
      js_util.callMethod(js_util.globalThis, 'eval', [jsCode]);
      print('✅ CSV Download initiated');
    } catch (e) {
      print('CSV Download via JS failed: $e');
      rethrow;
    }
  }

  Future<void> _importTasks() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select backup file to import',
      );

      if (result == null) return; // User cancelled

      setState(() => _isLoading = true);

      final file = io.File(result.files.single.path!);
      final importResult = await _service.importFromFile(file);

      if (importResult.tasks.isEmpty) {
        _showMessage(
          'No valid tasks found in file.\nErrors: ${importResult.errors.join(', ')}',
          isError: true,
        );
        return;
      }

      // Show import preview and ask for confirmation
      if (mounted) {
        _showImportPreview(importResult.tasks, importResult.errors);
      }
    } catch (e) {
      _showMessage('Failed to select file: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showImportPreview(List<Task> tasks, List<String> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Preview'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Found ${tasks.length} valid tasks',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '⚠️ ${errors.length} errors:',
                  style: const TextStyle(color: Colors.orange),
                ),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    itemCount: errors.length,
                    itemBuilder: (_, i) => Text(
                      '• ${errors[i]}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
              if (tasks.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Sample tasks:'),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    itemCount: (tasks.length > 3 ? 3 : tasks.length),
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tasks[i].title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Due: ${tasks[i].dueAt?.toString().split(' ')[0] ?? 'No due date'}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (tasks.length > 3)
                  Text(
                    '... and ${tasks.length - 3} more',
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmImport(tasks);
            },
            child: const Text('Import All'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmImport(List<Task> tasks) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to handle duplicates?'),
        content: const Text(
          'If same task ID exists in your reminders, what should we do?',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performImport(tasks, 'skip');
            },
            child: const Text('Keep Existing'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performImport(tasks, 'replace');
            },
            child: const Text('Replace'),
          ),
        ],
      ),
    );
  }

  Future<void> _performImport(List<Task> tasks, String duplicateHandling) async {
    setState(() => _isLoading = true);
    try {
      final result = await _service.mergeTasksIntoRepository(
        widget.repository,
        tasks,
        duplicateHandling: duplicateHandling,
      );

      _showMessage(
        'Imported ${result.imported} tasks! (${result.skipped} skipped)\n'
        '${result.errors.isNotEmpty ? '${result.errors.length} errors occurred.' : ''}',
      );

      // Notify parent that tasks were imported
      widget.onTasksImported();
    } catch (e) {
      _showMessage('Import failed: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showExportMenu(String filePath, List<Task> tasks) {
    if (kIsWeb) return; // Skip web platform
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('View exported file'),
              onTap: () {
                Navigator.pop(context);
                _showMessage('File saved at: $filePath');
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Close'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 24, bottom: 8),
          child: Text(
            'Backup & Restore',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        
        // Status Message
        if (_statusMessage != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isError
                  ? Colors.red.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
              border: Border.all(
                color: _isError ? Colors.red : Colors.green,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusMessage!,
              style: TextStyle(
                color: _isError ? Colors.red[700] : Colors.green[700],
                fontSize: 12,
              ),
            ),
          ),

        // Export Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _exportTasks,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.backup),
                      SizedBox(width: 8),
                      Text('Export Tasks (JSON)'),
                    ],
                  ),
          ),
        ),

        // Export CSV Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: OutlinedButton(
            onPressed: _isLoading ? null : _exportCsv,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.table_chart),
                SizedBox(width: 8),
                Text('Export as CSV'),
              ],
            ),
          ),
        ),

        // Import Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _importTasks,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: Colors.orangeAccent,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restore),
                SizedBox(width: 8),
                Text('Import Tasks (JSON)'),
              ],
            ),
          ),
        ),

        // Info text
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '💾 JSON backups include all task details (recurrence, sharing, etc.)\n'
              '📊 CSV exports are great for spreadsheet viewing\n'
              '📱 Use Import to restore from a backup file',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }
}
