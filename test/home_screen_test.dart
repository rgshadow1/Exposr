import 'package:breach_checker/app.dart';
import 'package:breach_checker/core/page_backdrop.dart';
import 'package:breach_checker/services/breach_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_breach_api_service.dart';

/// Widget tests for the Home screen. They drive the UI like a user (type,
/// tap) and check what appears. The network is replaced by a fake service.
void main() {
  late FakeBreachApiService service;

  setUp(() => service = FakeBreachApiService());

  Future<void> pumpApp(WidgetTester tester) async {
    // A typical phone-sized screen: 390x844 logical pixels at 1x density.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(BreachCheckerApp(service: service));
  }

  final checkButton = find.widgetWithText(FilledButton, 'Check Email');

  Future<void> enterEmailAndTap(WidgetTester tester, String email) async {
    await tester.enterText(find.byType(TextFormField), email);
    await tester.ensureVisible(checkButton);
    await tester.tap(checkButton);
    await tester.pump();
  }

  Future<void> tapText(WidgetTester tester, Type buttonType, String label) async {
    final finder = find.widgetWithText(buttonType, label);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  testWidgets('shows the header, welcome text, check card and feature cards', (tester) async {
    await pumpApp(tester);

    expect(find.text('Exposr'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget); // the logo
    expect(find.textContaining('Welcome'), findsOneWidget);
    expect(checkButton, findsOneWidget);
    expect(find.text('Privacy first'), findsOneWidget);
    expect(find.text('Breach intelligence'), findsOneWidget);
    expect(find.textContaining('sent over HTTPS to XposedOrNot'), findsOneWidget);

    final nav = find.byType(NavigationBar);
    for (final label in ['Home', 'History', 'Settings']) {
      expect(find.descendant(of: nav, matching: find.text(label)), findsOneWidget);
    }
  });

  testWidgets('the header and the welcome heading are centred', (tester) async {
    await pumpApp(tester);

    const screenCentre = 390 / 2;

    // Header: the middle of the logo-and-name pair sits on the screen's middle.
    final left = tester.getTopLeft(find.byType(Image)).dx;
    final right = tester.getTopRight(find.text('Exposr')).dx;
    expect((left + right) / 2, closeTo(screenCentre, 1));

    // Welcome heading: its text box is centred and aligned to the centre.
    final welcome = tester.widget<Text>(find.textContaining('Welcome'));
    expect(welcome.textAlign, TextAlign.center);
    expect(tester.getCenter(find.textContaining('Welcome')).dx, closeTo(screenCentre, 1));
  });

  group('background tint', () {
    LinearGradient backdrop(WidgetTester tester) {
      final box = tester.widget<AnimatedContainer>(find.byKey(const Key('page-background')));
      return (box.decoration! as BoxDecoration).gradient! as LinearGradient;
    }

    testWidgets('is neutral before any result', (tester) async {
      await pumpApp(tester);

      expect(backdrop(tester).colors, [PageBackdrop.neutral.top, PageBackdrop.neutral.bottom]);
    });

    testWidgets('turns dark red when breaches are found', (tester) async {
      await pumpApp(tester);

      await enterEmailAndTap(tester, 'name@example.com');
      // Still checking: no verdict yet, so the page stays neutral.
      expect(backdrop(tester).colors.first, PageBackdrop.neutral.top);

      service.answerBreached('name@example.com', ['Adobe']);
      await tester.pumpAndSettle();

      expect(backdrop(tester).colors, [PageBackdrop.breached.top, PageBackdrop.breached.bottom]);
    });

    testWidgets('turns green when nothing is found', (tester) async {
      await pumpApp(tester);

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerClean('name@example.com');
      await tester.pumpAndSettle();

      expect(backdrop(tester).colors, [PageBackdrop.clean.top, PageBackdrop.clean.bottom]);
    });

    testWidgets('stays neutral when the check fails', (tester) async {
      await pumpApp(tester);

      await enterEmailAndTap(tester, 'name@example.com');
      service.failCheck(BreachApiFailure.noConnection);
      await tester.pumpAndSettle();

      expect(backdrop(tester).colors.first, PageBackdrop.neutral.top);
    });

    testWidgets('returns to neutral when the email is edited', (tester) async {
      await pumpApp(tester);

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerBreached('name@example.com', ['Adobe']);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'other@example.com');
      await tester.pumpAndSettle();

      expect(backdrop(tester).colors.first, PageBackdrop.neutral.top);
    });

    testWidgets('only tints the Home tab', (tester) async {
      await pumpApp(tester);

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerBreached('name@example.com', ['Adobe']);
      await tester.pumpAndSettle();

      final nav = find.byType(NavigationBar);
      await tester.tap(find.descendant(of: nav, matching: find.text('Settings')));
      await tester.pumpAndSettle();

      expect(backdrop(tester).colors.first, PageBackdrop.neutral.top);
    });

    testWidgets('changes instantly when the system turns animations off', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await tester.pumpWidget(BreachCheckerApp(service: service));

      final box = tester.widget<AnimatedContainer>(find.byKey(const Key('page-background')));
      expect(box.duration, Duration.zero);
    });
  });

  testWidgets('the theme uses Inter', (tester) async {
    await pumpApp(tester);

    final theme = Theme.of(tester.element(find.byType(NavigationBar)));
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
    expect(theme.textTheme.titleMedium?.fontFamily, 'Inter');
  });

  testWidgets('an invalid email shows an error and sends nothing', (tester) async {
    await pumpApp(tester);

    await enterEmailAndTap(tester, 'not-an-email');

    expect(find.text('Enter a valid email address, like name@example.com.'), findsOneWidget);
    expect(service.checkedEmails, isEmpty);
  });

  testWidgets('an empty field asks for an email address', (tester) async {
    await pumpApp(tester);

    await tester.ensureVisible(checkButton);
    await tester.tap(checkButton);
    await tester.pump();

    expect(find.text('Enter an email address.'), findsOneWidget);
    expect(service.checkedEmails, isEmpty);
  });

  testWidgets('loading, then the breaches that were found', (tester) async {
    await pumpApp(tester);

    await enterEmailAndTap(tester, 'name@example.com');

    // Loading: the label changes and the button can't be tapped again.
    expect(find.text('Checking…'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(service.checkedEmails, ['name@example.com']);

    service.answerBreached('name@example.com', ['Adobe', 'LinkedIn']);
    await tester.pumpAndSettle();

    expect(find.text('Found in 2 breaches'), findsOneWidget);
    expect(find.text('Adobe'), findsOneWidget);
    expect(find.text('LinkedIn'), findsOneWidget);
    expect(checkButton, findsOneWidget); // button is back to normal
  });

  testWidgets('a single breach uses the singular', (tester) async {
    await pumpApp(tester);

    await enterEmailAndTap(tester, 'name@example.com');
    service.answerBreached('name@example.com', ['Adobe']);
    await tester.pumpAndSettle();

    expect(find.text('Found in 1 breach'), findsOneWidget);
  });

  testWidgets('no breaches found says so without overclaiming', (tester) async {
    await pumpApp(tester);

    await enterEmailAndTap(tester, 'name@example.com');
    service.answerClean('name@example.com');
    await tester.pumpAndSettle();

    expect(find.text('No breaches found'), findsOneWidget);
    expect(find.textContaining('not a guarantee'), findsOneWidget);
  });

  testWidgets('"Show details" loads and shows each breach', (tester) async {
    await pumpApp(tester);

    await enterEmailAndTap(tester, 'name@example.com');
    service.answerBreached('name@example.com', ['Adobe']);
    await tester.pumpAndSettle();

    await tapText(tester, OutlinedButton, 'Show details');
    expect(find.text('Loading details…'), findsOneWidget);

    service.answerDetails([sampleBreach]);
    await tester.pumpAndSettle();

    expect(find.text('Adobe'), findsOneWidget); // now a tile, not a chip
    expect(find.textContaining('152,445,165 records'), findsOneWidget);
    expect(find.text('Passwords'), findsOneWidget);
    expect(find.text('Passwords easy to crack'), findsOneWidget);
    expect(service.detailEmails, ['name@example.com']);
  });

  testWidgets('a rate-limit error is explained and can be retried', (tester) async {
    await pumpApp(tester);

    await enterEmailAndTap(tester, 'name@example.com');
    service.failCheck(BreachApiFailure.rateLimited);
    await tester.pumpAndSettle();

    expect(find.text('Too many checks'), findsOneWidget);

    await tapText(tester, OutlinedButton, 'Try again');
    expect(service.checkedEmails, ['name@example.com', 'name@example.com']);

    service.answerClean('name@example.com');
    await tester.pumpAndSettle();
    expect(find.text('No breaches found'), findsOneWidget);
  });

  testWidgets('a connection error is explained', (tester) async {
    await pumpApp(tester);

    await enterEmailAndTap(tester, 'name@example.com');
    service.failCheck(BreachApiFailure.noConnection);
    await tester.pumpAndSettle();

    expect(find.text('Couldn’t connect'), findsOneWidget);
  });

  testWidgets('editing the email clears a stale result', (tester) async {
    await pumpApp(tester);

    await enterEmailAndTap(tester, 'name@example.com');
    service.answerClean('name@example.com');
    await tester.pumpAndSettle();
    expect(find.text('No breaches found'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'other@example.com');
    await tester.pumpAndSettle();

    expect(find.text('No breaches found'), findsNothing);
  });

  testWidgets('bottom navigation switches tabs and keeps typed text', (tester) async {
    await pumpApp(tester);
    final nav = find.byType(NavigationBar);

    await tester.enterText(find.byType(TextFormField), 'keep@example.com');

    await tester.tap(find.descendant(of: nav, matching: find.text('History')));
    await tester.pumpAndSettle();
    expect(find.textContaining('placeholder'), findsOneWidget);

    await tester.tap(find.descendant(of: nav, matching: find.text('Home')));
    await tester.pumpAndSettle();
    expect(find.text('keep@example.com'), findsOneWidget);
  });
}
