import 'package:breach_checker/app.dart';
import 'package:breach_checker/config/app_config.dart';
import 'package:breach_checker/data/breach_check_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_breach_repository.dart';

/// End-to-end tests of the UI, with the network replaced by
/// [FakeBreachRepository]. They drive the app the way a user would: type,
/// tap, and check what appears on screen.
void main() {
  late FakeBreachRepository repository;

  setUp(() => repository = FakeBreachRepository());

  Future<void> pumpApp(WidgetTester tester, {AppConfig? config}) async {
    await tester.pumpWidget(
      BreachCheckerApp(
        config: config ??
            AppConfig(baseUrl: Uri.parse(AppConfig.hibpBaseUrl), apiKey: 'test-key'),
        repository: repository,
      ),
    );
  }

  Future<void> submit(WidgetTester tester, String email) async {
    await tester.enterText(find.byType(TextFormField), email);
    await tester.tap(find.widgetWithText(FilledButton, 'Check'));
    await tester.pump();
  }

  testWidgets('shows the intro before any search', (tester) async {
    await pumpApp(tester);

    expect(find.text('Check an email address'), findsOneWidget);
    expect(find.text('Before you check'), findsOneWidget);
    expect(find.text('Setup needed'), findsNothing);
  });

  testWidgets('warns when no API key or proxy is configured', (tester) async {
    await pumpApp(
      tester,
      config: AppConfig(baseUrl: Uri.parse(AppConfig.hibpBaseUrl), apiKey: null),
    );

    expect(find.text('Setup needed'), findsOneWidget);
  });

  testWidgets('invalid email shows a validation error and sends nothing', (tester) async {
    await pumpApp(tester);

    await submit(tester, 'not-an-email');

    expect(find.text('Enter a valid email address, like name@example.com.'), findsOneWidget);
    expect(repository.requestedEmails, isEmpty);
  });

  testWidgets('loading, then a list of breaches', (tester) async {
    await pumpApp(tester);

    await submit(tester, 'name@example.com');

    expect(find.text('Checking name@example.com…'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Check'), findsNothing); // spinner instead

    repository.succeed([sampleBreach]);
    await tester.pumpAndSettle();

    expect(find.text('Found in 1 breach'), findsOneWidget);
    expect(find.text('Adobe'), findsOneWidget);
    expect(find.text('Passwords'), findsOneWidget);
    expect(find.textContaining('152,445,165 accounts'), findsOneWidget);
  });

  testWidgets('no breaches found', (tester) async {
    await pumpApp(tester);

    await submit(tester, 'name@example.com');
    repository.succeed([]);
    await tester.pumpAndSettle();

    expect(find.text('No breaches found'), findsOneWidget);
    expect(find.textContaining('This isn’t a guarantee'), findsOneWidget);
  });

  testWidgets('error state can be retried', (tester) async {
    await pumpApp(tester);

    await submit(tester, 'name@example.com');
    repository.fail(const BreachCheckException(BreachCheckFailure.noConnection));
    await tester.pumpAndSettle();

    expect(find.text('Couldn’t connect'), findsOneWidget);

    final retry = find.widgetWithText(FilledButton, 'Try again');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pump();

    expect(repository.requestedEmails, ['name@example.com', 'name@example.com']);
    repository.succeed([]);
    await tester.pumpAndSettle();
    expect(find.text('No breaches found'), findsOneWidget);
  });

  testWidgets('"New search" clears the field and returns to the intro', (tester) async {
    await pumpApp(tester);

    await submit(tester, 'name@example.com');
    repository.succeed([]);
    await tester.pumpAndSettle();

    final newSearch = find.widgetWithText(OutlinedButton, 'New search');
    await tester.ensureVisible(newSearch);
    await tester.tap(newSearch);
    await tester.pumpAndSettle();

    expect(find.text('Before you check'), findsOneWidget);
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller!.text, isEmpty);
  });
}
