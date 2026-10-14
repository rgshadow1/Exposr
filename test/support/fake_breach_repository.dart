import 'dart:async';

import 'package:breach_checker/data/breach_repository.dart';
import 'package:breach_checker/models/breach.dart';

/// A [BreachRepository] for tests.
///
/// Each call to [findBreaches] returns a future the test completes by hand
/// with [succeed] or [fail]. That makes the in-between "loading" state
/// observable, which a real network call would make timing-dependent.
class FakeBreachRepository implements BreachRepository {
  final List<String> requestedEmails = [];
  final List<Completer<List<Breach>>> _pending = [];

  @override
  Future<List<Breach>> findBreaches(String email) {
    requestedEmails.add(email);
    final completer = Completer<List<Breach>>();
    _pending.add(completer);
    return completer.future;
  }

  /// Completes the oldest outstanding request with [breaches].
  void succeed(List<Breach> breaches) => _next().complete(breaches);

  /// Completes the request made [index]-th (0 = first ever) with [breaches],
  /// for testing responses that arrive out of order.
  void succeedAt(int index, List<Breach> breaches) => _pending[index].complete(breaches);

  /// Completes the oldest outstanding request with [error].
  void fail(Object error) => _next().completeError(error);

  Completer<List<Breach>> _next() => _pending.firstWhere((c) => !c.isCompleted);
}

const sampleBreach = Breach(
  name: 'Adobe',
  title: 'Adobe',
  domain: 'adobe.com',
  pwnCount: 152445165,
  description: 'In October 2013, 153 million Adobe accounts were breached.',
  dataClasses: ['Email addresses', 'Password hints', 'Passwords', 'Usernames'],
);
