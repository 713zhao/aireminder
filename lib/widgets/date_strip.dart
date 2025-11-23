import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../data/hive_task_repository.dart';

typedef DateSelectedCallback = void Function(DateTime date);

class DateStrip extends StatefulWidget {
  final DateTime initialDate;
  final DateSelectedCallback onDateSelected;

  const DateStrip({super.key, required this.initialDate, required this.onDateSelected});

  @override
  State<DateStrip> createState() => _DateStripState();
}

class _DateStripState extends State<DateStrip> {
  late final PageController _controller;
  static const int _centerIndex = 10000; // large center so user can scroll many days
  static const double _viewportFraction = 0.32;
  late DateTime _selectedDate;
  final Map<String, int> _taskCounts = {};
  StreamSubscription? _taskSub;
  Timer? _settleTimer;
  bool _isUserInteracting = false;
  bool _pendingTaskCountsReload = false;
  static const Duration _settleDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  _controller = PageController(viewportFraction: _viewportFraction, initialPage: _centerIndex);
      // file updated: month+date on same row, larger fonts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onDateSelected(_selectedDate);
    });
    _loadTaskCounts();
    // subscribe to changes so badges update live; if user is interacting we
    // defer the heavy reload until after sliding settles to avoid jank.
    try {
      _taskSub = HiveTaskRepository().watch().listen((_) {
        if (_isUserInteracting) {
          _pendingTaskCountsReload = true;
        } else {
          _loadTaskCounts();
        }
      });
    } catch (_) {}
  }

  String _dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadTaskCounts() async {
    try {
      final repo = HiveTaskRepository();
      final all = await repo.list();

      // Serialize tasks into JSON-serializable maps for compute()
      final List<Map<String, dynamic>> serial = all.map((t) => t.toJson()).toList();

      // build args for compute: include initialDate epoch and windowDays
      const int windowDays = 365;
      final args = {
        'tasks': serial,
        'initial': widget.initialDate.millisecondsSinceEpoch,
        'windowDays': windowDays,
      };

      final Map<String, int> counts = Map<String, int>.from(await compute(_computeTaskCounts, args));

      if (mounted) setState(() => _taskCounts
        ..clear()
        ..addAll(counts));
    } catch (_) {
      // ignore
    }
  }

// Top-level compute function to run in an isolate. Expects a Map with keys:
// - tasks: List<Map<String,dynamic>> (task JSON)
// - initial: int (millisecondsSinceEpoch)
// - windowDays: int
Future<Map<String, int>> _computeTaskCounts(Map<String, dynamic> payload) async {
  final List tasks = payload['tasks'] as List? ?? [];
  final int initialMs = payload['initial'] as int? ?? DateTime.now().millisecondsSinceEpoch;
  final int windowDays = payload['windowDays'] as int? ?? 365;

  DateTime initial = DateTime.fromMillisecondsSinceEpoch(initialMs);
  DateTime start = initial.subtract(Duration(days: windowDays));
  DateTime end = initial.add(Duration(days: windowDays));

  String dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  bool matchesOnDate(Map<String, dynamic> t, DateTime date) {
    if (t['dueAt'] == null) return false;
    final due = DateTime.parse(t['dueAt'] as String);
    final dueDate = DateTime(due.year, due.month, due.day);
    final target = DateTime(date.year, date.month, date.day);
    if (!target.isAfter(dueDate) && !isSameDay(dueDate, target)) return false;
    
    // Check if target date is after recurrence end date
    if (t['recurrenceEndDate'] != null) {
      final endDate = DateTime.parse(t['recurrenceEndDate'] as String);
      final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
      if (target.isAfter(endDateOnly)) {
        return false;
      }
    }
    
    final rec = t['recurrence'] as String?;
    if (rec == null || rec.isEmpty) return isSameDay(due, date);
    switch (rec) {
      case 'daily':
        return !target.isBefore(dueDate);
      case 'weekly':
        // Check if target date is after or on start date
        if (target.isBefore(dueDate)) {
          return false;
        }
        
        // For weekly tasks with specific weekdays selected
        final weeklyDays = t['weeklyDays'] as List<dynamic>?;
        if (weeklyDays != null && weeklyDays.isNotEmpty) {
          // Show on any of the selected weekdays
          return weeklyDays.contains(target.weekday);
        } else {
          // Default weekly behavior: only on the original due date's weekday
          return target.weekday == dueDate.weekday;
        }
      case 'monthly':
        if (dueDate.day == target.day && !target.isBefore(dueDate)) return true;
        return false;
      default:
        return isSameDay(due, date);
    }
  }

  final Map<String, int> counts = {};
  for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) counts[dateKey(d)] = 0;

  for (final dynamic t in tasks) {
    try {
      if (t['isCompleted'] == true) continue;
      for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
        try {
          if (matchesOnDate(t as Map<String, dynamic>, d)) {
            final key = dateKey(d);
            counts[key] = (counts[key] ?? 0) + 1;
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  return counts;
}

  DateTime _dateForIndex(int index) {
    final offset = index - _centerIndex;
    return widget.initialDate.add(Duration(days: offset));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: VelocityPageScrollPhysics(parent: const BouncingScrollPhysics(), viewportFraction: _viewportFraction),
        allowImplicitScrolling: true,
        onPageChanged: (index) {
          final date = _dateForIndex(index);
          // Update selection UI immediately, but delay expensive work and
          // notifying the parent until sliding/animation settles.
          setState(() => _selectedDate = date);
          _isUserInteracting = true;
          _settleTimer?.cancel();
          _settleTimer = Timer(_settleDuration, () async {
            _isUserInteracting = false;
            // Notify parent that date selection is final
            widget.onDateSelected(_selectedDate);
            // Perform task count refresh after settle. If a repo change
            // happened while interacting, ensure we reload now.
            if (_pendingTaskCountsReload) {
              _pendingTaskCountsReload = false;
              await _loadTaskCounts();
            } else {
              // Optionally refresh counts for smoother consistency.
              await _loadTaskCounts();
            }
          });
        },
        itemBuilder: (context, index) {
          final d = _dateForIndex(index);
          // Calculate which page is currently centered based on controller position
          final currentPage = _controller.hasClients ? _controller.page?.round() ?? _centerIndex : _centerIndex;
          final isSelected = index == currentPage;
          final int taskCount = _taskCounts[_dateKey(d)] ?? 0;
          return GestureDetector(
            onTap: () {
              // animate to tapped page
              _controller.animateToPage(index, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
            },
            child: _DayCell(date: d, selected: isSelected, taskCount: taskCount),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _taskSub?.cancel();
    _controller.dispose();
    super.dispose();
  }
}

/// ScrollPhysics that interprets fling velocity to move multiple pages in a PageView.
class VelocityPageScrollPhysics extends PageScrollPhysics {
  final double viewportFraction;

  const VelocityPageScrollPhysics({ScrollPhysics? parent, required this.viewportFraction}) : super(parent: parent);

  @override
  VelocityPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return VelocityPageScrollPhysics(parent: buildParent(ancestor), viewportFraction: viewportFraction);
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // If we're out of range or velocity is small, fall back to default behavior.
    if (position.outOfRange || velocity.abs() < 200.0) {
      return super.createBallisticSimulation(position, velocity);
    }

  final Tolerance tolerance = toleranceFor(position);

    // Compute logical page size and current page index.
    final double pageDimension = position.viewportDimension * viewportFraction;
    if (pageDimension <= 0) return super.createBallisticSimulation(position, velocity);
    final double currentPage = position.pixels / pageDimension;

    // Determine how many pages to move based on fling velocity.
    final int additional = (velocity.abs() / 1200).ceil(); // tune this factor if needed
    int targetPage = currentPage.round();
    if (velocity < 0) {
      // negative velocity: user swiped left -> move forward (increase index)
      targetPage += additional;
    } else {
      // positive velocity: swipe right -> move backward
      targetPage -= additional;
    }

    final double targetPixels = (targetPage * pageDimension).clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();

    return ScrollSpringSimulation(
      const SpringDescription(mass: 80, stiffness: 100, damping: 1),
      position.pixels,
      targetPixels,
      velocity,
      tolerance: tolerance,
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final int taskCount;

  const _DayCell({required this.date, this.selected = false, this.taskCount = 0});

  @override
  Widget build(BuildContext context) {
    final weekday = DateFormat.E().format(date); // Tue
    final day = DateFormat.d().format(date); // 4
    final month = DateFormat.MMM().format(date); // Oct
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        alignment: Alignment.center,
        constraints: const BoxConstraints(maxHeight: 88),
        decoration: BoxDecoration(
          color: selected ? Colors.blue : Colors.grey.shade200, // Blue for selected, light grey for unselected
          borderRadius: BorderRadius.circular(8),
          border: selected ? Border.all(color: Colors.blue.shade700, width: 2) : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(
                      weekday,
                      style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (taskCount > 0)
                    Positioned(
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: selected ? Colors.white70 : Colors.redAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 16),
                        child: Center(
                          child: Text(
                            taskCount > 9 ? '9+' : taskCount.toString(),
                            style: TextStyle(fontSize: 11, color: selected ? Colors.black87 : Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  day,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: selected ? Colors.white : Colors.black87),
                ),
                const SizedBox(width: 6),
                Text(
                  month.toUpperCase(),
                  style: TextStyle(fontSize: 12, color: selected ? Colors.white70 : Colors.black45),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
