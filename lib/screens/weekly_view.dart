import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/hive_task_repository.dart';
import '../models/task.dart';
import '../screens/task_detail.dart';

class WeeklyViewScreen extends StatefulWidget {
  const WeeklyViewScreen({super.key});

  @override
  State<WeeklyViewScreen> createState() => _WeeklyViewScreenState();
}

class _WeeklyViewScreenState extends State<WeeklyViewScreen> {
  final _repo = HiveTaskRepository();
  DateTime _currentWeekStart = DateTime.now();
  List<Task> _allTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentWeekStart = _getWeekStart(DateTime.now());
    _loadTasks();
  }

  DateTime _getWeekStart(DateTime date) {
    // Get Monday of the week
    return date.subtract(Duration(days: date.weekday - 1));
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final tasks = await _repo.list();
    setState(() {
      _allTasks = tasks;
      _isLoading = false;
    });
  }

  void _previousWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
    });
  }

  void _nextWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
    });
  }

  void _goToToday() {
    setState(() {
      _currentWeekStart = _getWeekStart(DateTime.now());
    });
  }

  List<Task> _getTasksForDay(DateTime day) {
    final filtered = _allTasks.where((task) {
      if (task.dueAt == null) return false;
      return _matchesOnDate(task, day);
    }).toList();
    
    filtered.sort((a, b) => _occurrenceForDate(a, day).compareTo(_occurrenceForDate(b, day)));
    return filtered;
  }

  bool _matchesOnDate(Task t, DateTime date) {
    final due = DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day);
    final target = DateTime(date.year, date.month, date.day);
    if (!target.isAfter(due) && !_isSameDay(due, target)) {
      // target before due date
      return false;
    }

    // Check if target date is after recurrence end date
    if (t.recurrenceEndDate != null) {
      final endDate = DateTime(t.recurrenceEndDate!.year, t.recurrenceEndDate!.month, t.recurrenceEndDate!.day);
      if (target.isAfter(endDate)) {
        return false;
      }
    }

    final rec = t.recurrence;
    if (rec == null || rec.isEmpty) {
      return _isSameDay(t.dueAt!, date);
    }

    switch (rec) {
      case 'daily':
        return !target.isBefore(due);
      case 'weekly':
        // Check if target date is after or on start date
        if (target.isBefore(due)) {
          return false;
        }
        
        // For weekly tasks with specific weekdays selected
        if (t.weeklyDays != null && t.weeklyDays!.isNotEmpty) {
          // Show on any of the selected weekdays
          return t.weeklyDays!.contains(target.weekday);
        } else {
          // Default weekly behavior: only on the original due date's weekday
          return target.weekday == due.weekday;
        }
      case 'monthly':
        // same day-of-month (best-effort)
        if (due.day == target.day && !target.isBefore(due)) return true;
        return false;
      default:
        return _isSameDay(t.dueAt!, date);
    }
  }

  DateTime _occurrenceForDate(Task t, DateTime date) {
    // Build occurrence datetime on the target date using time from original dueAt
    final time = t.dueAt!;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute, time.second, time.millisecond, time.microsecond);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Color _getTaskColor(Task task, DateTime taskDate) {
    if (task.dueAt == null) return Colors.grey;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDay = DateTime(taskDate.year, taskDate.month, taskDate.day);
    
    // Past days: always grey
    if (taskDay.isBefore(today)) {
      return Colors.grey.shade300;
    }
    
    // Today: compare time only
    if (_isSameDay(taskDay, today)) {
      final taskTime = TimeOfDay.fromDateTime(task.dueAt!);
      final nowTime = TimeOfDay.fromDateTime(now);
      
      final taskMinutes = taskTime.hour * 60 + taskTime.minute;
      final nowMinutes = nowTime.hour * 60 + nowTime.minute;
      final diffMinutes = taskMinutes - nowMinutes;
      
      if (diffMinutes < 0) {
        return Colors.red.shade300; // Time passed
      } else if (diffMinutes < 120) {
        return Colors.orange.shade300; // Due within 2 hours
      } else {
        return Colors.blue.shade200; // Normal
      }
    }
    
    // Future dates: always blue
    return Colors.blue.shade200;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getWeekRangeText()),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Go to today',
            onPressed: _goToToday,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadTasks,
          ),
        ],
      ),
      body: Column(
        children: [
          // Week navigation
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousWeek,
                ),
                Text(
                  _getWeekRangeText(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextWeek,
                ),
              ],
            ),
          ),
          
          // Week view grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildWeekGrid(),
          ),
        ],
      ),
    );
  }

  String _getWeekRangeText() {
    final weekEnd = _currentWeekStart.add(const Duration(days: 6));
    final startFormat = DateFormat('MMM d');
    final endFormat = DateFormat('MMM d, yyyy');
    return '${startFormat.format(_currentWeekStart)} - ${endFormat.format(weekEnd)}';
  }

  Widget _buildWeekGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 800;
        
        if (isWideScreen) {
          // Desktop/tablet layout - 7 columns side by side
          return _buildDesktopLayout();
        } else {
          // Mobile layout - scrollable list
          return _buildMobileLayout();
        }
      },
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(7, (index) {
        final day = _currentWeekStart.add(Duration(days: index));
        return Expanded(
          child: _buildDayColumn(day),
        );
      }),
    );
  }

  Widget _buildMobileLayout() {
    return ListView.builder(
      itemCount: 7,
      itemBuilder: (context, index) {
        final day = _currentWeekStart.add(Duration(days: index));
        return _buildDaySection(day);
      },
    );
  }

  Widget _buildDayColumn(DateTime day) {
    final tasks = _getTasksForDay(day);
    final isToday = _isToday(day);
    
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Day header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isToday
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('E').format(day),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isToday ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('d').format(day),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isToday ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          
          // Tasks list
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'No tasks',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      return _buildTaskCard(tasks[index], day, compact: true);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySection(DateTime day) {
    final tasks = _getTasksForDay(day);
    final isToday = _isToday(day);
    
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: isToday ? 4 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isToday
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                Text(
                  DateFormat('EEEE').format(day),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isToday ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM d').format(day),
                  style: TextStyle(
                    fontSize: 14,
                    color: isToday ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isToday
                        ? Colors.white.withOpacity(0.3)
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isToday ? Colors.white : Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Tasks list
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No tasks scheduled',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              itemCount: tasks.length,
              separatorBuilder: (context, index) => const Divider(height: 8),
              itemBuilder: (context, index) {
                return _buildTaskCard(tasks[index], day, compact: false);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task, DateTime taskDate, {required bool compact}) {
    final timeText = task.dueAt != null
        ? DateFormat('h:mm a').format(task.dueAt!.toLocal())
        : '';
    
    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TaskDetailScreen(taskId: task.id),
          ),
        );
        _loadTasks(); // Refresh after viewing details
      },
      child: Container(
        margin: compact
            ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
            : EdgeInsets.zero,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _getTaskColor(task, taskDate),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Time
            if (timeText.isNotEmpty)
              Text(
                timeText,
                style: TextStyle(
                  fontSize: compact ? 10 : 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            const SizedBox(height: 2),
            
            // Title
            Text(
              task.title,
              style: TextStyle(
                fontSize: compact ? 11 : 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
            ),
            
            // Notes preview (non-compact only)
            if (!compact && task.notes != null && task.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                task.notes!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            
            // Recurrence indicator
            if (task.recurrence != null && task.recurrence!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.repeat,
                      size: compact ? 10 : 12,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      task.recurrence!,
                      style: TextStyle(
                        fontSize: compact ? 9 : 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return _isSameDay(date, now);
  }
}
