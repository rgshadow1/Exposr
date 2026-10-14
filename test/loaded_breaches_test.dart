import 'package:breach_checker/state/email_check_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_breach_api_service.dart';

/// `controller.loadedBreaches` is what the Insights screen will read: the
/// breach details that have been fetched for the address on screen, or an
/// empty list when there aren't any.
void main() {
  late FakeBreachApiService service;
  late EmailCheckController controller;

  setUp(() {
    service = FakeBreachApiService();
    controller = EmailCheckController(service);
  });

  tearDown(() => controller.dispose());

  /// Runs a check that finds breaches, and waits for it to finish.
  Future<void> checkAndFindBreaches() async {
    final check = controller.check('a@b.co');
    service.answerBreached('a@b.co', ['Adobe']);
    await check;
  }

  test('is empty before any check', () {
    expect(controller.loadedBreaches, isEmpty);
  });

  test('is empty after a check, until details are asked for', () async {
    await checkAndFindBreaches();

    expect(controller.loadedBreaches, isEmpty);
  });

  test('is empty while details are still loading', () async {
    await checkAndFindBreaches();

    final details = controller.loadDetails();
    expect(controller.loadedBreaches, isEmpty);

    service.answerDetails([sampleBreach]);
    await details;
  });

  test('holds the breaches once the details have loaded', () async {
    await checkAndFindBreaches();

    final details = controller.loadDetails();
    service.answerDetails([sampleBreach]);
    await details;

    expect(controller.loadedBreaches, [sampleBreach]);
  });

  test('is empty when the address was clean', () async {
    final check = controller.check('a@b.co');
    service.answerClean('a@b.co');
    await check;

    expect(controller.loadedBreaches, isEmpty);
  });

  test('is empty again after reset()', () async {
    await checkAndFindBreaches();
    final details = controller.loadDetails();
    service.answerDetails([sampleBreach]);
    await details;
    expect(controller.loadedBreaches, isNotEmpty);

    controller.reset();

    expect(controller.loadedBreaches, isEmpty);
  });
}
