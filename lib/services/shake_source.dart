import 'package:sensors_plus/sensors_plus.dart';

import '../utils/shake_detector.dart';

/// Something that emits an event each time the phone is shaken.
///
/// An interface, so tests can trigger shakes by hand.
abstract interface class ShakeSource {
  Stream<void> get shakes;
}

/// Listens to the accelerometer. The sensor is only read while someone is
/// listening to [shakes], which the app does only when "Shake to hide" is on.
class SensorsShakeSource implements ShakeSource {
  const SensorsShakeSource();

  @override
  Stream<void> get shakes {
    final detector = ShakeDetector();
    return userAccelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
        // A phone without this sensor reports an error: ignore it quietly.
        .handleError((Object _) {})
        .where((event) => detector.addReading(x: event.x, y: event.y, z: event.z, at: DateTime.now()))
        .map((_) {});
  }
}

/// Never shakes. The default in tests.
class NoShakeSource implements ShakeSource {
  const NoShakeSource();

  @override
  Stream<void> get shakes => const Stream<void>.empty();
}
