import 'dart:async';

import 'package:breach_checker/core/app_theme.dart';
import 'package:breach_checker/models/breach.dart';
import 'package:breach_checker/screens/insights_screen.dart';
import 'package:breach_checker/services/breach_api_service.dart';
import 'package:breach_checker/state/email_check_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_breach_api_service.dart';

void main() {
  late FakeBreachApiService service;
  late EmailCheckController controller;

  const linkedIn = Breach(
    name: 'LinkedIn',
    date: '2016-05-18',
    records: 117000000,
    exposedData: ['Email addresses', 'Passwords'],
    passwordRisk: PasswordRisk.plaintext,
  );

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    service = FakeBreachApiService();
    controller = EmailCheckController(service);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: InsightsScreen(controller: controller)),
      ),
    );
  }

  /// Gets the controller into "breaches found", without the details yet.
  Future<void> findBreaches(WidgetTester tester) async {
    unawaited(controller.check('a@b.co'));
    service.answerBreached('a@b.co', ['Adobe', 'LinkedIn']);
    await tester.pump();
  }

  /// ...and then loads the details.
  Future<void> loadDetails(WidgetTester tester, List<Breach> breaches) async {
    unawaited(controller.loadDetails());
    service.answerDetails(breaches);
    await tester.pumpAndSettle();
  }

  testWidgets('before any check, explains how to get insights', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('No insights yet'), findsOneWidget);
    expect(find.textContaining('Check an email address on Home'), findsOneWidget);
  });

  testWidgets('a clean address has nothing to chart', (tester) async {
    await pumpScreen(tester);

    unawaited(controller.check('a@b.co'));
    service.answerClean('a@b.co');
    await tester.pump();

    expect(find.text('Nothing to chart'), findsOneWidget);
    expect(find.textContaining('a@b.co'), findsOneWidget);
  });

  testWidgets('with breaches but no details yet, offers to load them', (tester) async {
    await pumpScreen(tester);
    await findBreaches(tester);

    expect(find.text('Load the details'), findsOneWidget);
    expect(find.textContaining('2 breaches'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Load details'));
    await tester.pump();

    expect(service.detailEmails, ['a@b.co']);
    expect(find.text('Loading details…'), findsOneWidget);
  });

  testWidgets('shows the charts once the details are loaded', (tester) async {
    await pumpScreen(tester);
    await findBreaches(tester);
    await loadDetails(tester, [sampleBreach, linkedIn]);

    // Headline numbers: 152,445,165 + 117,000,000 records.
    expect(find.text('Breaches'), findsOneWidget);
    expect(find.text('Records exposed'), findsOneWidget);
    expect(find.text('269.4M'), findsOneWidget);
    expect(find.text('Most recent'), findsOneWidget);

    // The three charts.
    expect(find.text('Breaches by year'), findsOneWidget);
    expect(find.text('What was exposed'), findsOneWidget);
    expect(find.text('Password protection'), findsOneWidget);

    // Years from the two breaches, kinds of data, and the password legend.
    expect(find.text('2013'), findsOneWidget);
    expect(find.text('2016'), findsNWidgets(2)); // the "most recent" card and the chart
    expect(find.text('Email addresses'), findsOneWidget);
    expect(find.text('Passwords'), findsOneWidget);
    expect(find.text('Stored as plain text'), findsOneWidget);
    expect(find.text('Easy to crack'), findsOneWidget);
    expect(find.textContaining('2 breaches kept passwords in a form that is easy to recover'), findsOneWidget);
  });

  testWidgets('a breach with no date is left off the timeline but still counted', (tester) async {
    await pumpScreen(tester);
    await findBreaches(tester);
    await loadDetails(tester, [sampleBreach, const Breach(name: 'Mystery', records: 10)]);

    expect(find.text('2013'), findsNWidgets(2)); // the "most recent" card and the chart
    expect(find.text('Most recent'), findsOneWidget);
    expect(find.text('Breaches'), findsOneWidget);
  });

  testWidgets('a failed details request can be retried', (tester) async {
    await pumpScreen(tester);
    await findBreaches(tester);

    unawaited(controller.loadDetails());
    service.failDetails(BreachApiFailure.rateLimited);
    await tester.pump();

    expect(find.text('Too many checks'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Try again'));
    await tester.pump();

    expect(service.detailEmails, ['a@b.co', 'a@b.co']);
  });

  testWidgets('goes back to the empty state when the screen is cleared', (tester) async {
    await pumpScreen(tester);
    await findBreaches(tester);
    await loadDetails(tester, [sampleBreach]);
    expect(find.text('Breaches by year'), findsOneWidget);

    controller.wipe();
    await tester.pumpAndSettle();

    expect(find.text('Breaches by year'), findsNothing);
    expect(find.text('No insights yet'), findsOneWidget);
  });
}
