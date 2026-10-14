/// Email address validation.
///
/// This is deliberately practical rather than a full RFC 5322 parser: it
/// accepts the addresses people actually use and rejects obvious typos
/// before we spend an API request on them. HIBP does its own validation too.
abstract final class EmailValidator {
  static const int _maxLength = 254;
  static const int _maxLocalLength = 64;
  static const int _maxLabelLength = 63;

  static final RegExp _localPart = RegExp(r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~.-]+$");
  static final RegExp _domainLabel = RegExp(r'^[A-Za-z0-9-]+$');
  static final RegExp _topLevelDomain = RegExp(r'^(?:[A-Za-z]{2,}|xn--[A-Za-z0-9-]+)$');

  static bool isValid(String input) => validate(input) == null;

  /// Returns null when [input] is valid, otherwise a short message suitable
  /// for showing under the text field.
  static String? validate(String? input) {
    final email = input?.trim() ?? '';

    if (email.isEmpty) return 'Enter an email address.';
    if (email.length > _maxLength) return 'That email address is too long.';

    final at = email.indexOf('@');
    if (at == -1 || at != email.lastIndexOf('@')) {
      return 'Enter a valid email address, like name@example.com.';
    }

    final local = email.substring(0, at);
    final domain = email.substring(at + 1);

    if (!_isValidLocalPart(local) || !_isValidDomain(domain)) {
      return 'Enter a valid email address, like name@example.com.';
    }
    return null;
  }

  static bool _isValidLocalPart(String local) {
    if (local.isEmpty || local.length > _maxLocalLength) return false;
    if (local.startsWith('.') || local.endsWith('.')) return false;
    if (local.contains('..')) return false;
    return _localPart.hasMatch(local);
  }

  static bool _isValidDomain(String domain) {
    final labels = domain.split('.');
    if (labels.length < 2) return false;

    for (final label in labels) {
      if (label.isEmpty || label.length > _maxLabelLength) return false;
      if (label.startsWith('-') || label.endsWith('-')) return false;
      if (!_domainLabel.hasMatch(label)) return false;
    }
    return _topLevelDomain.hasMatch(labels.last);
  }
}
