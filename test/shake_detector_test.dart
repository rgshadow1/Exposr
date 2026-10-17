import 'package:breach_checker/utils/shake_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 1, 1, 12);

  /// A hard jolt of the given strength along one axis, [ms] after the start.
  bool jolt(ShakeDetector detector, int ms, {double strength = 20}) {
    return detector.addReading(x: strength, y: 0, z: 0, at: start.add(Duration(milliseconds: ms)));
  }

  test('a phone sitting still is never a shake', () {
    final detector = ShakeDetector();

    for (var ms = 0; ms < 3000; ms += 20) {
      expect(detector.addReading(x: 0.1, y: 0.2, z: 0.1, at: start.add(Duration(milliseconds: ms))), isFalse);
    }
  });

  test('one hard jolt is not a shake', () {
    final detector = ShakeDetector();

    expect(jolt(detector, 0), isFalse);
  });

  test('two hard jolts in quick succession are a shake', () {
    final detector = ShakeDetector();

    expect(jolt(detector, 0), isFalse);
    expect(jolt(detector, 300), isTrue);
  });

  test('two jolts too far apart are not a shake', () {
    final detector = ShakeDetector();

    expect(jolt(detector, 0), isFalse);
    expect(jolt(detector, 2000), isFalse);
  });

  test('the many readings of one jolt count as a single jolt', () {
    final detector = ShakeDetector();

    // Readings 20 ms apart, all part of the same movement.
    expect(jolt(detector, 0), isFalse);
    expect(jolt(detector, 20), isFalse);
    expect(jolt(detector, 40), isFalse);
    expect(jolt(detector, 60), isFalse);
  });

  test('a gentle movement below the threshold is ignored', () {
    final detector = ShakeDetector();

    expect(jolt(detector, 0, strength: 8), isFalse);
    expect(jolt(detector, 300, strength: 8), isFalse);
  });

  test('strength is measured across all three axes', () {
    final detector = ShakeDetector();

    // About 17 in total, though no single axis passes the threshold of 14.
    expect(detector.addReading(x: 10, y: 10, z: 10, at: start), isFalse);
    expect(detector.addReading(x: 10, y: 10, z: 10, at: start.add(const Duration(milliseconds: 300))), isTrue);
  });

  test('after a shake, a cooldown stops the same shake being reported again', () {
    final detector = ShakeDetector();

    expect(jolt(detector, 0), isFalse);
    expect(jolt(detector, 300), isTrue);
    expect(jolt(detector, 600), isFalse);
    expect(jolt(detector, 900), isFalse);

    // Once the cooldown has passed, a fresh shake counts again.
    expect(jolt(detector, 2000), isFalse);
    expect(jolt(detector, 2300), isTrue);
  });
}
