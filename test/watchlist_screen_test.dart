import 'package:breach_checker/core/app_theme.dart';
import 'package:breach_checker/screens/watchlist_screen.dart';
import 'package:breach_checker/services/breach_api_service.dart';
import 'package:breach_checker/services/key_value_store.dart';
import 'package:breach_checker/state/watchlist_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  late ScriptedBreachApiService service;
  late WatchlistController watchlist;
  final now = DateTime(2026, 10, 15, 12);

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1600);
    addTearDown(tester.view.reset);

    service = ScriptedBreachApiService();
    watchlist = WatchlistController(
      service: service,
      store: MemoryKeyValueStore(),
      clock: () => now,
    );
    addTearDown(watchlist.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: WatchlistScreen(watchlist: watchlist, clock: () => now)),
      ),
    );
  }

  Future<void> addAddress(WidgetTester tester, String email) async {
    await tester.enterText(find.byType(TextFormField), email);
    await tester.tap(find.widgetWithText(FilledButton, 'Add to watchlist'));
    await tester.pumpAndSettle();
  }

  testWidgets('starts empty, with a short explanation', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Watchlist'), findsOneWidget);
    expect(find.text('Nothing on your watchlist'), findsOneWidget);
    expect(find.textContaining('saved on this device only'), findsOneWidget);
  });

  testWidgets('adding a clean address shows it as checked, with no breaches', (tester) async {
    await pumpScreen(tester);

    await addAddress(tester, 'name@example.com');

    expect(watchlist.entries.single.email, 'name@example.com');
    expect(find.text('No breaches'), findsOneWidget);
    expect(find.text('Checked just now'), findsOneWidget);
    expect(find.text('1 of ${WatchlistController.maxEntries} addresses'), findsOneWidget);
    expect(service.checked, ['name@example.com']);
  });

  testWidgets('an address in breaches lists them and offers a checklist', (tester) async {
    await pumpScreen(tester);
    service.breaches['name@example.com'] = ['Adobe', 'LinkedIn'];

    await addAddress(tester, 'name@example.com');

    expect(find.text('2 breaches'), findsOneWidget);
    expect(find.text('Adobe'), findsOneWidget);
    expect(find.text('LinkedIn'), findsOneWidget);
    // 2 password tasks + 3 general ones.
    expect(find.text('What to do (0 of 5 done)'), findsOneWidget);

    await tester.tap(find.text('What to do (0 of 5 done)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turn on two-factor authentication'));
    await tester.pumpAndSettle();

    expect(find.text('What to do (1 of 5 done)'), findsOneWidget);
  });

  testWidgets('a breach that appears later is flagged until acknowledged', (tester) async {
    await pumpScreen(tester);
    service.breaches['name@example.com'] = ['Adobe'];
    await addAddress(tester, 'name@example.com');
    expect(find.textContaining('New since the last check'), findsNothing);

    service.breaches['name@example.com'] = ['Adobe', 'Dropbox'];
    await tester.tap(find.text('Check now'));
    await tester.pumpAndSettle();

    expect(find.text('New since the last check: Dropbox'), findsOneWidget);
    expect(find.text('1 new'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.textContaining('New since the last check'), findsNothing);
    expect(find.text('2 breaches'), findsOneWidget);
  });

  testWidgets('a failed check says why, in words', (tester) async {
    await pumpScreen(tester);
    service.failures['name@example.com'] = BreachApiFailure.noConnection;

    await addAddress(tester, 'name@example.com');

    expect(find.text('Not checked'), findsOneWidget);
    expect(find.textContaining('Couldn’t connect.'), findsOneWidget);
  });

  testWidgets('an invalid address is refused with a message and not checked', (tester) async {
    await pumpScreen(tester);

    await addAddress(tester, 'not-an-email');

    expect(find.text('Enter a valid email address, like name@example.com.'), findsOneWidget);
    expect(service.checked, isEmpty);
  });

  testWidgets('adding the same address twice is refused', (tester) async {
    await pumpScreen(tester);
    await addAddress(tester, 'name@example.com');

    await addAddress(tester, 'NAME@example.com');

    expect(find.text('That address is already on your watchlist.'), findsOneWidget);
    expect(watchlist.entries, hasLength(1));
  });

  testWidgets('"Check all" checks every address', (tester) async {
    await pumpScreen(tester);
    await addAddress(tester, 'one@example.com');
    await addAddress(tester, 'two@example.com');
    service.checked.clear();

    await tester.tap(find.text('Check all'));
    await tester.pumpAndSettle();

    expect(service.checked, ['one@example.com', 'two@example.com']);
  });

  testWidgets('removing an address takes it off the list', (tester) async {
    await pumpScreen(tester);
    await addAddress(tester, 'name@example.com');

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing on your watchlist'), findsOneWidget);
    expect(watchlist.entries, isEmpty);
  });
}
