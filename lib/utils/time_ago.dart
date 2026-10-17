/// A short, human description of how long ago [then] was: "just now",
/// "5 min ago", "3 h ago", "2 d ago".
///
/// [now] is passed in (rather than read from the clock) so the result can be
/// tested.
String timeAgo(DateTime then, DateTime now) {
  final difference = now.difference(then);
  if (difference.isNegative || difference.inMinutes < 1) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} h ago';
  return '${difference.inDays} d ago';
}
