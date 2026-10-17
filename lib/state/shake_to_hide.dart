import 'dart:async';

import '../services/shake_source.dart';
import 'settings_controller.dart';

/// Calls [onShake] when the phone is shaken, but only while the setting is on.
///
/// The accelerometer is subscribed to only when the setting is on, and the
/// subscription is dropped as soon as it is switched off.
class ShakeToHide {
  ShakeToHide({
    required this.source,
    required this.settings,
    required this.onShake,
  }) {
    settings.addListener(_sync);
    _sync();
  }

  final ShakeSource source;
  final SettingsController settings;
  final void Function() onShake;

  StreamSubscription<void>? _subscription;

  void _sync() {
    if (settings.shakeToHideEnabled) {
      _subscription ??= source.shakes.listen((_) => onShake());
    } else {
      _subscription?.cancel();
      _subscription = null;
    }
  }

  void dispose() {
    settings.removeListener(_sync);
    _subscription?.cancel();
    _subscription = null;
  }
}
