import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/email_check_result.dart';
import '../models/watch_entry.dart';
import '../services/breach_api_service.dart';
import '../services/key_value_store.dart';
import '../utils/email_validator.dart';

/// What happened when someone tried to add an address.
enum AddOutcome { added, duplicate, invalid, full }

/// The addresses the user has chosen to keep an eye on.
///
/// Opt-in and local: an address is saved only because the user added it, it is
/// stored on this device only, and it can be removed at any time. Each check
/// sends the address to XposedOrNot, exactly as a check on the Home tab does.
///
/// The interesting part is the diff. The first check of an address records a
/// baseline. Later checks compare against it, and any breach that wasn't there
/// before is flagged as new until the user acknowledges it.
class WatchlistController extends ChangeNotifier {
  WatchlistController({
    required BreachApiService service,
    required KeyValueStore store,
    DateTime Function()? clock,
    Duration pause = Duration.zero,
  })  : _service = service,
        _store = store,
        _clock = clock ?? DateTime.now,
        _pause = pause {
    _load();
  }

  /// A small cap keeps "check all" well inside XposedOrNot's free hourly limit.
  static const int maxEntries = 10;

  static const String storageKey = 'watchlist.v1';

  final BreachApiService _service;
  final KeyValueStore _store;
  final DateTime Function() _clock;
  final Duration _pause;

  List<WatchEntry> _entries = const [];
  final Set<String> _checking = {};
  final Map<String, BreachApiFailure> _failures = {};
  bool _checkingAll = false;
  bool _disposed = false;

  List<WatchEntry> get entries => List.unmodifiable(_entries);

  /// True while any address is being checked.
  bool get isBusy => _checking.isNotEmpty || _checkingAll;

  bool isChecking(String email) => _checking.contains(_canonical(email));

  /// Why the last check of [email] failed, or null if it didn't.
  BreachApiFailure? failureFor(String email) => _failures[_canonical(email)];

  /// How many unacknowledged new breaches there are across the whole list.
  int get newBreachCount => _entries.fold<int>(0, (sum, entry) => sum + entry.newBreaches.length);

  String _canonical(String email) {
    final index = _indexOf(email);
    return index == -1 ? email.trim() : _entries[index].email;
  }

  int _indexOf(String email) {
    final wanted = email.trim().toLowerCase();
    return _entries.indexWhere((entry) => entry.email.toLowerCase() == wanted);
  }

  void _load() {
    final raw = _store.getString(storageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _entries = [
        for (final item in decoded)
          if (item is Map<String, Object?>) WatchEntry.fromJson(item),
      ].where((entry) => entry.email.isNotEmpty).toList();
    } catch (_) {
      // A damaged save is treated as an empty watchlist.
      _entries = const [];
    }
  }

  Future<void> _persist() async {
    await _store.setString(
      storageKey,
      jsonEncode([for (final entry in _entries) entry.toJson()]),
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Adds an address and starts its first check, which sets the baseline.
  Future<AddOutcome> add(String input) async {
    final email = input.trim();
    if (EmailValidator.validate(email) != null) return AddOutcome.invalid;
    if (_indexOf(email) != -1) return AddOutcome.duplicate;
    if (_entries.length >= maxEntries) return AddOutcome.full;

    _entries = [..._entries, WatchEntry(email: email)];
    _notify();
    await _persist();
    unawaited(check(email));
    return AddOutcome.added;
  }

  /// Checks one address and records what changed.
  Future<void> check(String email) async {
    final index = _indexOf(email);
    if (index == -1) return;
    final key = _entries[index].email;
    if (_checking.contains(key)) return;

    _checking.add(key);
    _failures.remove(key);
    _notify();

    try {
      final result = await _service.checkEmail(key);
      final names = switch (result) {
        EmailBreached(:final breachNames) => breachNames,
        EmailClean() => const <String>[],
      };
      _applyResult(key, names);
    } on BreachApiException catch (error) {
      _failures[key] = error.failure;
    } catch (_) {
      _failures[key] = BreachApiFailure.unexpectedResponse;
    } finally {
      _checking.remove(key);
    }

    _notify();
    await _persist();
  }

  void _applyResult(String key, List<String> names) {
    final index = _indexOf(key);
    if (index == -1) return; // removed while the request was running

    final entry = _entries[index];
    final isBaseline = entry.lastChecked == null;
    final known = entry.knownBreaches.map((name) => name.toLowerCase()).toSet();

    final fresh = isBaseline
        ? const <String>[]
        : [
            for (final name in names)
              if (!known.contains(name.toLowerCase())) name,
          ];

    // Keep earlier unacknowledged ones, add the newly found, drop duplicates.
    final unseen = <String>{...entry.newBreaches, ...fresh}.toList();

    final updated = entry.copyWith(
      knownBreaches: names,
      newBreaches: unseen,
      lastChecked: _clock(),
    );
    _entries = [..._entries]..[index] = updated;
  }

  /// Checks every address one after another, pausing between requests to stay
  /// under the service's rate limit, and stopping early if the limit is hit.
  Future<void> checkAll() async {
    if (_checkingAll) return;
    _checkingAll = true;
    _notify();

    try {
      final emails = [for (final entry in _entries) entry.email];
      for (var i = 0; i < emails.length; i++) {
        if (_disposed) return;
        if (i > 0 && _pause > Duration.zero) {
          await Future<void>.delayed(_pause);
        }
        await check(emails[i]);
        if (_failures[emails[i]] == BreachApiFailure.rateLimited) break;
      }
    } finally {
      _checkingAll = false;
      _notify();
    }
  }

  /// "Got it": the user has seen the new breaches for this address.
  Future<void> acknowledge(String email) => _update(email, (entry) => entry.copyWith(newBreaches: const []));

  /// Ticks or unticks a remediation task.
  Future<void> toggleTask(String email, String taskId) {
    return _update(email, (entry) {
      final done = {...entry.completedTasks};
      if (!done.remove(taskId)) done.add(taskId);
      return entry.copyWith(completedTasks: done);
    });
  }

  Future<void> remove(String email) async {
    final index = _indexOf(email);
    if (index == -1) return;
    final key = _entries[index].email;
    _entries = [..._entries]..removeAt(index);
    _failures.remove(key);
    _notify();
    await _persist();
  }

  /// Forgets every address and deletes the saved list.
  Future<void> clearAll() async {
    _entries = const [];
    _failures.clear();
    _notify();
    await _store.remove(storageKey);
  }

  Future<void> _update(String email, WatchEntry Function(WatchEntry) change) async {
    final index = _indexOf(email);
    if (index == -1) return;
    _entries = [..._entries]..[index] = change(_entries[index]);
    _notify();
    await _persist();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
