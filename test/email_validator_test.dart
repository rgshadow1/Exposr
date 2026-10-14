import 'package:breach_checker/utils/email_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmailValidator', () {
    test('accepts common valid addresses', () {
      const valid = [
        'name@example.com',
        'first.last@example.co.uk',
        'user+tag@sub.example.org',
        "o'brien@example.ie",
        'a@b.io',
        'user@xn--bcher-kva.example',
        '  padded@example.com  ', // surrounding whitespace is trimmed
      ];
      for (final email in valid) {
        expect(EmailValidator.validate(email), isNull, reason: email);
      }
    });

    test('rejects invalid addresses', () {
      const invalid = [
        'plainaddress',
        '@example.com',
        'name@',
        'name@example',
        'name@@example.com',
        'na@me@example.com',
        '.name@example.com',
        'name.@example.com',
        'na..me@example.com',
        'name@-example.com',
        'name@example-.com',
        'name@exa mple.com',
        'name@example.c',
        'name@example.123',
        'name@example..com',
      ];
      for (final email in invalid) {
        expect(EmailValidator.validate(email), isNotNull, reason: email);
      }
    });

    test('empty and null input get a specific message', () {
      expect(EmailValidator.validate(''), 'Enter an email address.');
      expect(EmailValidator.validate('   '), 'Enter an email address.');
      expect(EmailValidator.validate(null), 'Enter an email address.');
    });

    test('enforces length limits', () {
      final longLocal = '${'a' * 65}@example.com';
      expect(EmailValidator.isValid(longLocal), isFalse);

      final tooLong = '${'a' * 64}@${'b' * 63}.${'c' * 63}.${'d' * 63}.com';
      expect(tooLong.length, greaterThan(254));
      expect(EmailValidator.validate(tooLong), 'That email address is too long.');
    });
  });
}
