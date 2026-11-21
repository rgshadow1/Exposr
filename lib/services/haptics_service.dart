import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Haptic feedback for the two results a check can end in.
///
/// There is deliberately nothing here for a failed check: a failure is shown
/// on screen, with a way to retry, and never feels like a result.
///
/// An interface, so tests can swap in a fake that records which one was asked
/// for. (The decision to give feedback is testable; the buzz itself is not.)
abstract interface class HapticsService {
  /// Whether this device can give these haptics at all. False on desktop and
  /// on the web, where the calls below do nothing.
  bool get isSupported;

  /// Breaches were found: one brief, noticeable warning.
  Future<void> breached();

  /// No known breaches were found: the platform's light "success".
  Future<void> clean();
}

/// Uses the phone's own haptic engine through Flutter's built-in
/// [HapticFeedback], so no extra package and no vibration permission is needed.
///
/// These are the platform's standard, named haptics rather than hand-made
/// vibration patterns, which has two consequences worth knowing:
///
///  * The system decides whether they play. Both iOS ("System Haptics") and
///    Android ("Touch feedback") let people turn haptics off, and both mute
///    them in some modes. This class never overrides that.
///  * What they feel like is the platform's choice:
///
///    | Result  | iOS                                   | Android                         |
///    |---------|---------------------------------------|---------------------------------|
///    | Clear   | notification "success" (two light taps) | `CONFIRM` (Android 11 and later) |
///    | Breach  | notification "warning"                | `CONTEXT_CLICK` (one firm click) |
///
///    Android has no named warning haptic of its own. Flutter's
///    `warningNotification` maps to a keyboard tap there, which is too faint
///    to notice, so a single firm click is used instead. On Android 10 and
///    earlier `CONFIRM` does not exist and a clear result gives no haptic.
///
/// Errors are swallowed: a device without a haptic engine should simply not
/// respond, never crash or hold up a result.
class SystemHapticsService implements HapticsService {
  const SystemHapticsService();

  @override
  bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  Future<void> breached() async {
    if (!isSupported) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await HapticFeedback.warningNotification();
      } else {
        await HapticFeedback.heavyImpact();
      }
    } catch (_) {}
  }

  @override
  Future<void> clean() async {
    if (!isSupported) return;
    try {
      await HapticFeedback.successNotification();
    } catch (_) {}
  }
}

/// Does nothing, and says it can't. The default in tests, and what a device
/// without haptics amounts to.
class NoHapticsService implements HapticsService {
  const NoHapticsService();

  @override
  bool get isSupported => false;

  @override
  Future<void> breached() async {}

  @override
  Future<void> clean() async {}
}
