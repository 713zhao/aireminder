import 'package:flutter/material.dart';
import '../services/firestore_sync.dart';
import '../services/settings_service.dart';
import '../models/task.dart';

class FamilySharingScreen extends StatefulWidget {
  const FamilySharingScreen({Key? key}) : super(key: key);

  @override
  State<FamilySharingScreen> createState() => _FamilySharingScreenState();
}

class _FamilySharingScreenState extends State<FamilySharingScreen> {
  final FirestoreSyncService _syncService = FirestoreSyncService.instance;
  final TextEditingController _emailController = TextEditingController();
  List<Task> _ownTasks = [];
  List<Task> _sharedTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      // Force refresh from server to get the latest data
      await _syncService.overwriteLocalWithRemote();
      
      final ownTasks = await _syncService.fetchRemoteTasks();
      final sharedTasks = await _syncService.fetchSharedTasks();
      
      setState(() {
        _ownTasks = ownTasks;
        _sharedTasks = sharedTasks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tasks: $e')),
        );
      }
    }
  }

  Future<void> _shareTask(Task task) async {
    final emails = await _showShareDialog();
    if (emails != null && emails.isNotEmpty) {
      try {
        await _syncService.shareTaskWithEmails(task.id, emails);
        await _loadTasks(); // Refresh
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Task shared with ${emails.length} family members')),
          );
        }
      } catch (e) {
        if (mounted) {
          final errorMsg = e.toString().replaceFirst('Exception: ', '');
          if (errorMsg.contains('permission-denied') || errorMsg.contains('Permission denied')) {
            _showPermissionErrorDialog();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error sharing task: $errorMsg'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _unshareTask(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Sharing'),
        content: Text('Stop sharing "${task.title}" with family members?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Stop Sharing'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _syncService.unshareTask(task.id);
        await _loadTasks(); // Refresh
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task is no longer shared')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error unsharing task: $e')),
          );
        }
      }
    }
  }

  Future<void> _shareAllTasks() async {
    if (_ownTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tasks to share')),
      );
      return;
    }

    final emails = await _showShareDialog();
    if (emails != null && emails.isNotEmpty) {
      try {
        int sharedCount = 0;
        int skippedCount = 0;
        
        for (final task in _ownTasks) {
          if (!task.isShared) {
            await _syncService.shareTaskWithEmails(task.id, emails);
            sharedCount++;
          } else {
            skippedCount++;
          }
        }
        
        await _loadTasks(); // Refresh
        
        String message = 'Shared $sharedCount tasks with family members';
        if (skippedCount > 0) {
          message += ' ($skippedCount already shared)';
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      } catch (e) {
        if (mounted) {
          final errorMsg = e.toString().replaceFirst('Exception: ', '');
          if (errorMsg.contains('permission-denied') || errorMsg.contains('Permission denied')) {
            _showPermissionErrorDialog();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error sharing tasks: $errorMsg'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _unshareAllTasks() async {
    final sharedTasks = _ownTasks.where((task) => task.isShared).toList();
    if (sharedTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No shared tasks to unshare')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Sharing All Tasks'),
        content: Text('Stop sharing all ${sharedTasks.length} shared tasks with family members?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Stop All Sharing'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        int unsharedCount = 0;
        for (final task in sharedTasks) {
          await _syncService.unshareTask(task.id);
          unsharedCount++;
        }
        await _loadTasks(); // Refresh
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Stopped sharing $unsharedCount tasks')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error unsharing tasks: $e')),
          );
        }
      }
    }
  }

  Future<void> _testPermissions() async {
    try {
      final hasPermissions = await _syncService.testFirestorePermissions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(hasPermissions 
              ? '✅ Permissions test passed! Sharing should work.'
              : '❌ Permissions test failed. Check Firestore rules.'),
            backgroundColor: hasPermissions ? Colors.green : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permission test error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _manualSyncFamily() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Syncing family tasks...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      await _syncService.syncFamilyTasks();
      await _loadTasks(); // Refresh the UI
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Family tasks synced successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPermissionErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Error'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Family sharing requires proper Firestore security rules to be configured.'),
            SizedBox(height: 16),
            Text('To fix this:'),
            Text('1. Go to Firebase Console > Firestore Database > Rules'),
            Text('2. Update rules with the content from firestore.rules file'),
            Text('3. Publish the updated rules'),
            SizedBox(height: 16),
            Text('Contact your app administrator if you need help with this setup.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<List<String>?> _showShareDialog() async {
    final emails = <String>[];
    String currentEmail = '';

    return showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Share with Family'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter email addresses of family members:'),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    hintText: 'family@example.com',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) => currentEmail = value,
                  onSubmitted: (value) {
                    if (value.isNotEmpty && value.contains('@')) {
                      setDialogState(() {
                        emails.add(value);
                        _emailController.clear();
                        currentEmail = '';
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    if (currentEmail.isNotEmpty && currentEmail.contains('@')) {
                      setDialogState(() {
                        emails.add(currentEmail);
                        _emailController.clear();
                        currentEmail = '';
                      });
                    }
                  },
                  child: const Text('Add Email'),
                ),
                const SizedBox(height: 16),
                if (emails.isNotEmpty) ...[
                  const Text('Family members to share with:'),
                  const SizedBox(height: 8),
                  ...emails.map((email) => Chip(
                    label: Text(email),
                    deleteIcon: const Icon(Icons.close),
                    onDeleted: () {
                      setDialogState(() => emails.remove(email));
                    },
                  )).toList(),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: emails.isEmpty 
                ? null 
                : () => Navigator.pop(context, List<String>.from(emails)),
              child: const Text('Share'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskTile(Task task, {required bool isOwned}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        title: Text(task.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.notes?.isNotEmpty == true) Text(task.notes!),
            const SizedBox(height: 4),
            Row(
              children: [
                if (task.isShared) ...[
                  const Icon(Icons.people, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    isOwned 
                      ? 'Shared with ${task.sharedWith?.length ?? 0} members'
                      : 'Shared by ${task.ownerId ?? 'Unknown'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const Spacer(),
                if (task.lastModifiedBy != null) ...[
                  const Icon(Icons.edit, size: 12, color: Colors.grey),
                  const SizedBox(width: 2),
                  Text(
                    task.lastModifiedBy!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: isOwned
          ? PopupMenuButton(
              itemBuilder: (context) => [
                if (task.isShared)
                  PopupMenuItem(
                    child: const ListTile(
                      leading: Icon(Icons.person_remove),
                      title: Text('Stop Sharing'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onTap: () => _unshareTask(task),
                  )
                else
                  PopupMenuItem(
                    child: const ListTile(
                      leading: Icon(Icons.people_alt),
                      title: Text('Share with Family'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onTap: () => _shareTask(task),
                  ),
              ],
            )
          : const Icon(Icons.people, color: Colors.blue),
        leading: Icon(
          task.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
          color: task.isCompleted ? Colors.green : Colors.grey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Sharing'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.people_alt),
                  title: Text('Share All Tasks'),
                  contentPadding: EdgeInsets.zero,
                ),
                onTap: () => Future.delayed(Duration.zero, _shareAllTasks),
              ),
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.person_remove),
                  title: Text('Unshare All Tasks'),
                  contentPadding: EdgeInsets.zero,
                ),
                onTap: () => Future.delayed(Duration.zero, _unshareAllTasks),
              ),
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.security),
                  title: Text('Test Permissions'),
                  contentPadding: EdgeInsets.zero,
                ),
                onTap: () => Future.delayed(Duration.zero, _testPermissions),
              ),
              // Manual sync option (when auto-sync is disabled)
              if (!SettingsService.autoSyncFamily)
                PopupMenuItem(
                  child: const ListTile(
                    leading: Icon(Icons.sync),
                    title: Text('Manual Sync Family Tasks'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onTap: () => Future.delayed(Duration.zero, _manualSyncFamily),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadTasks,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info card with stats
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info, color: Colors.blue),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Share your reminder events with family members. They can view and update shared reminders in real-time.',
                                    style: TextStyle(color: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Stats row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatCard('My Tasks', _ownTasks.length.toString(), Icons.task),
                                _buildStatCard('Shared', _ownTasks.where((t) => t.isShared).length.toString(), Icons.people),
                                _buildStatCard('Received', _sharedTasks.length.toString(), Icons.inbox),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Sync status
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: SettingsService.autoSyncFamily ? Colors.green[100] : Colors.orange[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    SettingsService.autoSyncFamily ? Icons.sync : Icons.sync_disabled,
                                    size: 16,
                                    color: SettingsService.autoSyncFamily ? Colors.green[700] : Colors.orange[700],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    SettingsService.autoSyncFamily 
                                      ? 'Auto-sync enabled' 
                                      : 'Auto-sync disabled',
                                    style: TextStyle(
                                      color: SettingsService.autoSyncFamily ? Colors.green[700] : Colors.orange[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // My Tasks section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'My Tasks',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_ownTasks.isNotEmpty) ...[
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: _shareAllTasks,
                                icon: const Icon(Icons.people_alt, size: 16),
                                label: const Text('Share All'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_ownTasks.any((task) => task.isShared))
                                OutlinedButton.icon(
                                  onPressed: _unshareAllTasks,
                                  icon: const Icon(Icons.person_remove, size: 16),
                                  label: const Text('Unshare All'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_ownTasks.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No tasks yet. Create some reminders to share with family!'),
                        ),
                      )
                    else
                      Column(
                        children: _ownTasks
                            .map((task) => _buildTaskTile(task, isOwned: true))
                            .toList(),
                      ),

                    const SizedBox(height: 24),

                    // Shared with Me section
                    Text(
                      'Shared with Me',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_sharedTasks.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No tasks shared with you yet.'),
                        ),
                      )
                    else
                      Column(
                        children: _sharedTasks
                            .map((task) => _buildTaskTile(task, isOwned: false))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
          ),
      floatingActionButton: _ownTasks.isNotEmpty && _ownTasks.any((task) => !task.isShared)
        ? FloatingActionButton.extended(
            onPressed: _shareAllTasks,
            icon: const Icon(Icons.people_alt),
            label: const Text('Share All'),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          )
        : null,
    );
  }
}