import 'dart:ui' show Tristate;

import 'package:breach_checker/app.dart';
import 'package:breach_checker/app_environment.dart';
import 'package:breach_checker/core/app_colors.dart';
import 'package:breach_checker/services/breach_api_service.dart';
import 'package:breach_checker/services/key_value_store.dart';
import 'package:breach_checker/widgets/app_navigation.dart';
import 'package:breach_checker/widgets/check_mark.dart';
import 'package:breach_checker/widgets/check_panel.dart';
import 'package:breach_checker/widgets/panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import 'support/fake_breach_api_service.dart';
import 'support/fakes.dart';

/// Widget tests for the Home screen. They drive the UI like a user (type,
/// tap) and check what appears. The network is replaced by a fake service.
void main() {
  late FakeBreachApiService service;

  setUp(() => service = FakeBreachApiService());

  void setScreen(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  /// [environment] swaps in fake hardware (vibration, shake sensor, storage).
  /// Without one, the app gets inert stand-ins.
  Future<void> pumpApp(
    WidgetTester tester, {
    AppEnvironment? environment,
    // A typical phone-sized screen: 390x844 logical pixels at 1x density.
    Size size = const Size(390, 844),
  }) async {
    setScreen(tester, size);
    await tester.pumpWidget(BreachCheckerApp(service: service, environment: environment));
  }

  final checkButton = find.widgetWithText(FilledButton, 'Check for breaches');
  final checkAnother = find.widgetWithText(OutlinedButton, 'Check another address');

  /// The Lottie animation of this file, if it is the one on screen.
  Finder animation(String file) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is LottieBuilder &&
          widget.lottie is AssetLottie &&
          (widget.lottie as AssetLottie).assetName == 'assets/lottie/$file.json',
    );
  }
  final emailField = find.byType(TextFormField);

  Future<void> enterEmailAndTap(WidgetTester tester, String email) async {
    await tester.enterText(emailField, email);
    await tester.ensureVisible(checkButton);
    await tester.tap(checkButton);
    await tester.pump();
  }

  Future<void> tapText(WidgetTester tester, Type buttonType, String label) async {
    final finder = find.widgetWithText(buttonType, label);
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  group('first view', () {
    testWidgets('shows the brand, a direct headline, the form and the navigation', (tester) async {
      await pumpApp(tester);

      expect(find.text('Exposr'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget); // the logo
      // On a phone the heading is on two lines ("Is your email" / "exposed?").
      expect(find.textContaining('exposed?'), findsOneWidget);
      expect(find.textContaining('Is your email'), findsOneWidget);
      expect(find.textContaining('Welcome'), findsNothing);
      expect(checkButton, findsOneWidget);
      expect(find.text('Email address'), findsOneWidget); // the label stays put
      expect(find.text('you@example.com'), findsOneWidget); // the placeholder

      final nav = find.byType(NavigationBar);
      for (final label in ['Home', 'Insights', 'Watchlist', 'Settings']) {
        expect(find.descendant(of: nav, matching: find.text(label)), findsOneWidget);
      }
    });

    testWidgets('the panel carries no small print: that is all behind "How it works"', (
      tester,
    ) async {
      await pumpApp(tester);

      // Nothing about privacy, permission or the provider sits around the
      // button...
      expect(find.textContaining('Sent to XposedOrNot'), findsNothing);
      expect(find.textContaining('Only check addresses you own'), findsNothing);
      expect(find.textContaining('Breach data provided by XposedOrNot'), findsNothing);
      // ...and the panel is just: mark, heading, text, field, button, toggle.
      final panel = find.byType(CheckPanel);
      expect(find.descendant(of: panel, matching: find.byType(TextFormField)), findsOneWidget);
      expect(find.descendant(of: panel, matching: find.byIcon(Icons.lock_outline)), findsNothing);
    });

    testWidgets('"How it works" says where the address goes, whose to check, and credits the provider', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.text('How it works'));
      await tester.pumpAndSettle();

      expect(find.text('Your privacy'), findsOneWidget);
      expect(find.textContaining('sent over HTTPS to XposedOrNot and nowhere else'), findsOneWidget);
      expect(find.textContaining('kept only if you add it to your Watchlist'), findsOneWidget);
      expect(find.text('Whose addresses'), findsOneWidget);
      expect(find.textContaining('Only check addresses you own or have permission to check'), findsOneWidget);
      expect(find.text('Breach data provided by XposedOrNot.'), findsOneWidget);
    });

    testWidgets('the provider is credited once on the whole screen, even with a sidebar', (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(1440, 900));
      await tester.tap(find.text('How it works'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Breach data provided by XposedOrNot'), findsOneWidget);
    });

    testWidgets('the idle mark is the radar sweep, and the panel holds the whole form', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(animation('scan'), findsOneWidget);
      // Mark, heading, text, field and button are all in one panel.
      final panel = find.byType(CheckPanel);
      for (final inside in [
        find.byType(CheckMark),
        find.textContaining('exposed?'),
        emailField,
        checkButton,
      ]) {
        expect(find.descendant(of: panel, matching: inside), findsOneWidget);
      }
    });

    testWidgets('the longer explanations are folded away behind "How it works"', (tester) async {
      await pumpApp(tester);

      expect(find.text('Privacy first'), findsNothing);
      expect(find.text('Breach intelligence'), findsNothing);
      expect(find.text('How it works'), findsOneWidget);
      expect(find.text('What is checked'), findsNothing);

      await tester.tap(find.text('How it works'));
      await tester.pumpAndSettle();

      expect(find.text('What is checked'), findsOneWidget);
      expect(find.text('What it can’t tell you'), findsOneWidget);
      expect(find.text('Your privacy'), findsOneWidget);

      await tester.tap(find.text('How it works'));
      await tester.pumpAndSettle();

      expect(find.text('What is checked'), findsNothing);
    });

    testWidgets('"How it works" is a button that says whether it is open', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester);

      final toggle = find.bySemanticsLabel('How it works');
      expect(tester.getSemantics(toggle).getSemanticsData().flagsCollection.isButton, isTrue);
      expect(
        tester.getSemantics(toggle).getSemanticsData().flagsCollection.isExpanded,
        Tristate.isFalse,
      );

      await tester.tap(find.text('How it works'));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.bySemanticsLabel('How it works')).getSemanticsData().flagsCollection.isExpanded,
        Tristate.isTrue,
      );

      handle.dispose();
    });

    testWidgets('the email field is announced by its label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester);

      final node = tester.getSemantics(find.byType(TextField));
      expect(node.label, contains('Email address'));
      expect(node.getSemanticsData().flagsCollection.isTextField, isTrue);

      handle.dispose();
    });

    testWidgets('the theme uses Inter', (tester) async {
      await pumpApp(tester);

      final theme = Theme.of(tester.element(find.byType(NavigationBar)));
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
      expect(theme.textTheme.titleMedium?.fontFamily, 'Inter');
    });
  });

  group('validation', () {
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

    testWidgets('the error clears as soon as the address becomes valid', (tester) async {
      await pumpApp(tester);
      await enterEmailAndTap(tester, 'not-an-email');
      expect(find.text('Enter a valid email address, like name@example.com.'), findsOneWidget);

      await tester.enterText(emailField, 'name@example.com');
      await tester.pump();

      expect(find.text('Enter a valid email address, like name@example.com.'), findsNothing);
    });
  });

  group('submitting', () {
    testWidgets('Enter in the field submits, just like the button', (tester) async {
      await pumpApp(tester);

      await tester.enterText(emailField, '  name@example.com ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      // Trimmed, and sent once.
      expect(service.checkedEmails, ['name@example.com']);
    });

    testWidgets('a second submit while one is running sends nothing more', (tester) async {
      await pumpApp(tester);

      await enterEmailAndTap(tester, 'name@example.com');
      // The button is disabled, and Enter is ignored too.
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(service.checkedEmails, ['name@example.com']);
    });

    testWidgets('loading says so in the button and under the form', (tester) async {
      await pumpApp(tester);

      await enterEmailAndTap(tester, 'name@example.com');

      expect(find.text('Checking…'), findsOneWidget);
      expect(find.text('Searching known breaches…'), findsOneWidget);
      expect(find.textContaining('Asking XposedOrNot.'), findsOneWidget);
      // The address can't be edited out from under a running check.
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    });

    testWidgets('the same scan animation keeps going, now looping', (tester) async {
      await pumpApp(tester);
      final before = tester.widget<LottieBuilder>(animation('scan')).controller;

      await enterEmailAndTap(tester, 'name@example.com');

      // One animation, not a new one: its mode changes, it doesn't restart as
      // a different widget.
      expect(animation('scan'), findsOneWidget);
      expect(tester.widget<LottieBuilder>(animation('scan')).controller, same(before));
    });

    testWidgets('the looping scan stops while another tab is showing', (tester) async {
      await pumpApp(tester);
      await enterEmailAndTap(tester, 'name@example.com');
      // Let the animation file load, so the loop is really running.
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump();
      }
      final scan = tester.widget<LottieBuilder>(animation('scan')).controller! as AnimationController;
      expect(scan.isAnimating, isTrue);

      final nav = find.byType(NavigationBar);
      await tester.tap(find.descendant(of: nav, matching: find.text('Settings')));
      // A running loop would draw a frame after frame and never let this
      // finish. It finishing means the hidden tab's animation is not drawing.
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(of: nav, matching: find.text('Home')));
      await tester.pump();
      expect(scan.isAnimating, isTrue);
    });

    testWidgets('the mark keeps its size from idle through loading to the verdict', (
      tester,
    ) async {
      await pumpApp(tester);
      final idle = tester.getSize(find.byType(CheckMark));

      await enterEmailAndTap(tester, 'name@example.com');
      expect(tester.getSize(find.byType(CheckMark)), idle);

      service.answerBreached('name@example.com', ['Adobe']);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(CheckMark)), idle);
    });

    testWidgets('the primary action follows the check: ready, running, done', (tester) async {
      await pumpApp(tester);
      expect(checkButton, findsOneWidget);

      await enterEmailAndTap(tester, 'name@example.com');
      expect(find.widgetWithText(FilledButton, 'Checking…'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Checking…')).onPressed, isNull);

      service.answerClean('name@example.com');
      await tester.pumpAndSettle();
      expect(checkButton, findsNothing);
      expect(checkAnother, findsOneWidget);
    });
  });

  group('when there is little height (keyboard open, or a phone on its side)', () {
    testWidgets('a phone shrinks the mark and drops the supporting line so the button stays in view', (
      tester,
    ) async {
      await pumpApp(tester);
      final normal = tester.getSize(find.byType(CheckMark));
      expect(find.textContaining('known data breaches'), findsOneWidget);

      // What the keyboard does to the body: take away the bottom 300px.
      tester.view.physicalSize = const Size(390, 544);
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(CheckMark)).height, lessThan(normal.height));
      expect(find.textContaining('known data breaches'), findsNothing);
      // The field and the button are inside the shortened window.
      expect(tester.getBottomLeft(checkButton).dy, lessThan(544));
      expect(tester.getBottomLeft(emailField).dy, lessThan(544));

      // And it goes back when the keyboard closes.
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(CheckMark)), normal);
      expect(find.textContaining('known data breaches'), findsOneWidget);
    });

    testWidgets('a phone on its side gets the compact panel too', (tester) async {
      await pumpApp(tester, size: const Size(844, 390));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('known data breaches'), findsNothing);
    });

    testWidgets('a desktop window is compact only when it is short', (tester) async {
      await pumpApp(tester, size: const Size(1440, 900));
      final normal = tester.getSize(find.byType(CheckMark));
      expect(find.textContaining('known data breaches'), findsOneWidget);

      tester.view.physicalSize = const Size(1440, 420);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(CheckMark)).height, lessThan(normal.height));

      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(CheckMark)), normal);
    });
  });

  group('breaches found', () {
    testWidgets('lists the breaches and says what to do next', (tester) async {
      await pumpApp(tester);

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerBreached('name@example.com', ['Adobe', 'LinkedIn']);
      await tester.pumpAndSettle();

      expect(find.text('Found in 2 known breaches'), findsOneWidget);
      expect(find.text('Adobe'), findsOneWidget);
      expect(find.text('LinkedIn'), findsOneWidget);
      expect(find.text('RECOMMENDED ACTIONS'), findsOneWidget);
      expect(find.text('Change your password on each affected service'), findsOneWidget);
      expect(find.text('Turn on two-factor authentication'), findsOneWidget);
      // The button becomes the way to start over.
      expect(checkAnother, findsOneWidget);
    });

    testWidgets('the outcome, the count and the address are shown straight away, in the panel', (
      tester,
    ) async {
      await pumpApp(tester);

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerBreached('name@example.com', ['Adobe', 'LinkedIn', 'Dropbox']);
      await tester.pump();

      final panel = find.byType(CheckPanel);
      expect(find.descendant(of: panel, matching: find.text('Found in 3 known breaches')), findsOneWidget);
      expect(find.descendant(of: panel, matching: find.textContaining('name@example.com')), findsWidgets);
    });

    testWidgets('a single breach uses the singular', (tester) async {
      await pumpApp(tester);

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerBreached('name@example.com', ['Adobe']);
      await tester.pumpAndSettle();

      expect(find.text('Found in 1 known breach'), findsOneWidget);
    });

    testWidgets('a match is not described as an active compromise', (tester) async {
      await pumpApp(tester);

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerBreached('name@example.com', ['Adobe']);
      await tester.pumpAndSettle();

      expect(find.textContaining('doesn’t mean anyone is using your accounts'), findsOneWidget);
    });

    testWidgets('the alert animation is the mark, and the page keeps its colour', (tester) async {
      await pumpApp(tester);

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerBreached('name@example.com', ['Adobe']);
      await tester.pumpAndSettle();

      expect(animation('alert'), findsOneWidget);
      expect(animation('scan'), findsNothing);

      // Red marks the exposure and nothing else: the page keeps its normal
      // background and no panel is flooded with colour.
      expect(find.byKey(const Key('page-background')), findsNothing);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(
        scaffold.backgroundColor ?? Theme.of(tester.element(emailField)).scaffoldBackgroundColor,
        AppColors.background,
      );
      expect(
        find.byWidgetPredicate((widget) => widget is Panel && widget.tone == AppColors.danger),
        findsNothing,
      );
    });

    testWidgets('details load on request and each breach opens to show more', (tester) async {
      await pumpApp(tester);

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerBreached('name@example.com', ['Adobe']);
      await tester.pumpAndSettle();

      await tapText(tester, OutlinedButton, 'Load breach details');
      expect(find.text('Loading details…'), findsOneWidget);

      service.answerDetails([sampleBreach]);
      await tester.pumpAndSettle();

      // The essentials are visible without opening the row.
      expect(find.text('Adobe'), findsOneWidget);
      expect(find.textContaining('Breached 2013'), findsOneWidget);
      expect(find.textContaining('152,445,165 records'), findsOneWidget);
      expect(find.text('Email addresses'), findsOneWidget);
      expect(find.text('Passwords'), findsOneWidget);
      expect(service.detailEmails, ['name@example.com']);

      // The longer details are behind the row.
      expect(find.text('Customer records were exposed in a 2013 breach.'), findsNothing);
      await tester.ensureVisible(find.text('Adobe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adobe'));
      await tester.pumpAndSettle();

      expect(find.text('Customer records were exposed in a 2013 breach.'), findsOneWidget);
      expect(find.text('Breach year'), findsOneWidget);
      expect(find.text('Easy to crack'), findsOneWidget);
      expect(find.text('adobe.com'), findsOneWidget);
    });

    testWidgets('the year is labelled as the breach year, not a disclosure date', (tester) async {
      await pumpApp(tester);

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerBreached('name@example.com', ['Adobe']);
      await tester.pumpAndSettle();
      await tapText(tester, OutlinedButton, 'Load breach details');
      service.answerDetails([sampleBreach]);
      await tester.pumpAndSettle();

      expect(find.textContaining('The year is when each breach happened'), findsOneWidget);
      expect(find.textContaining('doesn’t say when a breach was disclosed'), findsOneWidget);
    });

    testWidgets('a failed details request keeps the result and can be retried', (tester) async {
      await pumpApp(tester);

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerBreached('name@example.com', ['Adobe']);
      await tester.pumpAndSettle();
      await tapText(tester, OutlinedButton, 'Load breach details');
      service.failDetails(BreachApiFailure.rateLimited);
      await tester.pumpAndSettle();

      expect(find.text('Found in 1 known breach'), findsOneWidget);
      expect(find.textContaining('The details didn’t load.'), findsOneWidget);

      await tapText(tester, OutlinedButton, 'Try again');
      expect(service.detailEmails, ['name@example.com', 'name@example.com']);
    });

    testWidgets('a long list starts short and can be opened in full', (tester) async {
      await pumpApp(tester);
      final names = [for (var i = 1; i <= 30; i++) 'Breach $i'];

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerBreached('name@example.com', names);
      await tester.pumpAndSettle();

      expect(find.text('Found in 30 known breaches'), findsOneWidget);
      expect(find.text('Breach 1'), findsOneWidget);
      expect(find.text('Breach 30'), findsNothing);

      await tapText(tester, TextButton, 'Show all 30 breaches');
      await tester.pumpAndSettle();

      expect(find.text('Breach 30'), findsOneWidget);
    });
  });

  group('no breaches found', () {
    testWidgets('says so without promising the address is safe', (tester) async {
      await pumpApp(tester);

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerClean('name@example.com');
      await tester.pumpAndSettle();

      expect(find.text('No known breaches found'), findsOneWidget);
      expect(find.textContaining('not a guarantee'), findsOneWidget);
      expect(find.textContaining(RegExp(r'you’re safe|is secure|is safe', caseSensitive: false)), findsNothing);
      // Said with a picture as well as words: the success animation.
      expect(animation('success'), findsOneWidget);
      expect(find.textContaining('Found in'), findsNothing);
    });
  });

  group('failed checks', () {
    const titles = {
      BreachApiFailure.noConnection: 'Couldn’t connect',
      BreachApiFailure.timeout: 'Request timed out',
      BreachApiFailure.rateLimited: 'Too many checks',
      BreachApiFailure.serverError: 'Service unavailable',
      BreachApiFailure.unexpectedResponse: 'Unexpected response',
    };

    for (final MapEntry(key: failure, value: title) in titles.entries) {
      testWidgets('${failure.name} is explained, offers a retry, and is never a clean result', (
        tester,
      ) async {
        await pumpApp(tester);

        await enterEmailAndTap(tester, 'name@example.com');
        service.failCheck(failure);
        await tester.pumpAndSettle();

        expect(find.text(title), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
        expect(find.textContaining('The check didn’t finish.'), findsOneWidget);
        // Not an animation that could be taken for a result.
        expect(animation('alert'), findsNothing);
        expect(animation('success'), findsNothing);
        expect(find.text('No known breaches found'), findsNothing);
        expect(find.textContaining('Found in'), findsNothing);
      });
    }

    testWidgets('a rate-limit error can be retried, and the retry can succeed', (tester) async {
      await pumpApp(tester);

      await enterEmailAndTap(tester, 'name@example.com');
      service.failCheck(BreachApiFailure.rateLimited);
      await tester.pumpAndSettle();

      await tapText(tester, FilledButton, 'Try again');
      // One retry, made by the user. Nothing is retried automatically.
      expect(service.checkedEmails, ['name@example.com', 'name@example.com']);

      service.answerClean('name@example.com');
      await tester.pumpAndSettle();
      expect(find.text('No known breaches found'), findsOneWidget);
    });
  });

  group('moving on from a result', () {
    testWidgets('editing the email clears a stale result', (tester) async {
      await pumpApp(tester);

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerClean('name@example.com');
      await tester.pumpAndSettle();
      expect(find.text('No known breaches found'), findsOneWidget);

      await tester.enterText(emailField, 'other@example.com');
      await tester.pumpAndSettle();

      expect(find.text('No known breaches found'), findsNothing);
    });

    testWidgets('"Check another address" clears the result and the field', (tester) async {
      await pumpApp(tester);

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerBreached('name@example.com', ['Adobe']);
      await tester.pumpAndSettle();

      await tapText(tester, OutlinedButton, 'Check another address');
      await tester.pumpAndSettle();

      expect(find.textContaining('Found in'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    });

    testWidgets('a reply for an address the user has moved on from is ignored', (tester) async {
      await pumpApp(tester);

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerBreached('name@example.com', ['Adobe']);
      await tester.pumpAndSettle();
      await tapText(tester, OutlinedButton, 'Load breach details');

      // The user starts over before the details arrive...
      await tapText(tester, OutlinedButton, 'Check another address');
      await tester.pumpAndSettle();
      // ...and then the old reply turns up.
      service.answerDetails([sampleBreach]);
      await tester.pumpAndSettle();

      expect(find.text('Adobe'), findsNothing);
      expect(find.textContaining('Found in'), findsNothing);
    });
  });

  group('navigation', () {
    testWidgets('on a phone, the bottom bar switches tabs and Home keeps the typed text', (
      tester,
    ) async {
      await pumpApp(tester);
      final nav = find.byType(NavigationBar);

      await tester.enterText(emailField, 'keep@example.com');

      await tester.tap(find.descendant(of: nav, matching: find.text('Insights')));
      await tester.pumpAndSettle();
      expect(find.text('No insights yet'), findsOneWidget);

      await tester.tap(find.descendant(of: nav, matching: find.text('Watchlist')));
      await tester.pumpAndSettle();
      expect(find.text('Nothing on your watchlist'), findsOneWidget);

      await tester.tap(find.descendant(of: nav, matching: find.text('Settings')));
      await tester.pumpAndSettle();
      expect(find.text('About the developer'), findsOneWidget);

      await tester.tap(find.descendant(of: nav, matching: find.text('Home')));
      await tester.pumpAndSettle();
      expect(find.text('keep@example.com'), findsOneWidget);
    });

    testWidgets('on a tablet, a rail replaces the bottom bar', (tester) async {
      await pumpApp(tester, size: const Size(820, 1180));

      expect(find.byType(NavigationBar), findsNothing);
      for (final label in ['Home', 'Insights', 'Watchlist', 'Settings']) {
        expect(find.text(label), findsOneWidget);
      }

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('About the developer'), findsOneWidget);
    });

    testWidgets('on a desktop, a sidebar replaces the bottom bar', (tester) async {
      await pumpApp(tester, size: const Size(1440, 900));

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Exposr'), findsOneWidget);

      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();
      expect(find.text('No insights yet'), findsOneWidget);
    });

    testWidgets('the current tab is marked as selected for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, size: const Size(1440, 900));

      bool isSelected(String label) {
        // Within the sidebar: the Watchlist page has a title of the same name.
        final item = find.descendant(of: find.byType(AppSidebar), matching: find.text(label));
        return tester.getSemantics(item).getSemanticsData().flagsCollection.isSelected ==
            Tristate.isTrue;
      }

      expect(isSelected('Home'), isTrue);
      expect(isSelected('Watchlist'), isFalse);

      await tester.tap(find.text('Watchlist'));
      await tester.pumpAndSettle();

      expect(isSelected('Home'), isFalse);
      expect(isSelected('Watchlist'), isTrue);

      handle.dispose();
    });

    testWidgets('the tabs can be reached and opened from the keyboard', (tester) async {
      await pumpApp(tester, size: const Size(1440, 900));

      // Tab moves through the sidebar first: Home, then Insights.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('No insights yet'), findsOneWidget);
    });

    testWidgets('resizing the window keeps the typed address and the result', (tester) async {
      await pumpApp(tester);

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerBreached('name@example.com', ['Adobe']);
      await tester.pumpAndSettle();

      for (final size in const [Size(820, 1180), Size(1440, 900), Size(390, 844)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();

        expect(find.text('name@example.com'), findsOneWidget, reason: 'the field at $size');
        expect(find.text('Found in 1 known breach'), findsOneWidget, reason: 'the result at $size');
      }
      // Nothing was sent again just because the layout changed.
      expect(service.checkedEmails, ['name@example.com']);
    });
  });

  group('reduced motion', () {
    testWidgets('no spinner turns while a check runs', (tester) async {
      setScreen(tester, const Size(390, 844));
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(BreachCheckerApp(service: service));

      await enterEmailAndTap(tester, 'name@example.com');

      // The words still say what is happening.
      expect(find.text('Checking…'), findsOneWidget);
      expect(find.text('Searching known breaches…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('result feedback', () {
    late FakeHapticsService haptics;
    late FakeSoundService sounds;

    /// The app with fake haptics and sound, and sounds switched on or off.
    Future<void> pumpWithFeedback(
      WidgetTester tester, {
      bool soundsOn = false,
      bool hapticsOn = true,
      FakeShakeSource? shake,
    }) async {
      final store = MemoryKeyValueStore();
      await store.setBool('settings.sounds', soundsOn);
      await store.setBool('settings.haptics', hapticsOn);
      await store.setBool('settings.shakeToHide', shake != null);
      haptics = FakeHapticsService();
      sounds = FakeSoundService();
      await pumpApp(
        tester,
        environment: AppEnvironment(
          store: store,
          haptics: haptics,
          sounds: sounds,
          shake: shake,
        ),
      );
    }

    testWidgets('breaches found: a warning haptic, and silence unless sounds are on', (
      tester,
    ) async {
      await pumpWithFeedback(tester);

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerBreached('name@example.com', ['Adobe']);
      await tester.pumpAndSettle();

      expect(haptics.calls, ['breached']);
      expect(sounds.played, isEmpty);
    });

    testWidgets('no known breaches: a success haptic', (tester) async {
      await pumpWithFeedback(tester);

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerClean('name@example.com');
      await tester.pumpAndSettle();

      expect(haptics.calls, ['clean']);
    });

    testWidgets('with sounds on, each result also plays its sound', (tester) async {
      await pumpWithFeedback(tester, soundsOn: true);

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerBreached('name@example.com', ['Adobe']);
      await tester.pumpAndSettle();

      expect(sounds.played, ['breached']);
      expect(haptics.calls, ['breached']);
    });

    testWidgets('the feedback arrives with the result, not after it', (tester) async {
      await pumpWithFeedback(tester, soundsOn: true);

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerClean('name@example.com');
      // One frame, with no time allowed to pass.
      await tester.pump();

      expect(find.text('No known breaches found'), findsOneWidget);
      expect(haptics.calls, ['clean']);
      expect(sounds.played, ['clean']);
    });

    testWidgets('a failed check shows an error and gives no feedback at all', (tester) async {
      await pumpWithFeedback(tester, soundsOn: true);

      await enterEmailAndTap(tester, 'name@example.com');
      service.failCheck(BreachApiFailure.timeout);
      await tester.pumpAndSettle();

      expect(find.text('Request timed out'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
      expect(haptics.calls, isEmpty);
      expect(sounds.played, isEmpty);
    });

    testWidgets('stays still and silent when both are turned off in settings', (tester) async {
      await pumpWithFeedback(tester, hapticsOn: false);

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerBreached('name@example.com', ['Adobe']);
      await tester.pumpAndSettle();

      expect(haptics.calls, isEmpty);
      expect(sounds.played, isEmpty);
    });

    testWidgets('it is not replayed by navigating, resizing, or opening details', (tester) async {
      await pumpWithFeedback(tester, soundsOn: true);

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerBreached('name@example.com', ['Adobe']);
      await tester.pumpAndSettle();

      // Away to another tab and back again.
      final nav = find.byType(NavigationBar);
      await tester.tap(find.descendant(of: nav, matching: find.text('Insights')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: nav, matching: find.text('Home')));
      await tester.pumpAndSettle();

      // The window changes shape, which rebuilds everything.
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();

      // The details load.
      await tapText(tester, OutlinedButton, 'Load breach details');
      service.answerDetails([sampleBreach]);
      await tester.pumpAndSettle();

      expect(find.text('Found in 1 known breach'), findsOneWidget);
      expect(haptics.calls, ['breached']);
      expect(sounds.played, ['breached']);
    });

    testWidgets('a reply to a check that was cleared mid-flight gives no feedback', (
      tester,
    ) async {
      final shake = FakeShakeSource();
      await pumpWithFeedback(tester, soundsOn: true, shake: shake);

      await enterEmailAndTap(tester, 'name@example.com');
      // "Shake to hide" clears the screen while the request is still out...
      shake.shake();
      await tester.pumpAndSettle();
      // ...and then its reply turns up.
      service.answerBreached('name@example.com', ['Adobe']);
      await tester.pumpAndSettle();

      expect(find.textContaining('Found in'), findsNothing);
      expect(haptics.calls, isEmpty);
      expect(sounds.played, isEmpty);
    });
  });

  group('phone features', () {

    testWidgets('shake to hide clears the typed address and the results', (tester) async {
      final store = MemoryKeyValueStore();
      await store.setBool('settings.shakeToHide', true);
      final shake = FakeShakeSource();
      await pumpApp(tester, environment: AppEnvironment(store: store, shake: shake));

      await enterEmailAndTap(tester, 'name@example.com');
      service.answerBreached('name@example.com', ['Adobe']);
      await tester.pumpAndSettle();
      expect(find.text('Found in 1 known breach'), findsOneWidget);

      shake.shake();
      await tester.pumpAndSettle();

      expect(find.text('Found in 1 known breach'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    });

    testWidgets('a shake does nothing while the setting is off', (tester) async {
      final shake = FakeShakeSource();
      await pumpApp(tester, environment: AppEnvironment(shake: shake));

      await tester.enterText(emailField, 'name@example.com');
      shake.shake();
      await tester.pumpAndSettle();

      expect(find.text('name@example.com'), findsOneWidget);
    });
  });
}
