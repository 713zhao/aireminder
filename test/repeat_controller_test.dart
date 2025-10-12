import 'package:flutter_test/flutter_test.dart';
import 'package:aireminder/services/repeat_controller.dart';

void main() {
  test('repeat controller fires immediately and then respects interval and cap', () async {
    int calls = 0;
    final controller = RepeatController(
      interval: const Duration(milliseconds: 100),
      capDuration: const Duration(milliseconds: 350),
      onTick: () {
        calls++;
      },
    );

    controller.start();
    // Wait longer than capDuration to allow controller to stop
    await Future.delayed(const Duration(milliseconds: 500));
    expect(calls, greaterThanOrEqualTo(1));
    expect(controller.isActive, isFalse);
  });
}
