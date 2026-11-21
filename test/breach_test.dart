import 'package:breach_checker/models/breach.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests the parser against the shape XposedOrNot's breach-analytics endpoint
/// documents for one entry of `ExposedBreaches.breaches_details`.
void main() {
  group('Breach.fromJson', () {
    test('parses a full entry', () {
      final breach = Breach.fromJson(const {
        'breach': 'SweClockers',
        'details': 'SweClockers experienced a data breach in early 2015.',
        'domain': 'sweclockers.com',
        'industry': 'Electronics',
        'logo': 'Sweclockers.png',
        'password_risk': 'hardtocrack',
        'references': 'https://example.com/report',
        'searchable': 'Yes',
        'verified': 'Yes',
        'xposed_data': 'Usernames;Email addresses;Passwords',
        'xposed_date': '2015',
        'xposed_records': 254967,
      });

      expect(breach.name, 'SweClockers');
      expect(breach.domain, 'sweclockers.com');
      expect(breach.industry, 'Electronics');
      expect(breach.date, '2015');
      expect(breach.year, 2015);
      expect(breach.records, 254967);
      expect(breach.exposedData, ['Usernames', 'Email addresses', 'Passwords']);
      expect(breach.passwordRisk, PasswordRisk.hardToCrack);
      expect(breach.description, 'SweClockers experienced a data breach in early 2015.');
      expect(breach.reference, Uri.parse('https://example.com/report'));
      expect(breach.verified, isTrue);
    });

    test('an almost empty entry still parses, with nothing made up', () {
      final breach = Breach.fromJson(const {'breach': 'Mystery'});

      expect(breach.name, 'Mystery');
      expect(breach.date, isNull);
      expect(breach.year, isNull);
      expect(breach.records, isNull);
      expect(breach.exposedData, isEmpty);
      expect(breach.description, isNull);
      expect(breach.reference, isNull);
      expect(breach.verified, isFalse);
    });

    test('a missing or unrecognised password risk is unknown, never good news', () {
      expect(Breach.fromJson(const {'breach': 'A'}).passwordRisk, PasswordRisk.unknown);
      expect(
        Breach.fromJson(const {'breach': 'A', 'password_risk': ''}).passwordRisk,
        PasswordRisk.unknown,
      );
      expect(
        Breach.fromJson(const {'breach': 'A', 'password_risk': 'something new'}).passwordRisk,
        PasswordRisk.unknown,
      );
    });

    test('reads the password risk however it is spelled', () {
      PasswordRisk risk(String raw) =>
          Breach.fromJson({'breach': 'A', 'password_risk': raw}).passwordRisk;

      expect(risk('plaintext'), PasswordRisk.plaintext);
      expect(risk('PlainText'), PasswordRisk.plaintext);
      expect(risk('easytocrack'), PasswordRisk.easyToCrack);
      expect(risk('Easy to crack'), PasswordRisk.easyToCrack);
      expect(risk('hardtocrack'), PasswordRisk.hardToCrack);
      expect(risk('unknown'), PasswordRisk.unknown);
    });

    test('record counts are accepted as numbers or text', () {
      int? records(Object? raw) => Breach.fromJson({'breach': 'A', 'xposed_records': raw}).records;

      expect(records(152445165), 152445165);
      expect(records('152445165'), 152445165);
      expect(records('152,445,165'), 152445165);
      expect(records('lots'), isNull);
    });

    test('the year is the breach year at the start of the date', () {
      int? year(String raw) => Breach.fromJson({'breach': 'A', 'xposed_date': raw}).year;

      expect(year('2013'), 2013);
      expect(year('2013-10-04'), 2013);
      expect(year('unknown'), isNull);
    });

    test('HTML in a description becomes plain text on one line', () {
      final breach = Breach.fromJson(const {
        'breach': 'A',
        'details': '<p>Customer &amp; billing data.</p><p>Passwords were <em>hashed</em>.</p>',
      });

      expect(breach.description, 'Customer & billing data. Passwords were hashed.');
    });

    test('only an https reference is kept', () {
      Uri? reference(String raw) => Breach.fromJson({'breach': 'A', 'references': raw}).reference;

      expect(reference('https://example.com/a'), Uri.parse('https://example.com/a'));
      expect(reference('http://example.com/a'), isNull);
      expect(reference('javascript:alert(1)'), isNull);
      expect(reference('not a link'), isNull);
      expect(reference(''), isNull);
    });

    test('"verified" is true only when the API says so', () {
      bool verified(Object? raw) => Breach.fromJson({'breach': 'A', 'verified': raw}).verified;

      expect(verified('Yes'), isTrue);
      expect(verified(true), isTrue);
      expect(verified('No'), isFalse);
      expect(verified(null), isFalse);
    });
  });
}
