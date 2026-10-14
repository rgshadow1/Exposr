import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'screens/home_shell.dart';
import 'services/breach_api_service.dart';
import 'services/xposedornot_service.dart';
import 'state/email_check_controller.dart';

/// The root widget. It builds the service and controller once and owns them
/// for the life of the app.
class BreachCheckerApp extends StatefulWidget {
  /// Pass a [service] to replace the real XposedOrNot client, which is how the
  /// tests run the whole app without touching the network.
  const BreachCheckerApp({super.key, this.service});

  final BreachApiService? service;

  @override
  State<BreachCheckerApp> createState() => _BreachCheckerAppState();
}

class _BreachCheckerAppState extends State<BreachCheckerApp> {
  late final BreachApiService _service;
  late final EmailCheckController _controller;

  // initState runs once, when the State is created. Building the service here
  // (not in build()) means it isn't re-created on every rebuild.
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? XposedOrNotService();
    _controller = EmailCheckController(_service);
  }

  @override
  void dispose() {
    _controller.dispose();
    _service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exposr',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: HomeShell(controller: _controller),
    );
  }
}
