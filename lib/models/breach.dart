/// How well the passwords in a breach were protected, as XposedOrNot reports it.
enum PasswordRisk { plaintext, easyToCrack, hardToCrack, none, unknown }

/// One data breach, as described by XposedOrNot's breach-analytics endpoint.
///
/// Everything except [name] is optional because the API leaves fields out or
/// sends them in different shapes (a number as text, for example). The parser
/// below accepts all of that instead of crashing on a surprise.
class Breach {
  const Breach({
    required this.name,
    this.domain,
    this.industry,
    this.date,
    this.records,
    this.exposedData = const [],
    this.passwordRisk = PasswordRisk.unknown,
    this.description,
    this.verified = false,
  });

  /// Builds a [Breach] from one entry of `ExposedBreaches.breaches_details`.
  factory Breach.fromJson(Map<String, dynamic> json) {
    String? text(String key) {
      final value = json[key];
      if (value == null) return null;
      final trimmed = value.toString().trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final description = text('details');

    return Breach(
      name: text('breach') ?? 'Unknown breach',
      domain: text('domain'),
      industry: text('industry'),
      date: text('xposed_date'),
      // Accepts 152445165, "152445165" and "152,445,165".
      records: int.tryParse((text('xposed_records') ?? '').replaceAll(',', '')),
      exposedData: _splitList(text('xposed_data')),
      passwordRisk: _parseRisk(text('password_risk')),
      description: description == null ? null : _plainText(description),
      verified: const {'yes', 'true'}.contains(text('verified')?.toLowerCase()),
    );
  }

  final String name;
  final String? domain;
  final String? industry;

  /// The date as the API sent it (usually just a year such as "2013").
  final String? date;

  /// How many records were exposed, when known.
  final int? records;

  /// Kinds of data exposed, such as "Email addresses" or "Passwords".
  final List<String> exposedData;

  final PasswordRisk passwordRisk;

  /// Plain-text summary. Any HTML the API sent has been removed.
  final String? description;

  final bool verified;

  /// The four-digit year at the start of [date], if there is one.
  int? get year {
    final match = RegExp(r'^\s*(\d{4})').firstMatch(date ?? '');
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static List<String> _splitList(String? raw) {
    if (raw == null) return const [];
    return [
      for (final part in raw.split(RegExp(r'[;,]')))
        if (part.trim().isNotEmpty) part.trim(),
    ];
  }

  static PasswordRisk _parseRisk(String? raw) {
    if (raw == null) return PasswordRisk.none;
    // "Easy to crack", "easytocrack" and "EasyToCrack" all become one key.
    switch (raw.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')) {
      case 'plaintext':
        return PasswordRisk.plaintext;
      case 'easytocrack':
        return PasswordRisk.easyToCrack;
      case 'hardtocrack':
        return PasswordRisk.hardToCrack;
      case 'unknown':
        return PasswordRisk.unknown;
      default:
        return PasswordRisk.unknown;
    }
  }

  /// Descriptions can arrive as HTML. The app only ever shows plain text, so
  /// tags are dropped and the common entities are decoded.
  static String _plainText(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
