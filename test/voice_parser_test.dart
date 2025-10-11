import 'package:flutter_test/flutter_test.dart';
import 'package:todo_reminder_app/services/voice_parser.dart';

void main() {
  test('parses tomorrow at 9am', () {
    final now = DateTime(2025, 10, 4, 8, 0); // Oct 4, 2025 08:00
    final res = VoiceParser.parse('Remind me to buy milk tomorrow at 9am', now: now);
    expect(res.title.toLowerCase(), contains('buy milk'));
    expect(res.dueAt, isNotNull);
    expect(res.dueAt!.hour, equals(9));
  });

  test('parses in 10 minutes', () {
    final now = DateTime(2025, 10, 4, 8, 0);
    final res = VoiceParser.parse('Remind me to call John in 10 minutes', now: now);
    expect(res.dueAt, isNotNull);
    expect(res.dueAt!.minute, equals(10));
  });

  test('parses recurring every day', () {
    final now = DateTime(2025, 10, 4, 8, 0);
    final res = VoiceParser.parse('Remind me to stretch every day at 7am', now: now);
    expect(res.recurrence, isNotNull);
    expect(res.recurrence, contains('day'));
  });
}
