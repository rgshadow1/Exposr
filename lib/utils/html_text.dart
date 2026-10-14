/// Converts the small amount of HTML in HIBP breach descriptions into plain
/// text.
///
/// HIBP descriptions contain simple markup (`<em>`, `<strong>`, `<a>`), so
/// rendering them properly would mean adding an HTML-rendering package. Plain
/// text is enough here, and displaying text instead of interpreting markup
/// means nothing in the API response can inject links or styling into the UI.
abstract final class HtmlText {
  static final RegExp _lineBreakTags = RegExp(
    r'<\s*br\s*/?\s*>|<\s*/\s*(p|div|li)\s*>',
    caseSensitive: false,
  );
  static final RegExp _anyTag = RegExp(r'<[^>]*>');
  static final RegExp _entity = RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);');
  static final RegExp _spacesAndTabs = RegExp(r'[ \t\f\r]+');
  static final RegExp _spaceAroundNewline = RegExp(r' *\n *');
  static final RegExp _manyNewlines = RegExp(r'\n{3,}');

  static const Map<String, String> _namedEntities = {
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': ' ',
    'ndash': '–',
    'mdash': '—',
    'hellip': '…',
    'rsquo': '’',
    'lsquo': '‘',
    'rdquo': '”',
    'ldquo': '“',
  };

  static String toPlainText(String html) {
    var text = html.replaceAll(_lineBreakTags, '\n');
    text = text.replaceAll(_anyTag, '');
    // Entities are decoded after tags are removed, so an encoded "&lt;b&gt;"
    // ends up as the visible text "<b>" rather than being treated as a tag.
    text = text.replaceAllMapped(_entity, (match) => _decodeEntity(match));
    text = text
        .replaceAll(_spacesAndTabs, ' ')
        .replaceAll(_spaceAroundNewline, '\n')
        .replaceAll(_manyNewlines, '\n\n');
    return text.trim();
  }

  static String _decodeEntity(Match match) {
    final body = match.group(1)!;
    final original = match.group(0)!;

    if (body.startsWith('#')) {
      final isHex = body.length > 1 && (body[1] == 'x' || body[1] == 'X');
      final code = int.tryParse(
        isHex ? body.substring(2) : body.substring(1),
        radix: isHex ? 16 : 10,
      );
      if (code == null || code <= 0 || code > 0x10FFFF) return original;
      return String.fromCharCode(code);
    }
    return _namedEntities[body.toLowerCase()] ?? original;
  }
}
