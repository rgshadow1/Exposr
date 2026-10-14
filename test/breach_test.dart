import 'package:breach_checker/models/breach.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Breach.fromJson', () {
    test('parses a full HIBP breach object', () {
      final breach = Breach.fromJson(const {
        'Name': 'Adobe',
        'Title': 'Adobe',
        'Domain': 'adobe.com',
        'BreachDate': '2013-10-04',
        'AddedDate': '2013-12-04T00:00:00Z',
        'PwnCount': 152445165,
        'Description': 'In October 2013, 153 million <em>Adobe</em> accounts were breached.',
        'DataClasses': ['Email addresses', 'Password hints', 'Passwords', 'Usernames'],
        'IsVerified': true,
        'IsFabricated': false,
        'IsSensitive': false,
        'IsRetired': false,
        'IsSpamList': false,
        'IsMalware': false,
        'IsStealerLog': false,
        'LogoPath': 'Adobe.png',
      });

      expect(breach.name, 'Adobe');
      expect(breach.title, 'Adobe');
      expect(breach.domain, 'adobe.com');
      expect(breach.breachDate, DateTime(2013, 10, 4));
      expect(breach.pwnCount, 152445165);
      expect(breach.description, 'In October 2013, 153 million Adobe accounts were breached.');
      expect(breach.dataClasses, ['Email addresses', 'Password hints', 'Passwords', 'Usernames']);
      expect(breach.isVerified, isTrue);
      expect(breach.isSpamList, isFalse);
      expect(breach.infoUrl.toString(), 'https://haveibeenpwned.com/PwnedWebsites#Adobe');
    });

    test('only Name is required; missing fields fall back safely', () {
      final breach = Breach.fromJson(const {'Name': 'Example'});

      expect(breach.title, 'Example');
      expect(breach.domain, isNull);
      expect(breach.breachDate, isNull);
      expect(breach.pwnCount, isNull);
      expect(breach.description, isEmpty);
      expect(breach.dataClasses, isEmpty);
      expect(breach.isVerified, isTrue);
    });

    test('ignores fields with unexpected types', () {
      final breach = Breach.fromJson(const {
        'Name': 'Odd',
        'Domain': '   ',
        'BreachDate': 'not a date',
        'PwnCount': '12',
        'DataClasses': ['Emails', 42, null],
        'IsVerified': 'yes',
      });

      expect(breach.domain, isNull);
      expect(breach.breachDate, isNull);
      expect(breach.pwnCount, isNull);
      expect(breach.dataClasses, ['Emails']);
      expect(breach.isVerified, isTrue);
    });

    test('throws FormatException without a Name', () {
      expect(() => Breach.fromJson(const {'Title': 'No name'}), throwsFormatException);
      expect(() => Breach.fromJson(const {'Name': ''}), throwsFormatException);
      expect(() => Breach.fromJson(const {'Name': 7}), throwsFormatException);
    });
  });
}
