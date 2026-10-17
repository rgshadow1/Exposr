import 'package:breach_checker/services/breach_api_service.dart';
import 'package:breach_checker/services/key_value_store.dart';
import 'package:breach_checker/state/email_check_controller.dart';
import 'package:breach_checker/state/result_feedback.dart';
import 'package:breach_checker/state/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_breach_api_service.dart';
import 'support/fakes.dart';

void main() {
  late FakeBreachApiService service;
  late EmailCheckController controller;
  late SettingsController settings;
  late FakeHapticsService haptics;
  late ResultFeedback feedback;

  setUp(() {
    service = FakeBreachApiService();
    controller = EmailCheckController(service);
    settings = SettingsController(MemoryKeyValueStore());
    haptics = FakeHapticsService();
    feedback = ResultFeedback(controller: controller, settings: settings, haptics: haptics);
  });

  tearDown(() {
    feedback.dispose();
    controller.dispose();
    settings.dispose();
  });

  test('a firm pattern when breaches are found', () async {
    final check = controller.check('a@b.co');
    service.answerBreached('a@b.co', ['Adobe']);
    await check;

    expect(haptics.calls, ['breached']);
  });

  test('a soft tap when nothing is found', () async {
    final check = controller.check('a@b.co');
    service.answerClean('a@b.co');
    await check;

    expect(haptics.calls, ['clean']);
  });

  test('a click when the check fails', () async {
    final check = controller.check('a@b.co');
    service.failCheck(BreachApiFailure.noConnection);
    await check;

    expect(haptics.calls, ['failed']);
  });

  test('nothing while the check is still running', () {
    controller.check('a@b.co');

    expect(haptics.calls, isEmpty);
  });

  test('nothing when haptics are switched off', () async {
    await settings.setHapticsEnabled(false);

    final check = controller.check('a@b.co');
    service.answerBreached('a@b.co', ['Adobe']);
    await check;

    expect(haptics.calls, isEmpty);
  });

  test('loading the details afterwards does not buzz again', () async {
    final check = controller.check('a@b.co');
    service.answerBreached('a@b.co', ['Adobe']);
    await check;

    final details = controller.loadDetails();
    service.answerDetails([sampleBreach]);
    await details;

    expect(haptics.calls, ['breached']);
  });

  test('clearing the screen does not buzz', () async {
    final check = controller.check('a@b.co');
    service.answerBreached('a@b.co', ['Adobe']);
    await check;

    controller.reset();

    expect(haptics.calls, ['breached']);
  });
}
