import 'package:breach_checker/core/app_info.dart';
import 'package:breach_checker/core/app_theme.dart';
import 'package:breach_checker/screens/settings_screen.dart';
import 'package:breach_checker/services/key_value_store.dart';
import 'package:breach_checker/state/email_check_controller.dart';
import 'package:breach_checker/state/settings_controller.dart';
import 'package:breach_checker/state/watchlist_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_breach_api_service.dart';
import 'support/fakes.dart';

void main() {
  late MemoryKeyValueStore store;
  late SettingsController settings;
  late WatchlistController watchlist;
  late EmailCheckController lookup;
  late FakeAppLockService lock;
  late FakeLinkOpener links;
  late ScriptedBreachApiService service;

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 2400);
    addTearDown(tester.view.reset);

    store = MemoryKeyValueStore();
    service = ScriptedBreachApiService();
    settings = SettingsController(store);
    watchlist = WatchlistController(service: service, store: store);
    lookup = EmailCheckController(FakeBreachApiService());
    lock = FakeAppLockService();
    links = FakeLinkOpener();
    addTearDown(() {
      settings.dispose();
      watchlist.dispose();
      lookup.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SettingsScreen(
            settings: settings,
            watchlist: watchlist,
            lookup: lookup,
            lock: lock,
            links: links,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder switchFor(String title) {
    return find.widgetWithText(SwitchListTile, title);
  }

  bool isOn(WidgetTester tester, String title) {
    return tester.widget<SwitchListTile>(switchFor(title)).value;
  }

  testWidgets('shows every section', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('FEEDBACK'), findsOneWidget);
    expect(find.text('SECURITY'), findsOneWidget);
    expect(find.text('YOUR DATA'), findsOneWidget);
    expect(find.text('ABOUT EXPOSR'), findsOneWidget);
    expect(find.text('About the developer'), findsOneWidget);
    expect(find.text(AppInfo.version), findsOneWidget);
  });

  testWidgets('the vibration and shake switches change the settings', (tester) async {
    await pumpScreen(tester);
    expect(isOn(tester, 'Vibrate on results'), isTrue);
    expect(isOn(tester, 'Shake to hide'), isFalse);

    await tester.tap(switchFor('Vibrate on results'));
    await tester.pump();
    await tester.tap(switchFor('Shake to hide'));
    await tester.pump();

    expect(settings.hapticsEnabled, isFalse);
    expect(settings.shakeToHideEnabled, isTrue);
    expect(isOn(tester, 'Vibrate on results'), isFalse);
    expect(isOn(tester, 'Shake to hide'), isTrue);
  });

  group('app lock', () {
    testWidgets('turns on after the phone confirms it is the owner', (tester) async {
      await pumpScreen(tester);

      await tester.tap(switchFor('App lock'));
      await tester.pumpAndSettle();

      expect(lock.reasons, hasLength(1));
      expect(settings.lockEnabled, isTrue);
    });

    testWidgets('stays off if the confirmation fails', (tester) async {
      await pumpScreen(tester);
      lock.succeeds = false;

      await tester.tap(switchFor('App lock'));
      await tester.pumpAndSettle();

      expect(settings.lockEnabled, isFalse);
      expect(find.text('The app lock wasn’t turned on.'), findsOneWidget);
    });

    testWidgets('turns off without another prompt', (tester) async {
      await pumpScreen(tester);
      await settings.setLockEnabled(true);
      await tester.pump();

      await tester.tap(switchFor('App lock'));
      await tester.pumpAndSettle();

      expect(settings.lockEnabled, isFalse);
      expect(lock.reasons, isEmpty);
    });

    testWidgets('is unavailable, and says why, on a phone with no screen lock', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 2400);
      addTearDown(tester.view.reset);

      final unavailable = FakeAppLockService(available: false);
      final localSettings = SettingsController(MemoryKeyValueStore());
      final localService = ScriptedBreachApiService();
      final localWatchlist = WatchlistController(service: localService, store: MemoryKeyValueStore());
      final localLookup = EmailCheckController(FakeBreachApiService());
      addTearDown(() {
        localSettings.dispose();
        localWatchlist.dispose();
        localLookup.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SettingsScreen(
              settings: localSettings,
              watchlist: localWatchlist,
              lookup: localLookup,
              lock: unavailable,
              links: FakeLinkOpener(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(switchFor('App lock')).onChanged, isNull);
      expect(find.textContaining('Set up a screen lock'), findsOneWidget);
    });
  });

  group('clear all data', () {
    testWidgets('does nothing if cancelled', (tester) async {
      await pumpScreen(tester);
      await settings.setHapticsEnabled(false);
      await tester.pump();

      await tester.tap(find.text('Clear all data'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(settings.hapticsEnabled, isFalse);
    });

    testWidgets('removes the watchlist and resets the settings once confirmed', (tester) async {
      await pumpScreen(tester);
      await watchlist.add('name@example.com');
      await settings.setHapticsEnabled(false);
      await tester.pumpAndSettle();
      expect(watchlist.entries, hasLength(1));

      await tester.tap(find.text('Clear all data'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await tester.pumpAndSettle();

      expect(watchlist.entries, isEmpty);
      expect(settings.hapticsEnabled, isTrue);
      expect(find.text('All data cleared.'), findsOneWidget);
    });
  });

  group('about the developer', () {
    testWidgets('names the developer and links to the website', (tester) async {
      await pumpScreen(tester);

      expect(find.textContaining(AppInfo.developerName), findsOneWidget);
      expect(find.text('Visit ${AppInfo.developerSiteLabel}'), findsOneWidget);
    });

    testWidgets('the button opens mohamedhda.com', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Visit ${AppInfo.developerSiteLabel}'));
      await tester.pumpAndSettle();

      expect(links.opened, [Uri.parse('https://mohamedhda.com')]);
    });

    testWidgets('says so when the link can’t be opened', (tester) async {
      await pumpScreen(tester);
      links.succeeds = false;

      await tester.tap(find.text('Visit ${AppInfo.developerSiteLabel}'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Couldn’t open the link'), findsOneWidget);
    });
  });
}
