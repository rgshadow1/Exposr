import 'dart:async';

import '../services/haptics_service.dart';
import '../services/sound_service.dart';
import 'email_check_controller.dart';
import 'settings_controller.dart';

/// Gives the sound and haptic feedback for a finished check.
///
/// It listens to [EmailCheckController.completions], which fires once each
/// time a check the user started is accepted as the result on screen. That is
/// the only trigger, so feedback is given exactly once per completed check
/// and can't be replayed by anything else:
///
///  * rebuilding or resizing the screen, or switching tabs, emits nothing;
///  * loading a result's details, or clearing it, emits nothing;
///  * a reply to a check the user has moved on from is discarded by the
///    controller before it gets here;
///  * Watchlist checks don't go through that controller at all.
///
/// What it does with each outcome:
///
///  * breaches found: a brief warning haptic and, unless switched off, the "low honor" sound;
///  * no known breaches: a light success haptic and, unless switched off, the "high honor" sound;
///  * failed: nothing. A failure is never dressed up as a result.
///
/// Feedback is fired and forgotten: it is never awaited, so it lands with the
/// result rather than after it, and a device that can't vibrate or play
/// sound can't hold a result up or break it.
class ResultFeedback {
  ResultFeedback({
    required this.controller,
    required this.settings,
    required this.haptics,
    required this.sounds,
  }) {
    _completions = controller.completions.listen(give);
    settings.addListener(_prepareSounds);
    _prepareSounds();
  }

  final EmailCheckController controller;
  final SettingsController settings;
  final HapticsService haptics;
  final SoundService sounds;

  late final StreamSubscription<CheckOutcome> _completions;

  /// Whether this device can give result haptics. The Settings screen uses
  /// this to explain a switch that would do nothing.
  bool get hapticsSupported => haptics.isSupported;

  /// True when haptics are both wanted and possible.
  bool get hapticsActive => settings.hapticsEnabled && haptics.isSupported;

  /// True when at least one kind of feedback would be given for a result.
  bool get isActive => hapticsActive || settings.soundsEnabled;

  /// Gives the feedback for [outcome], following the user's settings.
  ///
  /// Called for each completed check, and by the previews in Settings, which
  /// is why a preview always matches what a real result will do.
  void give(CheckOutcome outcome) {
    switch (outcome) {
      case CheckOutcome.breached:
        if (hapticsActive) _fire(haptics.breached);
        if (settings.soundsEnabled) _fire(sounds.breached);
      case CheckOutcome.clean:
        if (hapticsActive) _fire(haptics.clean);
        if (settings.soundsEnabled) _fire(sounds.clean);
      case CheckOutcome.failed:
        // Deliberately nothing: no sound, no haptic, and never the "clean" ones.
        break;
    }
  }

  /// Load the sounds as soon as they are switched on, so the first one isn't late.
  void _prepareSounds() {
    if (settings.soundsEnabled) _fire(sounds.warmUp);
  }

  /// Starts [action] without waiting for it, and ignores any way it can fail.
  static void _fire(Future<void> Function() action) {
    try {
      unawaited(action().catchError((Object _) {}));
    } catch (_) {
      // Thrown before a future was even returned: equally ignored.
    }
  }

  void dispose() {
    settings.removeListener(_prepareSounds);
    unawaited(_completions.cancel());
  }
}
