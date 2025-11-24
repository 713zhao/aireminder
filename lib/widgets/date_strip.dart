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
  static const int _centerIndex = 1000; // reasonable center value that avoids precision errors
  late DateTime _selectedDate;
  late DateTime _anchorDate; // the date that corresponds to _centerIndex
  final Map<String, int> _taskCounts = {};
  StreamSubscription? _taskSub;
  Timer? _settleTimer;
  Timer? _programmaticSettleTimer;
  bool _isUserInteracting = false;
  bool _pendingTaskCountsReload = false;
  bool _isProgrammaticScroll = false;
  bool _expectingParentUpdate = false;
  late int _lastHighlightedIndex;
  late VoidCallback _controllerListener;
  static const Duration _settleDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _anchorDate = widget.initialDate;
  _controller = PageController(initialPage: _centerIndex);
    _lastHighlightedIndex = _centerIndex;
    _controllerListener = () {
      if (!_controller.hasClients) return;
      final p = _controller.page;
      if (p == null) return;
      final int highlighted = p.round();
      if (highlighted != _lastHighlightedIndex) {
        _lastHighlightedIndex = highlighted;
        final date = _dateForIndex(highlighted);
        // Only update UI highlight, don't notify parent here; parent is
        // notified after settle timers in onPageChanged/ScrollEnd.
        if (date.year != _selectedDate.year || date.month != _selectedDate.month || date.day != _selectedDate.day) {
          setState(() => _selectedDate = date);
        }
      }
    };
    _controller.addListener(_controllerListener);
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
    final date = _anchorDate.add(Duration(days: offset));
    // Normalize to midnight to avoid DST issues
    return DateTime(date.year, date.month, date.day);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification is ScrollEndNotification) {
            // When scrolling ends, determine which page is centered
            if (_controller.hasClients && _controller.page != null) {
              final int centeredPage = _controller.page!.round();
              final date = _dateForIndex(centeredPage);
              if (date.year != _selectedDate.year || 
                  date.month != _selectedDate.month || 
                  date.day != _selectedDate.day) {
                // Update local selection only. Defer notifying parent until
                // onPageChanged's settle timer runs to avoid parent rebuilding
                // with a different initialDate mid-navigation.
                setState(() => _selectedDate = date);
                _pendingTaskCountsReload = true;
              }
            }
          }
          return false;
        },
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              allowImplicitScrolling: true,
              onPageChanged: (index) {
                final date = _dateForIndex(index);
                
                // Update selection UI immediately
                setState(() => _selectedDate = date);

                if (_isProgrammaticScroll) {
                  // Programmatic navigation: clear flag and use a separate
                  // debounce timer so rapid programmatic taps are coalesced
                  // and we notify the parent only once after the sequence
                  // finishes.
                  _isProgrammaticScroll = false;
                  _programmaticSettleTimer?.cancel();
                  _programmaticSettleTimer = Timer(_settleDuration, () async {
                    // Notify parent once programmatic navigation has settled
                    _expectingParentUpdate = true;
                    widget.onDateSelected(_selectedDate);
                    if (_pendingTaskCountsReload) {
                      _pendingTaskCountsReload = false;
                      await _loadTaskCounts();
                    } else {
                      await _loadTaskCounts();
                    }
                  });
                } else {
                  // User interaction: treat as before
                  _isUserInteracting = true;
                  _settleTimer?.cancel();
                  _settleTimer = Timer(_settleDuration, () async {
                    _isUserInteracting = false;
                    // Notify parent that date selection is final
                    _expectingParentUpdate = true;
                    widget.onDateSelected(_selectedDate);
                    // Perform task count refresh after settle
                    if (_pendingTaskCountsReload) {
                      _pendingTaskCountsReload = false;
                      await _loadTaskCounts();
                    } else {
                      await _loadTaskCounts();
                    }
                  });
                }
              },
              itemBuilder: (context, index) {
                // Each page represents a single center date, but visually
                // show the previous and next dates to the left and right.
                final centerDate = _dateForIndex(index);
                final prevDate = centerDate.subtract(const Duration(days: 1));
                final nextDate = centerDate.add(const Duration(days: 1));
                final isSelected = centerDate.year == _selectedDate.year && centerDate.month == _selectedDate.month && centerDate.day == _selectedDate.day;

                return Row(
                  children: [
                    // Previous date (left)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          final currentPage = _controller.hasClients && _controller.page != null ? _controller.page!.round() : index;
                          final targetPage = currentPage - 1;
                          
                          _isProgrammaticScroll = true;
                          _controller.animateToPage(
                            targetPage,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          );
                          // Update local selected date optimistically; defer
                          // notifying parent until settle timer.
                          final newDate = _dateForIndex(targetPage);
                          setState(() => _selectedDate = newDate);
                          _pendingTaskCountsReload = true;
                        },
                        child: _DayCell(
                          date: prevDate,
                          selected: false,
                          taskCount: _taskCounts[_dateKey(prevDate)] ?? 0,
                        ),
                      ),
                    ),

                    // Center date (highlighted)
                    Expanded(
                      child: _DayCell(
                        date: centerDate,
                        selected: isSelected,
                        taskCount: _taskCounts[_dateKey(centerDate)] ?? 0,
                      ),
                    ),

                    // Next date (right)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          final currentPage = _controller.hasClients && _controller.page != null ? _controller.page!.round() : index;
                          final targetPage = currentPage + 1;
                          
                          _isProgrammaticScroll = true;
                          _controller.animateToPage(
                            targetPage,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          );
                          final newDate = _dateForIndex(targetPage);
                          setState(() => _selectedDate = newDate);
                          _pendingTaskCountsReload = true;
                        },
                        child: _DayCell(
                          date: nextDate,
                          selected: false,
                          taskCount: _taskCounts[_dateKey(nextDate)] ?? 0,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _taskSub?.cancel();
    _controller.removeListener(_controllerListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DateStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent changed the initialDate (for example after
    // a notification), re-align the controller so the page indices map
    // consistently to dates. This prevents index->date drift when the
    // parent updates the date while the PageView is still using the old
    // initialDate mapping.
    bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    if (!isSameDay(oldWidget.initialDate, widget.initialDate)) {
      // If we expected the parent to update (because we just notified it),
      // and the new initialDate matches our current selection, consume
      // the update silently to avoid re-centering mid-navigation.
      if (_expectingParentUpdate && isSameDay(widget.initialDate, _selectedDate)) {
        _expectingParentUpdate = false;
        return;
      }

      _selectedDate = widget.initialDate;
      _anchorDate = widget.initialDate;
      // Move the controller back to center so _dateForIndex keeps mapping
      // index == _centerIndex -> widget.initialDate.
      if (_controller.hasClients) {
        _isProgrammaticScroll = true;
        _controller.jumpToPage(_centerIndex);
      }
    }
  }
}

/// ScrollPhysics that interprets fling velocity to move multiple pages in a PageView.

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
