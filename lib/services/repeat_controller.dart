import 'dart:async';

typedef RepeatCallback = void Function();

class RepeatController {
  RepeatController({
    this.interval = const Duration(seconds: 20),
    this.capDuration,
    this.maxRepeats,
    required this.onTick,
  });

  final Duration interval;
  final Duration? capDuration;
  final int? maxRepeats;
  final RepeatCallback onTick;

  Timer? _timer;
  DateTime? _startTime;
  int _count = 0;

  bool get isActive => _timer != null;
  int get firedCount => _count;

  void start({Duration? intervalOverride}) {
    if (isActive) return;
    _startTime = DateTime.now();
    _count = 0;
    final effectiveInterval = intervalOverride ?? interval;
    // Fire immediately once, then schedule periodic ticks
    _fire();
    _timer = Timer.periodic(effectiveInterval, (_) => _tick(effectiveInterval));
  }

  void _tick(Duration effectiveInterval) {
    if (_shouldStop()) {
      stop();
      return;
    }
    _fire();
  }

  void _fire() {
    try {
      onTick();
    } catch (_) {}
    _count++;
  }

  bool _shouldStop() {
    if (maxRepeats != null && _count >= maxRepeats!) return true;
    if (capDuration != null && _startTime != null) {
      final elapsed = DateTime.now().difference(_startTime!);
      if (elapsed >= capDuration!) return true;
    }
    return false;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _startTime = null;
  }

  void pause() {
    // Simplified pause: cancel timer but keep state; resume starts fresh periodic ticks
    _timer?.cancel();
    _timer = null;
  }

  void resume({Duration? intervalOverride}) {
    if (isActive) return;
    final effectiveInterval = intervalOverride ?? interval;
    _timer = Timer.periodic(effectiveInterval, (_) => _tick(effectiveInterval));
  }

  Map<String, dynamic> toJson() {
    return {
      'intervalSeconds': interval.inSeconds,
      'capDurationSeconds': capDuration?.inSeconds,
      'maxRepeats': maxRepeats,
      'count': _count,
      'isActive': isActive,
    };
  }
}
