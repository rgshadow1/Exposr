import 'dart:async';

import 'package:breach_checker/models/breach.dart';
import 'package:breach_checker/models/email_check_result.dart';
import 'package:breach_checker/services/breach_api_service.dart';

/// A [BreachApiService] the test controls by hand.
///
/// Each call returns a future that stays pending until the test completes it,
/// so a test can look at the "loading" screen before deciding what the
/// "server" answers. No network is involved.
class FakeBreachApiService implements BreachApiService {
  final List<String> checkedEmails = [];
  final List<String> detailEmails = [];

  Completer<EmailCheckResult> _check = Completer<EmailCheckResult>();
  Completer<List<Breach>> _details = Completer<List<Breach>>();

  @override
  Future<EmailCheckResult> checkEmail(String email) {
    checkedEmails.add(email);
    _check = Completer<EmailCheckResult>();
    return _check.future;
  }

  @override
  Future<List<Breach>> fetchBreachDetails(String email) {
    detailEmails.add(email);
    _details = Completer<List<Breach>>();
    return _details.future;
  }

  @override
  void close() {}

  void answerBreached(String email, List<String> names) =>
      _check.complete(EmailBreached(email, names));

  void answerClean(String email) => _check.complete(EmailClean(email));

  void failCheck(BreachApiFailure failure) => _check.completeError(BreachApiException(failure));

  void answerDetails(List<Breach> breaches) => _details.complete(breaches);

  void failDetails(BreachApiFailure failure) => _details.completeError(BreachApiException(failure));
}

/// A realistic breach for tests, shaped like XposedOrNot's data.
const sampleBreach = Breach(
  name: 'Adobe',
  domain: 'adobe.com',
  industry: 'Technology',
  date: '2013',
  records: 152445165,
  exposedData: ['Email addresses', 'Passwords'],
  passwordRisk: PasswordRisk.easyToCrack,
  description: 'Customer records were exposed in a 2013 breach.',
  verified: true,
);
