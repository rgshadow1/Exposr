/// Formats a whole number with thousands separators: 152445165 -> "152,445,165".
///
/// Written by hand because the only alternative is the `intl` package, which
/// is a lot of weight for one comma-inserting loop.
String formatCount(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    // A comma goes before every group of three digits counted from the right.
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// A short form for tight spaces: 152445165 -> "152.4M", 12000 -> "12K".
String formatCompact(int value) {
  if (value >= 1000000000) return '${_oneDecimal(value / 1000000000)}B';
  if (value >= 1000000) return '${_oneDecimal(value / 1000000)}M';
  if (value >= 1000) return '${_oneDecimal(value / 1000)}K';
  return value.toString();
}

/// One decimal place, dropping a trailing ".0": 12.0 -> "12", 152.44 -> "152.4".
String _oneDecimal(double value) {
  final text = value.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}
