import 'package:breach_checker/data/breach_check_exception.dart';
import 'package:breach_checker/models/breach_check_state.dart';
import 'package:breach_checker/state/breach_check_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_breach_repository.dart';

void main() {
  late FakeBreachRepository repository;
  late BreachCheckController controller;

  setUp(() {
    repository = FakeBreachRepository();
    controller = BreachCheckController(repository);
  });

  tearDown(() => controller.dispose());

  test('starts idle', () {
    expect(controller.state, isA<CheckIdle>());
    expect(controller.isLoading, isFalse);
  });

  test('loading, then breaches found', () async {
    final future = controller.check('  name@example.com ');

    expect(controller.state, isA<CheckLoading>());
    expect(controller.isLoading, isTrue);
    expect(repository.requestedEmails, ['name@example.com']);

    repository.succeed([sampleBreach]);
    await future;

    expect(controller.state, isA<CheckBreachesFound>());
    final found = controller.state as CheckBreachesFound;
    expect(found.email, 'name@example.com');
    expect(found.breaches, [sampleBreach]);
  });

  test('an empty result means no breaches', () async {
    final future = controller.check('name@example.com');
    repository.succeed([]);
    await future;

    expect(controller.state, isA<CheckNoBreaches>());
  });

  test('a BreachCheckException becomes a failed state', () async {
    final future = controller.check('name@example.com');
    repository.fail(const BreachCheckException(BreachCheckFailure.timeout));
    await future;

    final state = controller.state;
    expect(state, isA<CheckFailed>());
    expect((state as CheckFailed).error.failure, BreachCheckFailure.timeout);
  });

  test('an unexpected error still ends loading', () async {
    // The controller reports unexpected errors through FlutterError; silence
    // that for this test so it doesn't clutter the output.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = originalOnError);

    final future = controller.check('name@example.com');
    repository.fail(StateError('bug'));
    await future;

    final state = controller.state;
    expect(state, isA<CheckFailed>());
    expect((state as CheckFailed).error.failure, BreachCheckFailure.unexpectedResponse);
  });

  test('a result that arrives after reset is ignored', () async {
    final future = controller.check('name@example.com');
    controller.reset();
    repository.succeed([sampleBreach]);
    await future;

    expect(controller.state, isA<CheckIdle>());
  });

  test('a slow earlier request cannot overwrite a newer result', () async {
    final first = controller.check('first@example.com');
    final second = controller.check('second@example.com');

    repository.succeedAt(1, []); // the second request answers first
    await second;
    expect(controller.state, isA<CheckNoBreaches>());

    repository.succeedAt(0, [sampleBreach]); // then the stale first one
    await first;
    final state = controller.state;
    expect(state, isA<CheckNoBreaches>());
    expect((state as CheckNoBreaches).email, 'second@example.com');
  });

  test('notifies listeners on each state change', () async {
    var notifications = 0;
    controller.addListener(() => notifications++);

    final future = controller.check('name@example.com');
    repository.succeed([]);
    await future;

    expect(notifications, 2); // loading, then result
  });
}
