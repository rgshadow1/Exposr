import 'package:breach_checker/app.dart';
import 'package:breach_checker/services/breach_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_breach_api_service.dart';
import 'support/fonts.dart';

/// The check panel must not move what is under it when the check changes
/// state: someone about to press the button shouldn't see it jump away.
///
/// These run with the real Inter font, because where text wraps is the whole
/// question. They check the Y position of the field and of the button in every
/// state, on the phone widths in use.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadInter();
  });

  const phoneWidths = [320.0, 360.0, 375.0, 390.0, 412.0, 430.0];
  const desktop = 1440.0;

  Future<void> pump(WidgetTester tester, FakeBreachApiService service, double width) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, width >= 600 ? 900 : 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(BreachCheckerApp(service: service));
    await tester.pump();
  }

  /// Where the field and the button are, in the current state.
  ({double field, double button}) positions(WidgetTester tester) {
    return (
      field: tester.getTopLeft(find.byType(TextFormField)).dy,
      button: tester.getTopLeft(find.byType(FilledButton).evaluate().isNotEmpty
              ? find.byType(FilledButton)
              : find.byType(OutlinedButton).first)
          .dy,
    );
  }

  Future<void> submit(WidgetTester tester, String email) async {
    await tester.enterText(find.byType(TextFormField), email);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
  }

  for (final width in [...phoneWidths, desktop]) {
    group('at ${width.toInt()} wide', () {
      testWidgets('the field and the button stay put: idle, checking, breached', (tester) async {
        final service = FakeBreachApiService();
        await pump(tester, service, width);
        final idle = positions(tester);

        await submit(tester, 'name@example.com');
        final checking = positions(tester);
        expect(checking.field, closeTo(idle.field, 1), reason: 'field, while checking');
        expect(checking.button, closeTo(idle.button, 1), reason: 'button, while checking');

        service.answerBreached('name@example.com', ['Adobe', 'LinkedIn', 'Dropbox']);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final found = positions(tester);
        expect(found.field, closeTo(idle.field, 1), reason: 'field, with breaches');
        expect(found.button, closeTo(idle.button, 1), reason: 'button, with breaches');
      });

      testWidgets('...and for a two-digit count, a clean result and a failure', (tester) async {
        final service = FakeBreachApiService();
        await pump(tester, service, width);
        final idle = positions(tester);

        await submit(tester, 'name@example.com');
        service.answerBreached('name@example.com', [for (var i = 0; i < 24; i++) 'Breach $i']);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(positions(tester).field, closeTo(idle.field, 1), reason: 'field, 24 breaches');

        // Start again with an address that is clean.
        await tester.tap(find.widgetWithText(OutlinedButton, 'Check another address'));
        await tester.pump();
        await submit(tester, 'name@example.com');
        service.answerClean('name@example.com');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(positions(tester).field, closeTo(idle.field, 1), reason: 'field, clean');

        // ...and with each kind of failure.
        for (final failure in BreachApiFailure.values) {
          // Start from a blank form: after the clean result there is a button
          // for that, and after a failure editing the field does it.
          final another = find.widgetWithText(OutlinedButton, 'Check another address');
          if (another.evaluate().isNotEmpty) {
            await tester.tap(another);
            await tester.pump();
          }
          await submit(tester, 'name@example.com');
          service.failCheck(failure);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          final failed = positions(tester);
          expect(failed.field, closeTo(idle.field, 1), reason: 'field, ${failure.name}');
          expect(failed.button, closeTo(idle.button, 1), reason: 'button, ${failure.name}');

          // Back to idle for the next one: editing the field clears a failure.
          await tester.enterText(find.byType(TextFormField), '');
          await tester.pump();
        }
      });
    });
  }
}
