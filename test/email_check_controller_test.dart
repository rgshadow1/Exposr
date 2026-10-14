import 'package:breach_checker/services/breach_api_service.dart';
import 'package:breach_checker/state/email_check_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_breach_api_service.dart';

void main() {
  late FakeBreachApiService service;
  late EmailCheckController controller;

  setUp(() {
    service = FakeBreachApiService();
    controller = EmailCheckController(service);
  });

  tearDown(() => controller.dispose());

  test('starts idle', () {
    expect(controller.state, isA<LookupIdle>());
    expect(controller.isLoading, isFalse);
  });

  test('moves idle -> loading -> breached, and notifies listeners', () async {
    var notifications = 0;
    controller.addListener(() => notifications++);

    final pending = controller.check('a@b.co');
    expect(controller.state, isA<LookupLoading>());
    expect(controller.isLoading, isTrue);

    service.answerBreached('a@b.co', ['Adobe']);
    await pending;

    final state = controller.state as LookupBreached;
    expect(state.breachNames, ['Adobe']);
    expect(state.details, isA<DetailsIdle>());
    expect(notifications, 2); // loading, then result
  });

  test('a clean address ends in the clean state', () async {
    final pending = controller.check('a@b.co');
    service.answerClean('a@b.co');
    await pending;

    expect(controller.state, isA<LookupClean>());
  });

  test('a service failure ends in the failed state with its reason', () async {
    final pending = controller.check('a@b.co');
    service.failCheck(BreachApiFailure.rateLimited);
    await pending;

    final state = controller.state as LookupFailed;
    expect(state.failure, BreachApiFailure.rateLimited);
    expect(state.email, 'a@b.co');
  });

  test('a second check while one is running is ignored', () async {
    final first = controller.check('a@b.co');
    await controller.check('other@b.co');

    expect(service.checkedEmails, ['a@b.co']);

    service.answerClean('a@b.co');
    await first;
  });

  test('a reply that arrives after reset() is discarded', () async {
    final pending = controller.check('a@b.co');
    controller.reset();
    expect(controller.state, isA<LookupIdle>());

    service.answerBreached('a@b.co', ['Adobe']);
    await pending;

    expect(controller.state, isA<LookupIdle>());
  });

  test('details load on demand and attach to the breached state', () async {
    final check = controller.check('a@b.co');
    service.answerBreached('a@b.co', ['Adobe']);
    await check;

    final details = controller.loadDetails();
    expect((controller.state as LookupBreached).details, isA<DetailsLoading>());

    service.answerDetails([sampleBreach]);
    await details;

    final loaded = (controller.state as LookupBreached).details as DetailsLoaded;
    expect(loaded.breaches.single.name, 'Adobe');
    expect(service.detailEmails, ['a@b.co']);
  });

  test('details failure can be retried', () async {
    final check = controller.check('a@b.co');
    service.answerBreached('a@b.co', ['Adobe']);
    await check;

    final first = controller.loadDetails();
    service.failDetails(BreachApiFailure.timeout);
    await first;
    expect((controller.state as LookupBreached).details, isA<DetailsFailed>());

    final retry = controller.loadDetails();
    service.answerDetails([sampleBreach]);
    await retry;

    expect((controller.state as LookupBreached).details, isA<DetailsLoaded>());
    expect(service.detailEmails.length, 2);
  });

  test('loadDetails does nothing unless breaches were found', () async {
    await controller.loadDetails();

    expect(service.detailEmails, isEmpty);
  });
}
