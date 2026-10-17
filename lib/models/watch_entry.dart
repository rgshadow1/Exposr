/// How a watched address looked the last time it was checked.
enum WatchStatus { notChecked, clear, breached }

/// One address on the watchlist, and what we know about it.
///
/// Immutable: to change something, make a copy with [copyWith]. The controller
/// then swaps the old entry for the new one, which keeps the screen's "one value
/// in, one picture out" rule.
class WatchEntry {
  const WatchEntry({
    required this.email,
    this.knownBreaches = const [],
    this.newBreaches = const [],
    this.lastChecked,
    this.completedTasks = const {},
  });

  final String email;

  /// Every breach found the last time the address was checked.
  final List<String> knownBreaches;

  /// Breaches that appeared after an earlier check and haven't been
  /// acknowledged yet. The first check of an address sets the baseline and
  /// produces none.
  final List<String> newBreaches;

  /// When the address was last checked successfully. Null until it has been.
  final DateTime? lastChecked;

  /// Ids of the remediation tasks the user has ticked off.
  final Set<String> completedTasks;

  WatchStatus get status {
    if (lastChecked == null) return WatchStatus.notChecked;
    return knownBreaches.isEmpty ? WatchStatus.clear : WatchStatus.breached;
  }

  WatchEntry copyWith({
    List<String>? knownBreaches,
    List<String>? newBreaches,
    DateTime? lastChecked,
    Set<String>? completedTasks,
  }) {
    return WatchEntry(
      email: email,
      knownBreaches: knownBreaches ?? this.knownBreaches,
      newBreaches: newBreaches ?? this.newBreaches,
      lastChecked: lastChecked ?? this.lastChecked,
      completedTasks: completedTasks ?? this.completedTasks,
    );
  }

  Map<String, Object?> toJson() => {
        'email': email,
        'knownBreaches': knownBreaches,
        'newBreaches': newBreaches,
        'lastChecked': lastChecked?.toUtc().toIso8601String(),
        'completedTasks': completedTasks.toList(),
      };

  /// Reads an entry back from storage, tolerating missing or odd fields so a
  /// bad save can never crash the app.
  factory WatchEntry.fromJson(Map<String, Object?> json) {
    List<String> strings(Object? value) {
      if (value is! List) return const [];
      return [
        for (final item in value)
          if (item is String) item,
      ];
    }

    final checked = json['lastChecked'];
    final email = json['email'];

    return WatchEntry(
      email: email is String ? email : '',
      knownBreaches: strings(json['knownBreaches']),
      newBreaches: strings(json['newBreaches']),
      lastChecked: checked is String ? DateTime.tryParse(checked) : null,
      completedTasks: strings(json['completedTasks']).toSet(),
    );
  }
}
