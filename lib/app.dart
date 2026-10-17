import 'package:flutter/material.dart';

import 'app_environment.dart';
import 'core/app_theme.dart';
import 'screens/home_shell.dart';
import 'services/breach_api_service.dart';
import 'services/xposedornot_service.dart';
import 'state/email_check_controller.dart';
import 'state/result_feedback.dart';
import 'state/settings_controller.dart';
import 'state/shake_to_hide.dart';
import 'state/watchlist_controller.dart';
import 'widgets/lock_gate.dart';

/// The root widget. It builds the service and controllers once and owns them
/// for the life of the app.
class BreachCheckerApp extends StatefulWidget {
  /// Pass a [service] to replace the real XposedOrNot client, and an
  /// [environment] to replace the phone's hardware (storage, vibration,
  /// biometrics, accelerometer, browser). This is how the tests run the whole
  /// app without the network or a device.
  const BreachCheckerApp({super.key, this.service, this.environment});

  final BreachApiService? service;
  final AppEnvironment? environment;

  @override
  State<BreachCheckerApp> createState() => _BreachCheckerAppState();
}

class _BreachCheckerAppState extends State<BreachCheckerApp> {
  late final AppEnvironment _environment;
  late final BreachApiService _service;
  late final EmailCheckController _lookup;
  late final SettingsController _settings;
  late final WatchlistController _watchlist;
  late final ResultFeedback _feedback;
  late final ShakeToHide _shakeToHide;

  // initState runs once, when the State is created. Building these here (not
  // in build()) means they aren't re-created on every rebuild.
  @override
  void initState() {
    super.initState();
    _environment = widget.environment ?? AppEnvironment();
    _service = widget.service ?? XposedOrNotService();

    _lookup = EmailCheckController(_service);
    _settings = SettingsController(_environment.store);
    _watchlist = WatchlistController(
      service: _service,
      store: _environment.store,
      pause: _environment.watchlistPause,
    );

    // Two small helpers that react to the controllers: vibrate on a result,
    // and clear the screen on a shake.
    _feedback = ResultFeedback(
      controller: _lookup,
      settings: _settings,
      haptics: _environment.haptics,
    );
    _shakeToHide = ShakeToHide(
      source: _environment.shake,
      settings: _settings,
      onShake: _lookup.wipe,
    );
  }

  @override
  void dispose() {
    _shakeToHide.dispose();
    _feedback.dispose();
    _watchlist.dispose();
    _settings.dispose();
    _lookup.dispose();
    _service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exposr',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: LockGate(
        settings: _settings,
        lock: _environment.lock,
        child: HomeShell(
          controller: _lookup,
          settings: _settings,
          watchlist: _watchlist,
          lock: _environment.lock,
          links: _environment.links,
        ),
      ),
    );
  }
}
