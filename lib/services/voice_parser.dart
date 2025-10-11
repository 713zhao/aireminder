class VoiceParseResult {
  final String title;
  final DateTime? dueAt;
  final String? recurrence; // 'daily','weekly','monthly' or null

  VoiceParseResult({required this.title, this.dueAt, this.recurrence});

  @override
  String toString() => 'VoiceParseResult(title: $title, dueAt: $dueAt, recurrence: $recurrence)';
}

class VoiceParser {
  /// Parse a free-form voice command into a title, optional due date/time, and optional recurrence.
  /// This is a deterministic, rule-based parser intended for MVP use.
  static VoiceParseResult parse(String input, {DateTime? now}) {
    now ??= DateTime.now();
    var text = input.trim();
    // Normalize
    text = text.replaceAll(RegExp('\s+'), ' ').toLowerCase();

    DateTime? due;
    String? recurrence;

    // Detect recurrence: every day/week/month, daily, weekly, monthly
    final recurMatch = RegExp(r'\bevery\s+(day|week|month)|\b(daily|weekly|monthly)\b').firstMatch(text);
    if (recurMatch != null) {
      recurrence = (recurMatch.group(1) ?? recurMatch.group(2))!;
      recurrence = recurrence.replaceAll('daily', 'day').replaceAll('weekly', 'week').replaceAll('monthly', 'month');
      // remove the recurrence phrase from text
      text = text.replaceFirst(recurMatch.group(0)!, '').trim();
    }

    // Detect "in X minutes/hours/days"
    final inMatch = RegExp(r'\bin\s+(\d+)\s+(minute|minutes|hour|hours|day|days)\b').firstMatch(text);
    if (inMatch != null) {
      final val = int.tryParse(inMatch.group(1)!) ?? 0;
      final unit = inMatch.group(2)!;
      if (unit.startsWith('minute')) due = now.add(Duration(minutes: val));
      if (unit.startsWith('hour')) due = now.add(Duration(hours: val));
      if (unit.startsWith('day')) due = now.add(Duration(days: val));
      text = text.replaceFirst(inMatch.group(0)!, '').trim();
    }

    // Detect "tomorrow" and "today"
    if (due == null && text.contains('tomorrow')) {
      due = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      text = text.replaceFirst('tomorrow', '').trim();
    }
    if (due == null && text.contains('today')) {
      due = DateTime(now.year, now.month, now.day);
      text = text.replaceFirst('today', '').trim();
    }

    // Weekday names: next monday, monday
    final weekdays = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };
    for (final name in weekdays.keys) {
      if (text.contains('next $name') || text.contains('this $name')) {
        final target = weekdays[name]!;
        due = _nextWeekday(now, target);
        text = text.replaceFirst(RegExp(r'next\s+' + name), '').replaceFirst(RegExp(r'this\s+' + name), '').trim();
        break;
      } else if (text.contains(' $name') || text.startsWith(name)) {
        // plain weekday -> next occurrence of that weekday
        if (text.contains(name)) {
          final target = weekdays[name]!;
          due = _nextWeekday(now, target);
          text = text.replaceFirst(name, '').trim();
          break;
        }
      }
    }

    // Detect time "at 9am", "at 9:30 pm", "9am"
    final timeMatch = RegExp(r'\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b').firstMatch(text);
    if (timeMatch != null) {
      final hourRaw = int.parse(timeMatch.group(1)!);
      final minute = timeMatch.group(2) != null ? int.parse(timeMatch.group(2)!) : 0;
      final ampm = timeMatch.group(3);
      int hour = hourRaw;
      if (ampm != null) {
        final a = ampm.toLowerCase();
        if (a == 'pm' && hour < 12) hour += 12;
        if (a == 'am' && hour == 12) hour = 0;
      }
      if (due == null) {
        due = DateTime(now.year, now.month, now.day, hour, minute);
        if (due.isBefore(now)) {
          // assume next day
          due = due.add(const Duration(days: 1));
        }
      } else {
        // combine date from due with time
        due = DateTime(due.year, due.month, due.day, hour, minute);
      }
      text = text.replaceFirst(timeMatch.group(0)!, '').trim();
    }

    // Remove leading commands like 'remind me to', 'set a reminder to', 'add'
    text = text.replaceFirst(RegExp(r'^(remind me to|remind me|set (a )?reminder to|add|create|please)\s*'), '');

    // Final title cleanup: if trailing 'at' or 'on' leftover, strip it
    text = text.replaceAll(RegExp(r'\b(on|at)\b\s*\$'), '').trim();

    // If title is empty, fallback to original input
    final title = text.isEmpty ? input.trim() : _capitalize(text);

    return VoiceParseResult(title: title, dueAt: due, recurrence: recurrence);
  }

  static DateTime _nextWeekday(DateTime from, int weekday) {
    int daysToAdd = (weekday - from.weekday) % 7;
    if (daysToAdd <= 0) daysToAdd += 7;
    return DateTime(from.year, from.month, from.day).add(Duration(days: daysToAdd));
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
