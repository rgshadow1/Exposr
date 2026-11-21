// A design preview. This is NOT the app: `lib/main.dart` is.
//
// It runs the real screens against made-up data, so every state (breaches
// found, nothing found, each kind of failure, long names, long lists) can be
// looked at without sending anything anywhere or using up XposedOrNot's free
// limit. A strip across the top of every screen says the data is sample data.
//
//   flutter run -t lib/dev/preview_main.dart
//
// What the address you type decides:
//
//   breached@...  three breaches, with details
//   many@...      forty breaches, one with a very long name
//   one@...       one breach, whose details come back empty
//   offline@...   no connection        slow@...    a timeout
//   limit@...     the rate limit       server@...  a server error
//   odd@...       an unexpected reply
//   anything else: no known breaches
//
// Nothing here is reachable from `lib/main.dart`, so none of it is compiled
// into the real app.
import 'package:flutter/material.dart';

import '../app.dart';
import '../app_environment.dart';
import '../models/breach.dart';
import '../models/email_check_result.dart';
import '../services/breach_api_service.dart';
import '../services/sound_service.dart';

void main() {
  runApp(
    BreachCheckerApp(
      service: PreviewBreachApiService(),
      // The real sound player, so the result sounds can be heard here (turn
      // them on in Settings). Everything else about the device is a stand-in.
      environment: AppEnvironment(sounds: AssetSoundService()),
      sampleDataNotice: 'Design preview. Every result here is sample data, and nothing is sent.',
    ),
  );
}

/// Answers from a script instead of from the network.
class PreviewBreachApiService implements BreachApiService {
  PreviewBreachApiService({this.delay = const Duration(milliseconds: 900)});

  /// A stand-in for the time a real request takes.
  final Duration delay;

  static String _scenario(String email) => email.split('@').first.toLowerCase();

  static const Map<String, BreachApiFailure> _failures = {
    'offline': BreachApiFailure.noConnection,
    'slow': BreachApiFailure.timeout,
    'limit': BreachApiFailure.rateLimited,
    'server': BreachApiFailure.serverError,
    'odd': BreachApiFailure.unexpectedResponse,
  };

  @override
  Future<EmailCheckResult> checkEmail(String email) async {
    await Future<void>.delayed(delay);

    final scenario = _scenario(email);
    final failure = _failures[scenario];
    if (failure != null) throw BreachApiException(failure);

    return switch (scenario) {
      'breached' => EmailBreached(email, [for (final breach in sampleBreaches) breach.name]),
      'many' => EmailBreached(email, [for (final breach in manySampleBreaches) breach.name]),
      'one' => EmailBreached(email, const ['Sample Forum']),
      _ => EmailClean(email),
    };
  }

  @override
  Future<List<Breach>> fetchBreachDetails(String email) async {
    await Future<void>.delayed(delay);

    return switch (_scenario(email)) {
      'breached' => sampleBreaches,
      'many' => manySampleBreaches,
      _ => const [],
    };
  }

  @override
  void close() {}
}

/// Invented breaches of invented services. Only their shape is real: the
/// fields are the ones XposedOrNot returns.
final List<Breach> sampleBreaches = [
  Breach(
    name: 'Sample Streaming Service',
    domain: 'streaming.example',
    industry: 'Entertainment',
    date: '2021',
    records: 4820113,
    exposedData: const ['Email addresses', 'Names', 'Passwords', 'IP addresses'],
    passwordRisk: PasswordRisk.easyToCrack,
    description: 'Sample text. A made-up streaming service had its customer database copied in '
        '2021. The copy included email addresses, names, IP addresses and passwords stored as '
        'unsalted MD5 hashes, which are quick to reverse.',
    reference: Uri.parse('https://example.com/sample-report'),
    verified: true,
  ),
  const Breach(
    name: 'Sample Marketing List',
    industry: 'Marketing',
    date: '2019',
    records: 152445165,
    exposedData: ['Email addresses', 'Phone numbers', 'Geographic locations', 'Dates of birth'],
  ),
  const Breach(
    name: 'Sample Forum',
    domain: 'forum.example',
    industry: 'Information Technology',
    date: '2016',
    records: 254967,
    exposedData: ['Usernames', 'Email addresses', 'Passwords'],
    passwordRisk: PasswordRisk.hardToCrack,
    description: 'Sample text. A made-up discussion forum exposed 255k accounts in 2016. '
        'Passwords were stored as salted hashes.',
    verified: true,
  ),
];

/// A long list, led by a breach with a very long name and many kinds of data.
final List<Breach> manySampleBreaches = [
  const Breach(
    name: 'An Unusually Long Sample Breach Name That Keeps Going To Test How A Row Wraps '
        '(Combined Collection, Second Edition)',
    date: '2024',
    records: 1250000000,
    exposedData: [
      'Email addresses',
      'Passwords',
      'Password hints',
      'Names',
      'Phone numbers',
      'Physical addresses',
      'Dates of birth',
      'Government-issued IDs',
      'Partial credit card data',
      'Security questions and answers',
    ],
    passwordRisk: PasswordRisk.plaintext,
    description: 'Sample text. A deliberately long description, to check that a long passage '
        'stays readable once a row is opened. It repeats itself. It repeats itself. It repeats '
        'itself. It repeats itself. It repeats itself. It repeats itself. It repeats itself.',
  ),
  for (var i = 2; i <= 40; i++)
    Breach(
      name: 'Sample Service $i',
      domain: 'service$i.example',
      industry: const ['Retail', 'Gaming', 'Finance', 'Health', 'Education'][i % 5],
      date: '${2024 - (i ~/ 3)}',
      records: 12000 * i * i,
      exposedData: [
        'Email addresses',
        if (i.isEven) 'Passwords',
        if (i % 3 == 0) 'Usernames',
        if (i % 5 == 0) 'Phone numbers',
      ],
      passwordRisk: PasswordRisk.values[i % PasswordRisk.values.length],
    ),
];
