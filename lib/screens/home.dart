import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/voice_button.dart';
import '../services/audio_priming.dart';
import '../services/firestore_sync.dart';
import '../services/settings_service.dart';
import '../services/gemini_service.dart';
import 'tasks_list.dart';
import 'settings.dart';
import 'family_sharing_screen.dart';
import '../widgets/task_form.dart';
import '../widgets/date_strip.dart';
import '../widgets/ad_bar.dart';
import '../widgets/tasks_for_date.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _userEmail;
  StreamSubscription<String?>? _userSub;
  bool _standaloneMode = true;

  void _onDateSelected(DateTime d) {
    setState(() => _selectedDate = d);
  }

  void _updateStandaloneMode() {
    setState(() {
      _standaloneMode = SettingsService.standaloneMode;
    });
  }

  Future<void> _onPictureInput() async {
    await _processImageInput(ImageSource.gallery);
  }

  Future<void> _onCameraInput() async {
    await _processImageInput(ImageSource.camera);
  }

  Future<void> _processImageInput(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      
      // Configure image quality for both camera and gallery to target 512KB
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024, // Smaller resolution for both sources
        maxHeight: 1024,
        imageQuality: 70, // More aggressive compression for both
      );
      
      if (image == null) return;

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('Processing image with AI...')),
            ],
          ),
        ),
      );

      try {
        // Pass XFile directly - works on both web and mobile
        final extractedData = await GeminiService.extractEventFromImage(image);
        
        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
        }

        if (extractedData != null && !extractedData.containsKey('error')) {
          _showExtractedDataDialog(extractedData);
        } else {
          _showErrorDialog(extractedData?['error'] ?? 'Failed to extract event information from image');
        }
      } catch (e) {
        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
        }
        _showErrorDialog(e.toString());
      }
    } catch (e) {
      _showErrorDialog('Failed to pick image: $e');
    }
  }

  void _showExtractedDataDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.smart_toy, color: Colors.blue),
            SizedBox(width: 8),
            Text('AI Extracted Information'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data['confidence'] != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(data['confidence']),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Confidence: ${data['confidence']}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _buildDataRow('Title', data['title']),
              _buildDataRow('Date', data['date']),
              _buildDataRow('Time', data['time']),
              _buildDataRow('Location', data['location']),
              _buildDataRow('Description', data['description']),
              _buildRecurrenceRow(data['recurrence']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _openTaskFormWithData(data);
            },
            child: const Text('Create Event'),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String? value) {
    if (value == null || value.isEmpty || value == 'null') {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurrenceRow(dynamic recurrence) {
    if (recurrence == null) {
      return const SizedBox.shrink();
    }
    
    String recurrenceText = '';
    
    if (recurrence is Map<String, dynamic>) {
      final type = recurrence['type']?.toString() ?? 'none';
      final interval = recurrence['interval']?.toString() ?? '1';
      final days = recurrence['days'] as List<dynamic>?;
      final until = recurrence['until']?.toString();
      
      switch (type.toLowerCase()) {
        case 'daily':
          recurrenceText = interval == '1' ? 'Daily' : 'Every $interval days';
          break;
        case 'weekly':
          if (days != null && days.isNotEmpty) {
            final dayNames = days.map((d) => _capitalize(d.toString())).join(', ');
            recurrenceText = interval == '1' ? 'Weekly on $dayNames' : 'Every $interval weeks on $dayNames';
          } else {
            recurrenceText = interval == '1' ? 'Weekly' : 'Every $interval weeks';
          }
          break;
        case 'monthly':
          recurrenceText = interval == '1' ? 'Monthly' : 'Every $interval months';
          break;
        case 'yearly':
          recurrenceText = interval == '1' ? 'Yearly' : 'Every $interval years';
          break;
        case 'none':
        default:
          return const SizedBox.shrink();
      }
      
      if (until != null && until.isNotEmpty && until != 'null') {
        recurrenceText += ' (until $until)';
      }
    } else {
      recurrenceText = recurrence.toString();
    }
    
    if (recurrenceText.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 80,
            child: Text(
              'Repeats:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.repeat, size: 16, color: Colors.purple),
                  const SizedBox(width: 4),
                  Text(
                    recurrenceText,
                    style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  Color _getConfidenceColor(String confidence) {
    switch (confidence.toLowerCase()) {
      case 'high':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _openTaskFormWithData(Map<String, dynamic> data) async {
    // Parse the extracted data
    final title = data['title']?.toString() ?? '';
    final dateStr = data['date']?.toString();
    final timeStr = data['time']?.toString();
    final location = data['location']?.toString() ?? '';
    final description = data['description']?.toString() ?? '';
    final recurrence = data['recurrence'];
    
    // Combine location, description, and recurrence for notes
    String notes = '';
    final noteParts = <String>[];
    
    if (location.isNotEmpty) {
      noteParts.add('Location: $location');
    }
    
    if (recurrence != null && recurrence is Map<String, dynamic>) {
      final type = recurrence['type']?.toString() ?? 'none';
      if (type != 'none') {
        final interval = recurrence['interval']?.toString() ?? '1';
        final days = recurrence['days'] as List<dynamic>?;
        
        String recurrenceNote = 'Recurring: ';
        switch (type.toLowerCase()) {
          case 'daily':
            recurrenceNote += interval == '1' ? 'Daily' : 'Every $interval days';
            break;
          case 'weekly':
            if (days != null && days.isNotEmpty) {
              final dayNames = days.map((d) => _capitalize(d.toString())).join(', ');
              recurrenceNote += interval == '1' ? 'Weekly on $dayNames' : 'Every $interval weeks on $dayNames';
            } else {
              recurrenceNote += interval == '1' ? 'Weekly' : 'Every $interval weeks';
            }
            break;
          case 'monthly':
            recurrenceNote += interval == '1' ? 'Monthly' : 'Every $interval months';
            break;
          case 'yearly':
            recurrenceNote += interval == '1' ? 'Yearly' : 'Every $interval years';
            break;
        }
        noteParts.add(recurrenceNote);
      }
    }
    
    if (description.isNotEmpty) {
      noteParts.add(description);
    }
    
    notes = noteParts.join('\n\n');
    
    // Parse date and time
    final dueAt = GeminiService.parseDateTime(dateStr, timeStr);
    
    // Parse recurrence data
    String? initialRecurrence;
    Set<int>? initialWeeklyDays;
    DateTime? initialRecurrenceEndDate;
    
    if (recurrence != null && recurrence is Map<String, dynamic>) {
      final type = recurrence['type']?.toString().toLowerCase();
      if (type != null && type != 'none') {
        // Map AI recurrence types to TaskForm types
        switch (type) {
          case 'daily':
            initialRecurrence = 'daily';
            break;
          case 'weekly':
            initialRecurrence = 'weekly';
            // Parse weekly days if provided by AI
            final days = recurrence['days'] as List<dynamic>?;
            final singleDay = recurrence['day']?.toString();
            
            if (days != null && days.isNotEmpty) {
              // Handle "days" array format
              initialWeeklyDays = <int>{};
              for (final day in days) {
                final dayStr = day.toString().toLowerCase();
                switch (dayStr) {
                  case 'monday':
                    initialWeeklyDays.add(1);
                    break;
                  case 'tuesday':
                    initialWeeklyDays.add(2);
                    break;
                  case 'wednesday':
                    initialWeeklyDays.add(3);
                    break;
                  case 'thursday':
                    initialWeeklyDays.add(4);
                    break;
                  case 'friday':
                    initialWeeklyDays.add(5);
                    break;
                  case 'saturday':
                    initialWeeklyDays.add(6);
                    break;
                  case 'sunday':
                    initialWeeklyDays.add(7);
                    break;
                }
              }
            } else if (singleDay != null && singleDay.isNotEmpty) {
              // Handle single "day" field format
              initialWeeklyDays = <int>{};
              final dayStr = singleDay.toLowerCase();
              switch (dayStr) {
                case 'monday':
                  initialWeeklyDays.add(1);
                  break;
                case 'tuesday':
                  initialWeeklyDays.add(2);
                  break;
                case 'wednesday':
                  initialWeeklyDays.add(3);
                  break;
                case 'thursday':
                  initialWeeklyDays.add(4);
                  break;
                case 'friday':
                  initialWeeklyDays.add(5);
                  break;
                case 'saturday':
                  initialWeeklyDays.add(6);
                  break;
                case 'sunday':
                  initialWeeklyDays.add(7);
                  break;
              }
              print('Weekly recurrence detected, AI specified day: $singleDay (${initialWeeklyDays.first})');
            } else if (dueAt != null) {
              // No specific days provided by AI, auto-select based on due date
              initialWeeklyDays = <int>{dueAt.weekday};
              print('Weekly recurrence detected, auto-selected weekday: ${dueAt.weekday} (${_getWeekdayName(dueAt.weekday)})');
            }
            break;
          case 'monthly':
            initialRecurrence = 'monthly';
            break;
          case 'yearly':
            // TaskForm doesn't support yearly, fallback to monthly  
            initialRecurrence = 'monthly';
            break;
        }
        
        // Parse until date if provided
        final until = recurrence['until']?.toString();
        if (until != null && until.isNotEmpty && until != 'null') {
          try {
            initialRecurrenceEndDate = DateTime.parse(until);
          } catch (e) {
            // If parsing fails, set a default end date
            initialRecurrenceEndDate = dueAt?.add(const Duration(days: 90)) ?? DateTime.now().add(const Duration(days: 90));
          }
        }
      }
    }
    
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TaskForm(
          initialTitle: title,
          initialNotes: notes.isNotEmpty ? notes : null,
          initialDueAt: dueAt,
          initialRecurrence: initialRecurrence,
          initialWeeklyDays: initialWeeklyDays,
          initialRecurrenceEndDate: initialRecurrenceEndDate,
        ),
      ),
    );
    
    // Show success message if task was saved
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task created from image')),
      );
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }



  @override
  void initState() {
    super.initState();
    // Initialize standalone mode setting
    _standaloneMode = SettingsService.standaloneMode;
    
    // listen for sign-in changes from the sync service
    _userSub = FirestoreSyncService.instance.userChanges.listen((email) {
      setState(() {
        _userEmail = email;
      });
    });
    // No automatic sign-in or dev auto-run: user must press the login button to sign in.
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Reminder'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TasksListScreen()));
            },
          ),
          // Hide user email and login button in standalone mode
          if (!_standaloneMode) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Text(
                  _userEmail ?? 'Not signed in',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            
            // Family sharing button (only show when signed in)
            if (_userEmail != null && _userEmail != 'offline-user@local')
              IconButton(
                icon: const Icon(Icons.people),
                tooltip: 'Family Sharing',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FamilySharingScreen()),
                  );
                },
              ),

            IconButton(
              icon: Icon(_userEmail == null ? Icons.login : Icons.logout),
              tooltip: _userEmail == null ? 'Sign in to sync' : 'Sign out',
              onPressed: () async {
                if (_userEmail == null) {
                  _showLoginOptions(context);
                } else {
                  try {
                    await FirestoreSyncService.instance.signOut();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign-out failed')));
                  }
                }
              },
            ),
          ],
          // Dev controls moved to Settings (one-tap Run dev sync and hidden dev menu).
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
              _updateStandaloneMode(); // Refresh standalone mode after returning from settings
            },
          ),
          IconButton(
            tooltip: 'Enable audio',
            icon: const Icon(Icons.volume_up),
            onPressed: () {
              try {
                AudioPriming.showOverlay();
              } catch (_) {}
            },
          ),
        ],
      ),
      body: Column(children: [
        const AdBar(),
        DateStrip(initialDate: DateTime.now(), onDateSelected: _onDateSelected),
        Expanded(child: TasksForDate(date: _selectedDate)),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final res = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TaskForm()));
          if (res == true) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task created')));
          }
        },
        child: const Icon(Icons.add),
      ),
      persistentFooterButtons: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ElevatedButton.icon(
                  onPressed: _onPictureInput,
                  icon: const Icon(Icons.image, size: 20),
                  label: const Text('Picture', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ElevatedButton.icon(
                  onPressed: _onCameraInput,
                  icon: const Icon(Icons.camera_alt, size: 20),
                  label: const Text('Camera', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: VoiceButton(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getWeekdayName(int weekday) {
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return names[weekday - 1];
  }

  void _showLoginOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign In'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose your sign-in method:'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '� Email works on all devices including Huawei\n🔍 Google may not work on some restricted devices',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                _showEmailSignInDialog(context);
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.email, size: 16, color: Colors.blue),
                  SizedBox(width: 4),
                  Text('Email Sign-In'),
                ],
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                try {
                  await FirestoreSyncService.instance.init();
                  final res = await FirestoreSyncService.instance.signInWithGoogle();
                  
                  if (mounted && res != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Signed in as: ${res['email']}')));
                  }
                } catch (e) {
                  // Only show error messages if the widget is still mounted
                  if (!mounted) return;
                  
                  final msg = e.toString();
                  
                  // Don't show error for user-cancelled actions (popup closed)
                  if (msg.contains('popup-closed-by-user') || msg.contains('user-cancelled')) {
                    print('[Home] Sign-in cancelled by user');
                    return; // Silently return without showing error
                  }
                  
                  String errorMessage = 'Google sign-in failed';
                  if (msg.contains('configuration-not-found') || msg.contains('firebase-not-initialized')) {
                    errorMessage = 'Google sign-in not available on this device. Try Email sign-in instead.';
                  } else if (msg.contains('network-error') || msg.contains('network') || msg.contains('connectivity')) {
                    errorMessage = 'Network error - check internet connection';
                  } else if (msg.contains('google-signin-not-available')) {
                    errorMessage = 'Google Play Services unavailable. Use Email sign-in instead.';
                  } else if (msg.contains('huawei-device-restriction')) {
                    errorMessage = 'Huawei device detected: Google sign-in restricted. Use Email sign-in instead.';
                  } else if (msg.contains('google-signin-not-available-on-device')) {
                    errorMessage = 'Google authentication unavailable. Use Email sign-in instead.';
                  }
                  
                  // Only show error if widget is still mounted
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorMessage),
                        duration: const Duration(seconds: 4),
                        backgroundColor: Colors.red,
                        action: SnackBarAction(
                          label: 'Use Email',
                          textColor: Colors.white,
                          onPressed: () {
                            if (mounted) {
                              _showEmailSignInDialog(context);
                            }
                          },
                        ),
                      ));
                  }
                }
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_circle, size: 16),
                  SizedBox(width: 4),
                  Text('Google Account'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showEmailSignInDialog(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isCreatingAccount = false;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isCreatingAccount ? 'Create Account' : 'Sign In with Email'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isCreatingAccount 
                      ? 'Password should be at least 6 characters'
                      : 'Enter your email and password',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      isCreatingAccount = !isCreatingAccount;
                    });
                  },
                  child: Text(isCreatingAccount ? 'Already have account? Sign In' : 'Need account? Create One'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final email = emailController.text.trim();
                    final password = passwordController.text;
                    
                    if (email.isEmpty || password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill in all fields')),
                      );
                      return;
                    }
                    
                    if (password.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password must be at least 6 characters')),
                      );
                      return;
                    }
                    
                    Navigator.of(dialogContext).pop();
                    
                    try {
                      await FirestoreSyncService.instance.init();
                      
                      final res = isCreatingAccount 
                        ? await FirestoreSyncService.instance.createAccountWithEmail(email, password)
                        : await FirestoreSyncService.instance.signInWithEmail(email, password);
                      
                      if (mounted && res != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ ${isCreatingAccount ? "Account created" : "Signed in"} as: ${res['email']}'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      // Only show errors if widget is still mounted
                      if (!mounted) return;
                      
                      String errorMsg = 'Authentication failed';
                      
                      if (e.toString().contains('user-not-found')) {
                        errorMsg = 'No account found with this email. Try creating an account.';
                      } else if (e.toString().contains('wrong-password')) {
                        errorMsg = 'Incorrect password. Please try again.';
                      } else if (e.toString().contains('email-already-in-use')) {
                        errorMsg = 'Account already exists. Try signing in instead.';
                      } else if (e.toString().contains('weak-password')) {
                        errorMsg = 'Password is too weak. Use at least 6 characters.';
                      } else if (e.toString().contains('invalid-email')) {
                        errorMsg = 'Invalid email address format.';
                      } else if (e.toString().contains('network')) {
                        errorMsg = 'Network error. Check your internet connection.';
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(errorMsg),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                  child: Text(isCreatingAccount ? 'Create Account' : 'Sign In'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Removed manual sync choice dialog — sign-in automatically fetches server data.
}
