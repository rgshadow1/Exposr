import 'package:breach_checker/core/app_info.dart';
import 'package:breach_checker/core/app_theme.dart';
import 'package:breach_checker/screens/settings_screen.dart';
import 'package:breach_checker/services/key_value_store.dart';
import 'package:breach_checker/state/email_check_controller.dart';
import 'package:breach_checker/state/result_feedback.dart';
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
  late FakeHapticsService haptics;
  late FakeSoundService sounds;
  late ResultFeedback feedback;
  late FakeAppLockService lock;
  late FakeLinkOpener links;
  late ScriptedBreachApiService service;

  /// [hapticsSupported] false stands in for a desktop or a browser.
  /// [lockAvailable] false stands in for a phone with no screen lock.
  Future<void> pumpScreen(
    WidgetTester tester, {
    bool hapticsSupported = true,
    bool lockAvailable = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 2800);
    addTearDown(tester.view.reset);

    store = MemoryKeyValueStore();
    service = ScriptedBreachApiService();
    settings = SettingsController(store);
    watchlist = WatchlistController(service: service, store: store);
    lookup = EmailCheckController(FakeBreachApiService());
    haptics = FakeHapticsService(supported: hapticsSupported);
    sounds = FakeSoundService();
    feedback = ResultFeedback(
      controller: lookup,
      settings: settings,
      haptics: haptics,
      sounds: sounds,
    );
    lock = FakeAppLockService(available: lockAvailable);
    links = FakeLinkOpener();
    addTearDown(() {
      feedback.dispose();
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
            feedback: feedback,
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

  final previewBreach = find.widgetWithText(OutlinedButton, 'Breaches found');
  final previewClear = find.widgetWithText(OutlinedButton, 'No known breaches');

  bool isEnabled(WidgetTester tester, Finder button) {
    return tester.widget<OutlinedButton>(button).onPressed != null;
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

  group('feedback', () {
    testWidgets('haptics and sounds both start on, as two separate switches', (tester) async {
      await pumpScreen(tester);

      expect(isOn(tester, 'Haptic feedback'), isTrue);
      expect(isOn(tester, 'Result sounds'), isTrue);
      expect(isOn(tester, 'Shake to hide'), isFalse);
    });

    testWidgets('the switches change the settings and save them', (tester) async {
      await pumpScreen(tester);

      await tester.tap(switchFor('Haptic feedback'));
      await tester.pump();
      await tester.tap(switchFor('Result sounds'));
      await tester.pump();
      await tester.tap(switchFor('Shake to hide'));
      await tester.pump();

      expect(settings.hapticsEnabled, isFalse);
      expect(settings.soundsEnabled, isFalse);
      expect(settings.shakeToHideEnabled, isTrue);
      expect(isOn(tester, 'Haptic feedback'), isFalse);
      expect(isOn(tester, 'Result sounds'), isFalse);

      // Saved, so the choice is still there the next time the app opens.
      final reopened = SettingsController(store);
      expect(reopened.hapticsEnabled, isFalse);
      expect(reopened.soundsEnabled, isFalse);
      reopened.dispose();
    });

    testWidgets('turning sounds back on loads them, without playing anything', (tester) async {
      await pumpScreen(tester);
      await tester.tap(switchFor('Result sounds')); // off
      await tester.pump();
      final loaded = sounds.warmUps;

      await tester.tap(switchFor('Result sounds')); // on again
      await tester.pump();

      expect(sounds.warmUps, loaded + 1);
      expect(sounds.played, isEmpty);
    });

    testWidgets('nothing plays just because the screen is shown', (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(haptics.calls, isEmpty);
      expect(sounds.played, isEmpty);
    });

    testWidgets('each preview gives that result’s feedback, haptic and sound by default', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(previewBreach);
      await tester.pump();
      expect(haptics.calls, ['breached']);
      expect(sounds.played, ['breached']);

      await tester.tap(previewClear);
      await tester.pump();
      expect(haptics.calls, ['breached', 'clean']);
      expect(sounds.played, ['breached', 'clean']);
    });

    testWidgets('the previews stay silent once sounds are switched off', (tester) async {
      await pumpScreen(tester);
      await tester.tap(switchFor('Result sounds'));
      await tester.pump();

      await tester.tap(previewBreach);
      await tester.pump();
      await tester.tap(previewClear);
      await tester.pump();

      expect(sounds.played, isEmpty);
      expect(haptics.calls, ['breached', 'clean']);
    });

    testWidgets('the previews are disabled, and say why, when both are off', (tester) async {
      await pumpScreen(tester);

      await tester.tap(switchFor('Haptic feedback'));
      await tester.pump();
      await tester.tap(switchFor('Result sounds'));
      await tester.pump();

      expect(isEnabled(tester, previewBreach), isFalse);
      expect(isEnabled(tester, previewClear), isFalse);
      expect(find.textContaining('Turn on haptic feedback or result sounds'), findsOneWidget);
    });

    testWidgets('on a device without haptics the switch is off, locked and explained', (
      tester,
    ) async {
      await pumpScreen(tester, hapticsSupported: false);

      final tile = tester.widget<SwitchListTile>(switchFor('Haptic feedback'));
      expect(tile.value, isFalse);
      expect(tile.onChanged, isNull);
      expect(find.text('This device doesn’t support haptic feedback.'), findsOneWidget);

      // Sounds still work there, and so do their previews.
      expect(isEnabled(tester, previewBreach), isTrue);
      await tester.tap(previewClear);
      await tester.pump();

      expect(sounds.played, ['clean']);
      expect(haptics.calls, isEmpty);

      // With the sounds off too, there is nothing left to preview.
      await tester.tap(switchFor('Result sounds'));
      await tester.pump();
      expect(isEnabled(tester, previewBreach), isFalse);
    });

    testWidgets('the previews are named for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);

      expect(find.bySemanticsLabel('Preview the feedback for breaches found'), findsOneWidget);
      expect(find.bySemanticsLabel('Preview the feedback for no known breaches'), findsOneWidget);

      handle.dispose();
    });
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
      await pumpScreen(tester, lockAvailable: false);

      expect(tester.widget<SwitchListTile>(switchFor('App lock')).onChanged, isNull);
      expect(find.textContaining('Set up a screen lock'), findsOneWidget);
    });
  });

  group('your data', () {
    testWidgets('says where an address goes and how it is stored', (tester) async {
      await pumpScreen(tester);

      expect(find.textContaining('sent over HTTPS to XposedOrNot and nowhere else'), findsOneWidget);
      expect(find.textContaining('not encrypted'), findsOneWidget);
      expect(find.textContaining('a backup of your device may include it'), findsOneWidget);
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
      await settings.setSoundsEnabled(false);
      await tester.pumpAndSettle();
      expect(watchlist.entries, hasLength(1));

      await tester.tap(find.text('Clear all data'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await tester.pumpAndSettle();

      expect(watchlist.entries, isEmpty);
      expect(settings.hapticsEnabled, isTrue);
      expect(settings.soundsEnabled, isTrue); // back to on
      expect(find.text('All data cleared.'), findsOneWidget);
    });
  });

  group('about', () {
    testWidgets('the breach data row opens the provider’s website', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Breach data'));
      await tester.pumpAndSettle();

      expect(links.opened, [Uri.parse('https://xposedornot.com')]);
    });

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
