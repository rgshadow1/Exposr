import 'dart:async';

import '../services/haptics_service.dart';
import 'email_check_controller.dart';
import 'settings_controller.dart';

/// Vibrates when a check finishes, if the user has haptics switched on.
///
/// It watches the [EmailCheckController] and reacts only to the moment a
/// running check turns into an outcome. Editing the field (which resets the
/// state) or starting a check does not buzz.
class ResultFeedback {
  ResultFeedback({
    required this.controller,
    required this.settings,
    required this.haptics,
  }) : _previous = controller.state {
    controller.addListener(_onChanged);
  }

  final EmailCheckController controller;
  final SettingsController settings;
  final HapticsService haptics;

  LookupState _previous;

  void _onChanged() {
    final before = _previous;
    final now = controller.state;
    _previous = now;

    if (before is! LookupLoading) return;
    if (!settings.hapticsEnabled) return;

    if (now is LookupBreached) {
      unawaited(haptics.breached());
    } else if (now is LookupClean) {
      unawaited(haptics.clean());
    } else if (now is LookupFailed) {
      unawaited(haptics.failed());
    }
  }

  void dispose() => controller.removeListener(_onChanged);
}
