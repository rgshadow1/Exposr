import 'dart:convert';

import 'package:breach_checker/models/watch_entry.dart';
import 'package:breach_checker/services/breach_api_service.dart';
import 'package:breach_checker/services/key_value_store.dart';
import 'package:breach_checker/state/watchlist_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  late ScriptedBreachApiService service;
  late MemoryKeyValueStore store;
  late WatchlistController watchlist;
  late DateTime now;

  WatchlistController build() {
    return WatchlistController(service: service, store: store, clock: () => now);
  }

  /// Adds an address and waits for its first check to finish.
  Future<void> addAndWait(String email) async {
    expect(await watchlist.add(email), AddOutcome.added);
    await pumpEventQueue();
  }

  setUp(() {
    service = ScriptedBreachApiService();
    store = MemoryKeyValueStore();
    now = DateTime(2026, 10, 15, 12);
    watchlist = build();
  });

  tearDown(() => watchlist.dispose());

  group('adding', () {
    test('adds a valid address and checks it straight away', () async {
      service.breaches['a@b.co'] = ['Adobe', 'LinkedIn'];

      await addAndWait('a@b.co');

      expect(watchlist.entries, hasLength(1));
      final entry = watchlist.entries.single;
      expect(entry.email, 'a@b.co');
      expect(entry.knownBreaches, ['Adobe', 'LinkedIn']);
      expect(entry.lastChecked, now);
      expect(entry.status, WatchStatus.breached);
    });

    test('trims the address', () async {
      await addAndWait('  a@b.co  ');

      expect(watchlist.entries.single.email, 'a@b.co');
    });

    test('rejects an invalid address without checking it', () async {
      expect(await watchlist.add('not-an-email'), AddOutcome.invalid);

      expect(watchlist.entries, isEmpty);
      expect(service.checked, isEmpty);
    });

    test('rejects a duplicate, ignoring upper and lower case', () async {
      await addAndWait('a@b.co');

      expect(await watchlist.add('A@B.CO'), AddOutcome.duplicate);
      expect(watchlist.entries, hasLength(1));
    });

    test('stops at the maximum number of addresses', () async {
      for (var i = 0; i < WatchlistController.maxEntries; i++) {
        await addAndWait('user$i@example.com');
      }

      expect(await watchlist.add('one-too-many@example.com'), AddOutcome.full);
      expect(watchlist.entries, hasLength(WatchlistController.maxEntries));
    });

    test('a clean address has the clear status', () async {
      await addAndWait('a@b.co');

      expect(watchlist.entries.single.status, WatchStatus.clear);
    });
  });

  group('spotting new breaches', () {
    test('the first check sets a baseline: nothing is "new"', () async {
      service.breaches['a@b.co'] = ['Adobe', 'LinkedIn'];

      await addAndWait('a@b.co');

      expect(watchlist.entries.single.newBreaches, isEmpty);
      expect(watchlist.newBreachCount, 0);
    });

    test('a later check flags only the breaches that weren’t there before', () async {
      service.breaches['a@b.co'] = ['Adobe'];
      await addAndWait('a@b.co');

      service.breaches['a@b.co'] = ['Adobe', 'LinkedIn', 'Dropbox'];
      await watchlist.check('a@b.co');

      final entry = watchlist.entries.single;
      expect(entry.knownBreaches, ['Adobe', 'LinkedIn', 'Dropbox']);
      expect(entry.newBreaches, ['LinkedIn', 'Dropbox']);
      expect(watchlist.newBreachCount, 2);
    });

    test('a clean address that later turns up in a breach is flagged', () async {
      await addAndWait('a@b.co');

      service.breaches['a@b.co'] = ['Adobe'];
      await watchlist.check('a@b.co');

      expect(watchlist.entries.single.newBreaches, ['Adobe']);
    });

    test('comparison ignores upper and lower case in breach names', () async {
      service.breaches['a@b.co'] = ['Adobe'];
      await addAndWait('a@b.co');

      service.breaches['a@b.co'] = ['ADOBE'];
      await watchlist.check('a@b.co');

      expect(watchlist.entries.single.newBreaches, isEmpty);
    });

    test('unacknowledged breaches stay flagged through another check', () async {
      await addAndWait('a@b.co');
      service.breaches['a@b.co'] = ['Adobe'];
      await watchlist.check('a@b.co');

      await watchlist.check('a@b.co');

      expect(watchlist.entries.single.newBreaches, ['Adobe']);
    });

    test('acknowledging clears the flag', () async {
      await addAndWait('a@b.co');
      service.breaches['a@b.co'] = ['Adobe'];
      await watchlist.check('a@b.co');

      await watchlist.acknowledge('a@b.co');

      expect(watchlist.entries.single.newBreaches, isEmpty);
      expect(watchlist.entries.single.knownBreaches, ['Adobe']);
    });
  });

  group('failures', () {
    test('a failed check is recorded and keeps what was known', () async {
      service.breaches['a@b.co'] = ['Adobe'];
      await addAndWait('a@b.co');

      service.failures['a@b.co'] = BreachApiFailure.noConnection;
      await watchlist.check('a@b.co');

      expect(watchlist.failureFor('a@b.co'), BreachApiFailure.noConnection);
      expect(watchlist.entries.single.knownBreaches, ['Adobe']);
    });

    test('a failure on the first check leaves the address unchecked', () async {
      service.failures['a@b.co'] = BreachApiFailure.timeout;

      await addAndWait('a@b.co');

      expect(watchlist.entries.single.status, WatchStatus.notChecked);
      expect(watchlist.failureFor('a@b.co'), BreachApiFailure.timeout);
    });

    test('a later success clears the recorded failure', () async {
      service.failures['a@b.co'] = BreachApiFailure.timeout;
      await addAndWait('a@b.co');

      service.failures.clear();
      await watchlist.check('a@b.co');

      expect(watchlist.failureFor('a@b.co'), isNull);
    });
  });

  group('check all', () {
    test('checks every address', () async {
      await addAndWait('one@example.com');
      await addAndWait('two@example.com');
      service.checked.clear();

      await watchlist.checkAll();

      expect(service.checked, ['one@example.com', 'two@example.com']);
      expect(watchlist.isBusy, isFalse);
    });

    test('stops when the rate limit is hit, leaving the rest alone', () async {
      await addAndWait('one@example.com');
      await addAndWait('two@example.com');
      await addAndWait('three@example.com');
      service.checked.clear();
      service.failures['two@example.com'] = BreachApiFailure.rateLimited;

      await watchlist.checkAll();

      expect(service.checked, ['one@example.com', 'two@example.com']);
      expect(watchlist.failureFor('two@example.com'), BreachApiFailure.rateLimited);
    });
  });

  group('the checklist, removing and clearing', () {
    test('ticks and unticks a task', () async {
      await addAndWait('a@b.co');

      await watchlist.toggleTask('a@b.co', 'two-factor');
      expect(watchlist.entries.single.completedTasks, {'two-factor'});

      await watchlist.toggleTask('a@b.co', 'two-factor');
      expect(watchlist.entries.single.completedTasks, isEmpty);
    });

    test('removes one address', () async {
      await addAndWait('a@b.co');
      await addAndWait('c@d.co');

      await watchlist.remove('a@b.co');

      expect(watchlist.entries.map((e) => e.email), ['c@d.co']);
    });

    test('clearAll forgets everything, including what was saved', () async {
      await addAndWait('a@b.co');

      await watchlist.clearAll();

      expect(watchlist.entries, isEmpty);
      expect(store.getString(WatchlistController.storageKey), isNull);
    });
  });

  group('saving', () {
    test('a new controller loads what an old one saved', () async {
      service.breaches['a@b.co'] = ['Adobe'];
      await addAndWait('a@b.co');
      await watchlist.toggleTask('a@b.co', 'two-factor');

      final reloaded = build();
      addTearDown(reloaded.dispose);

      final entry = reloaded.entries.single;
      expect(entry.email, 'a@b.co');
      expect(entry.knownBreaches, ['Adobe']);
      // Saved as UTC text, so compare the moment in time, not the DateTime object.
      expect(entry.lastChecked!.isAtSameMomentAs(now), isTrue);
      expect(entry.completedTasks, {'two-factor'});
    });

    test('a damaged save is treated as an empty watchlist', () async {
      await store.setString(WatchlistController.storageKey, '{ this is not json');

      final broken = build();
      addTearDown(broken.dispose);

      expect(broken.entries, isEmpty);
    });

    test('entries with odd or missing fields are read safely', () async {
      await store.setString(
        WatchlistController.storageKey,
        jsonEncode([
          {'email': 'ok@example.com', 'knownBreaches': 'not a list', 'lastChecked': 12},
          {'knownBreaches': []}, // no email: dropped
          'not even a map',
        ]),
      );

      final tolerant = build();
      addTearDown(tolerant.dispose);

      expect(tolerant.entries.map((e) => e.email), ['ok@example.com']);
      expect(tolerant.entries.single.knownBreaches, isEmpty);
      expect(tolerant.entries.single.lastChecked, isNull);
    });
  });
}
