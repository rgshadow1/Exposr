import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'app_environment.dart';

Future<void> main() async {
  // Needed before using plugins (storage) ahead of runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // Lists the Inter typeface's licence on the "Open-source licences" page.
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Inter typeface'], text);
  });

  final prefs = await SharedPreferences.getInstance();
  runApp(BreachCheckerApp(environment: AppEnvironment.production(prefs)));
}
