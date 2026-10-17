import 'package:shared_preferences/shared_preferences.dart';

import 'services/app_lock_service.dart';
import 'services/haptics_service.dart';
import 'services/key_value_store.dart';
import 'services/link_opener.dart';
import 'services/shake_source.dart';

/// Everything in the app that touches the phone itself: storage, vibration,
/// biometrics, the accelerometer and the browser.
///
/// The app is built from one of these. [AppEnvironment.production] wires in the
/// real hardware; a plain `AppEnvironment()` uses inert stand-ins, which is what
/// the tests get unless they pass their own fakes.
class AppEnvironment {
  AppEnvironment({
    KeyValueStore? store,
    HapticsService? haptics,
    AppLockService? lock,
    ShakeSource? shake,
    LinkOpener? links,
    this.watchlistPause = Duration.zero,
  })  : store = store ?? MemoryKeyValueStore(),
        haptics = haptics ?? const NoHapticsService(),
        lock = lock ?? const NoAppLockService(),
        shake = shake ?? const NoShakeSource(),
        links = links ?? const NoLinkOpener();

  factory AppEnvironment.production(SharedPreferences prefs) {
    return AppEnvironment(
      store: SharedPrefsKeyValueStore(prefs),
      haptics: const SystemHapticsService(),
      lock: LocalAuthLockService(),
      shake: const SensorsShakeSource(),
      links: const UrlLauncherLinkOpener(),
      // XposedOrNot allows 2 requests a second; stay comfortably under it.
      watchlistPause: const Duration(milliseconds: 700),
    );
  }

  final KeyValueStore store;
  final HapticsService haptics;
  final AppLockService lock;
  final ShakeSource shake;
  final LinkOpener links;

  /// The gap left between requests when the watchlist is checked all at once.
  final Duration watchlistPause;
}
