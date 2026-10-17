import 'package:flutter/services.dart';

/// Vibration feedback for the three things a check can end in.
///
/// An interface, so tests can swap in a fake that records which pattern was
/// asked for. (The decision to vibrate is testable; the buzz itself is not.)
abstract interface class HapticsService {
  /// Breaches were found: a firm double pulse.
  Future<void> breached();

  /// Nothing was found: one soft tap.
  Future<void> clean();

  /// The check failed: a short click.
  Future<void> failed();
}

/// Uses the phone's own haptic engine through Flutter's built-in
/// [HapticFeedback], so no extra package or permission is needed.
///
/// Errors are swallowed: a phone without a vibration motor should simply not
/// vibrate, never crash.
class SystemHapticsService implements HapticsService {
  const SystemHapticsService();

  @override
  Future<void> breached() async {
    try {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 140));
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  @override
  Future<void> clean() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  @override
  Future<void> failed() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}

/// Does nothing. The default in tests.
class NoHapticsService implements HapticsService {
  const NoHapticsService();

  @override
  Future<void> breached() async {}

  @override
  Future<void> clean() async {}

  @override
  Future<void> failed() async {}
}
