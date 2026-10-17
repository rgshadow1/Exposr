import 'dart:async';

import 'package:breach_checker/models/breach.dart';
import 'package:breach_checker/models/email_check_result.dart';
import 'package:breach_checker/services/app_lock_service.dart';
import 'package:breach_checker/services/breach_api_service.dart';
import 'package:breach_checker/services/haptics_service.dart';
import 'package:breach_checker/services/link_opener.dart';
import 'package:breach_checker/services/shake_source.dart';

/// A [BreachApiService] that answers at once from a script.
///
/// Unlike `FakeBreachApiService` (which waits for the test to answer by hand,
/// so a test can look at the loading screen), this one is for tests that only
/// care about the outcome: set what an address should return, then check it.
class ScriptedBreachApiService implements BreachApiService {
  /// Lower-case address -> breach names. An address not listed is clean.
  final Map<String, List<String>> breaches = {};

  /// Lower-case address -> the failure to throw instead of answering.
  final Map<String, BreachApiFailure> failures = {};

  /// Every address that was checked, in order.
  final List<String> checked = [];

  @override
  Future<EmailCheckResult> checkEmail(String email) async {
    checked.add(email);
    final failure = failures[email.toLowerCase()];
    if (failure != null) throw BreachApiException(failure);

    final names = breaches[email.toLowerCase()];
    if (names == null || names.isEmpty) return EmailClean(email);
    return EmailBreached(email, names);
  }

  @override
  Future<List<Breach>> fetchBreachDetails(String email) async => const [];

  @override
  void close() {}
}

/// Records which vibration patterns were requested.
class FakeHapticsService implements HapticsService {
  final List<String> calls = [];

  @override
  Future<void> breached() async => calls.add('breached');

  @override
  Future<void> clean() async => calls.add('clean');

  @override
  Future<void> failed() async => calls.add('failed');
}

/// A phone that is shaken whenever the test says so.
class FakeShakeSource implements ShakeSource {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  @override
  Stream<void> get shakes => _controller.stream;

  bool get hasListener => _controller.hasListener;

  void shake() => _controller.add(null);
}

/// A phone lock the test controls.
class FakeAppLockService implements AppLockService {
  FakeAppLockService({this.available = true, this.succeeds = true});

  bool available;
  bool succeeds;

  /// When set, [authenticate] waits for this instead of answering, so a test
  /// can look at the locked screen before deciding the outcome.
  Completer<bool>? pending;

  final List<String> reasons = [];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) {
    reasons.add(reason);
    final waiting = pending;
    if (waiting != null) return waiting.future;
    return Future.value(succeeds);
  }
}

/// Remembers which links were "opened".
class FakeLinkOpener implements LinkOpener {
  FakeLinkOpener({this.succeeds = true});

  bool succeeds;
  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return succeeds;
  }
}
