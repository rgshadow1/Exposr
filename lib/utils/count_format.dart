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
