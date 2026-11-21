import 'package:breach_checker/app.dart';
import 'package:breach_checker/dev/preview_main.dart';
import 'package:breach_checker/models/breach.dart';
import 'package:breach_checker/models/email_check_result.dart';
import 'package:breach_checker/services/breach_api_service.dart';
import 'package:breach_checker/widgets/app_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lays the whole app out at phone, tablet and desktop sizes, in every state,
/// and fails if anything overflows or throws.
///
/// These tests don't look at wording. They exist to catch a row that no
/// longer fits: Flutter reports an overflow as an error, and an error fails
/// the test.
void main() {
  const sizes = <String, Size>{
    'small phone': Size(320, 568),
    'phone': Size(390, 844),
    'phone on its side': Size(844, 390),
    'tablet': Size(820, 1180),
    'laptop': Size(1280, 720),
    'desktop': Size(1920, 1080),
  };

  /// A very long name, a very long address, and far more breaches than fit.
  const longEmail = 'a.very.long.address.for.testing.layout@a-long-subdomain.example.com';
  final manyNames = [for (final breach in manySampleBreaches) breach.name];

  Future<void> pumpApp(
    WidgetTester tester,
    Size size,
    BreachApiService service, {
    double textScale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(BreachCheckerApp(service: service));
    await tester.pumpAndSettle();
  }

  Future<void> check(WidgetTester tester, String email) async {
    await tester.enterText(find.byType(TextFormField), email);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  /// Taps a destination in whichever navigation the current size shows.
  Future<void> open(WidgetTester tester, String tab) async {
    for (final nav in [AppBottomBar, AppNavRail, AppSidebar]) {
      final item = find.descendant(of: find.byType(nav), matching: find.text(tab));
      if (item.evaluate().isNotEmpty) {
        await tester.tap(item);
        await tester.pumpAndSettle();
        return;
      }
    }
    fail('No navigation item named $tab');
  }

  /// Scrolls the page to the bottom, so everything on it gets built and laid out.
  Future<void> scrollThrough(WidgetTester tester) async {
    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 40; i++) {
      await tester.drag(scrollable, const Offset(0, -600), warnIfMissed: false);
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    group(name, () {
      // Large text is where layouts break first, so every size is also laid
      // out at double the normal text size.
      for (final textScale in [1.0, 2.0]) {
        final suffix = textScale == 1 ? '' : ' at ${textScale}x text';

        testWidgets('the first view fits$suffix', (tester) async {
          await pumpApp(tester, size, _Instant(), textScale: textScale);
          await scrollThrough(tester);

          expect(tester.takeException(), isNull);
        });

        testWidgets('a long list of breaches fits, closed and open$suffix', (tester) async {
          final service = _Instant(names: manyNames, details: manySampleBreaches);
          await pumpApp(tester, size, service, textScale: textScale);

          await check(tester, longEmail);
          expect(find.text('Found in ${manyNames.length} known breaches'), findsOneWidget);
          await scrollThrough(tester);
          expect(tester.takeException(), isNull);

          // Load the details, open the row with the longest name, show them all.
          final load = find.widgetWithText(OutlinedButton, 'Load breach details');
          await tester.ensureVisible(load);
          await tester.pumpAndSettle();
          await tester.tap(load);
          await tester.pumpAndSettle();

          final longest = find.text(manySampleBreaches.first.name);
          await tester.ensureVisible(longest);
          await tester.pumpAndSettle();
          await tester.tap(longest);
          await tester.pumpAndSettle();

          final showAll = find.text('Show all ${manySampleBreaches.length} breaches');
          await tester.ensureVisible(showAll);
          await tester.pumpAndSettle();
          await tester.tap(showAll);
          await tester.pumpAndSettle();
          await scrollThrough(tester);

          expect(find.text('Sample Service 40'), findsOneWidget);
          expect(tester.takeException(), isNull);

          // The same data, as charts.
          await open(tester, 'Insights');
          await scrollThrough(tester);
          expect(find.text('Breaches by year'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('"no known breaches" fits$suffix', (tester) async {
          await pumpApp(tester, size, _Instant(), textScale: textScale);

          await check(tester, longEmail);
          await scrollThrough(tester);

          expect(find.text('No known breaches found'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('every kind of failure fits$suffix', (tester) async {
          for (final failure in BreachApiFailure.values) {
            await pumpApp(tester, size, _Instant(failure: failure), textScale: textScale);

            await check(tester, longEmail);
            await scrollThrough(tester);

            expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
            expect(tester.takeException(), isNull, reason: failure.name);

            // Start the next failure from a fresh app.
            await tester.pumpWidget(const SizedBox.shrink());
          }
        });

        testWidgets('the other tabs fit, empty and in use$suffix', (tester) async {
          final service = _Instant(names: manyNames.take(7).toList());
          await pumpApp(tester, size, service, textScale: textScale);

          await open(tester, 'Insights');
          await scrollThrough(tester);
          expect(tester.takeException(), isNull);

          await open(tester, 'Watchlist');
          await scrollThrough(tester);
          expect(tester.takeException(), isNull);

          // Add an address: its panel shows breaches, a checklist and actions.
          final field = find.byType(TextFormField);
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          await tester.enterText(field, longEmail);
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          final checklist = find.textContaining('What to do');
          await tester.ensureVisible(checklist);
          await tester.pumpAndSettle();
          await tester.tap(checklist);
          await tester.pumpAndSettle();
          await scrollThrough(tester);
          expect(tester.takeException(), isNull);

          await open(tester, 'Settings');
          await scrollThrough(tester);
          expect(find.text('About the developer'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    });
  }
}

/// Answers every request at once, with whatever the test asked for.
class _Instant implements BreachApiService {
  _Instant({this.names = const [], this.details = const [], this.failure});

  final List<String> names;
  final List<Breach> details;
  final BreachApiFailure? failure;

  @override
  Future<EmailCheckResult> checkEmail(String email) async {
    final failure = this.failure;
    if (failure != null) throw BreachApiException(failure);
    return names.isEmpty ? EmailClean(email) : EmailBreached(email, names);
  }

  @override
  Future<List<Breach>> fetchBreachDetails(String email) async => details;

  @override
  void close() {}
}
