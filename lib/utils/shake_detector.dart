import 'dart:math' as math;

/// Decides, from a stream of accelerometer readings, when the phone was shaken.
///
/// It is plain Dart with no sensor in it, so it can be tested by feeding it
/// numbers. The readings are "user acceleration": the phone's movement with
/// gravity already removed, in metres per second squared. Sitting still it is
/// about 0; a deliberate shake pushes it well past 10.
///
/// A shake is [requiredSpikes] hard jolts inside [window]. One jolt produces
/// many consecutive readings, so readings closer than [jolt] apart count as the
/// same jolt. After a shake is reported, [cooldown] ignores further readings so
/// a single shake isn't reported three times.
class ShakeDetector {
  ShakeDetector({
    this.threshold = 14,
    this.requiredSpikes = 2,
    this.window = const Duration(milliseconds: 900),
    this.cooldown = const Duration(milliseconds: 1200),
    this.jolt = const Duration(milliseconds: 120),
  });

  final double threshold;
  final int requiredSpikes;
  final Duration window;
  final Duration cooldown;
  final Duration jolt;

  final List<DateTime> _spikes = [];
  DateTime? _lastShake;
  DateTime? _lastHardReading;

  /// Feeds one reading in. Returns true if this reading completes a shake.
  bool addReading({required double x, required double y, required double z, required DateTime at}) {
    final magnitude = math.sqrt(x * x + y * y + z * z);
    if (magnitude < threshold) return false;

    final lastShake = _lastShake;
    if (lastShake != null && at.difference(lastShake) < cooldown) return false;

    // Readings in quick succession belong to the same jolt.
    final lastHard = _lastHardReading;
    _lastHardReading = at;
    if (lastHard != null && at.difference(lastHard) < jolt) return false;

    _spikes.removeWhere((time) => at.difference(time) > window);
    _spikes.add(at);

    if (_spikes.length >= requiredSpikes) {
      _spikes.clear();
      _lastShake = at;
      return true;
    }
    return false;
  }
}
