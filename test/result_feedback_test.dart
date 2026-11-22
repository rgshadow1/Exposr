import 'dart:async';

import 'package:breach_checker/models/breach.dart';
import 'package:breach_checker/models/email_check_result.dart';
import 'package:breach_checker/services/breach_api_service.dart';
import 'package:breach_checker/services/haptics_service.dart';
import 'package:breach_checker/services/key_value_store.dart';
import 'package:breach_checker/services/sound_service.dart';
import 'package:breach_checker/state/email_check_controller.dart';
import 'package:breach_checker/state/result_feedback.dart';
import 'package:breach_checker/state/settings_controller.dart';
import 'package:breach_checker/state/watchlist_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_breach_api_service.dart';
import 'support/fakes.dart';

void main() {
  late FakeBreachApiService service;
  late EmailCheckController controller;
  late SettingsController settings;
  late FakeHapticsService haptics;
  late FakeSoundService sounds;
  late ResultFeedback feedback;

  ResultFeedback build({HapticsService? hapticsService, SoundService? soundService}) {
    return ResultFeedback(
      controller: controller,
      settings: settings,
      haptics: hapticsService ?? haptics,
      sounds: soundService ?? sounds,
    );
  }

  setUp(() {
    service = FakeBreachApiService();
    controller = EmailCheckController(service);
    settings = SettingsController(MemoryKeyValueStore());
    haptics = FakeHapticsService();
    sounds = FakeSoundService();
    feedback = build();
  });

  tearDown(() {
    feedback.dispose();
    controller.dispose();
    settings.dispose();
  });

  Future<void> finishBreached() async {
    final check = controller.check('a@b.co');
    service.answerBreached('a@b.co', ['Adobe']);
    await check;
  }

  Future<void> finishClean() async {
    final check = controller.check('a@b.co');
    service.answerClean('a@b.co');
    await check;
  }

  group('by default (haptics on, sounds on)', () {
    test('the sounds are loaded as soon as the feedback is set up', () {
      expect(sounds.warmUps, 1);
    });

    test('breaches found: the warning haptic and the breach sound', () async {
      await finishBreached();

      expect(haptics.calls, ['breached']);
      expect(sounds.played, ['breached']);
    });

    test('no known breaches: the success haptic and the confirmation sound', () async {
      await finishClean();

      expect(haptics.calls, ['clean']);
      expect(sounds.played, ['clean']);
    });

    test('sound alone, when haptics are switched off', () async {
      await settings.setHapticsEnabled(false);

      await finishBreached();

      expect(haptics.calls, isEmpty);
      expect(sounds.played, ['breached']);
    });
  });

  group('with result sounds switched off', () {
    setUp(() => settings.setSoundsEnabled(false));

    test('breaches found: the warning haptic and no sound', () async {
      await finishBreached();

      expect(haptics.calls, ['breached']);
      expect(sounds.played, isEmpty);
    });

    test('no known breaches: the success haptic and no sound', () async {
      await finishClean();

      expect(haptics.calls, ['clean']);
      expect(sounds.played, isEmpty);
    });

    test('switching them back on loads them again', () async {
      final before = sounds.warmUps;

      await settings.setSoundsEnabled(true);

      expect(sounds.warmUps, before + 1);
    });

    test('sounds saved as off are not even loaded when the app opens', () async {
      final saved = MemoryKeyValueStore();
      await saved.setBool('settings.sounds', false);
      final savedOff = SettingsController(saved);
      final quiet = FakeSoundService();
      final local = ResultFeedback(
        controller: controller,
        settings: savedOff,
        haptics: haptics,
        sounds: quiet,
      );
      addTearDown(() {
        local.dispose();
        savedOff.dispose();
      });

      expect(quiet.warmUps, 0);
    });
  });

  group('a failed check', () {
    for (final failure in BreachApiFailure.values) {
      test('${failure.name}: no haptic and no sound, and never the success ones', () async {
        final check = controller.check('a@b.co');
        service.failCheck(failure);
        await check;

        expect(controller.state, isA<LookupFailed>());
        expect(haptics.calls, isEmpty);
        expect(sounds.played, isEmpty);
      });
    }

    test('a retry that then succeeds gives feedback once, for the success', () async {
      final first = controller.check('a@b.co');
      service.failCheck(BreachApiFailure.timeout);
      await first;

      await finishClean();

      expect(haptics.calls, ['clean']);
      expect(sounds.played, ['clean']);
    });
  });

  group('settings', () {
    test('nothing at all when both are switched off', () async {
      await settings.setHapticsEnabled(false);
      await settings.setSoundsEnabled(false);

      await finishBreached();

      expect(haptics.calls, isEmpty);
      expect(sounds.played, isEmpty);
    });

    test('a change takes effect on the very next check', () async {
      await finishBreached();
      await settings.setHapticsEnabled(false);
      controller.reset();

      await finishBreached();

      expect(haptics.calls, ['breached']); // only the first one
    });
  });

  group('exactly once per completed check', () {
    test('nothing while the check is still running', () {
      controller.check('a@b.co');

      expect(haptics.calls, isEmpty);
      expect(sounds.played, isEmpty);
    });

    test('loading the details afterwards does not repeat it', () async {
      await finishBreached();

      final details = controller.loadDetails();
      service.answerDetails([sampleBreach]);
      await details;

      expect(haptics.calls, ['breached']);
      expect(sounds.played, ['breached']);
    });

    test('a failed details request does not give feedback either', () async {
      await finishBreached();

      final details = controller.loadDetails();
      service.failDetails(BreachApiFailure.rateLimited);
      await details;

      expect(haptics.calls, ['breached']);
    });

    test('clearing the screen does not repeat it', () async {
      await finishBreached();

      controller.reset();
      controller.wipe();

      expect(haptics.calls, ['breached']);
      expect(sounds.played, ['breached']);
    });

    test('listeners being notified again (a rebuild) does not repeat it', () async {
      await finishBreached();

      // Whatever redraws the screen calls listeners; none of it is a completion.
      controller.inputWipes.value++;
      await settings.setShakeToHideEnabled(true);
      await pumpEventQueue();

      expect(haptics.calls, ['breached']);
      expect(sounds.played, ['breached']);
    });

    test('two checks give two rounds of feedback, one each', () async {
      await finishBreached();
      await finishClean();

      expect(haptics.calls, ['breached', 'clean']);
      expect(sounds.played, ['breached', 'clean']);
    });
  });

  group('cancelled and stale checks', () {
    test('a reply that arrives after the check was cleared gives nothing', () async {
      final check = controller.check('a@b.co');
      controller.reset(); // the user edited the address, or shook to hide
      service.answerBreached('a@b.co', ['Adobe']);
      await check;

      expect(controller.state, isA<LookupIdle>());
      expect(haptics.calls, isEmpty);
    });

    test('a failure that arrives after the check was cleared gives nothing', () async {
      final check = controller.check('a@b.co');
      controller.reset();
      service.failCheck(BreachApiFailure.noConnection);
      await check;

      expect(haptics.calls, isEmpty);
    });

    test('only the newer of two searches gives feedback', () async {
      // The first search is still out when the user starts over with another.
      final manual = _TwoStepService();
      final lookup = EmailCheckController(manual);
      final local = ResultFeedback(
        controller: lookup,
        settings: settings,
        haptics: haptics,
        sounds: sounds,
      );
      addTearDown(() {
        local.dispose();
        lookup.dispose();
      });

      final first = lookup.check('old@b.co');
      lookup.reset();
      final second = lookup.check('new@b.co');

      // The old reply lands last, and says the opposite of the new one.
      manual.answer('new@b.co', clean: true);
      await second;
      manual.answer('old@b.co', clean: false);
      await first;

      expect(lookup.state, isA<LookupClean>());
      expect(haptics.calls, ['clean']);
    });

    test('nothing after the feedback is disposed', () async {
      feedback.dispose();

      await finishBreached();

      expect(haptics.calls, isEmpty);
    });
  });

  test('a Watchlist check is a background refresh and gives no feedback', () async {
    final scripted = ScriptedBreachApiService()..breaches['a@b.co'] = ['Adobe'];
    final watchlist = WatchlistController(service: scripted, store: MemoryKeyValueStore());
    addTearDown(watchlist.dispose);

    await watchlist.add('a@b.co');
    await pumpEventQueue();
    await watchlist.checkAll();

    expect(watchlist.entries.single.knownBreaches, ['Adobe']);
    expect(haptics.calls, isEmpty);
    expect(sounds.played, isEmpty);
  });

  group('devices that cannot give feedback', () {
    test('no haptics are asked for where they are not supported', () async {
      final unsupported = FakeHapticsService(supported: false);
      feedback.dispose();
      feedback = build(hapticsService: unsupported);

      await finishBreached();

      expect(unsupported.calls, isEmpty);
      expect(feedback.hapticsSupported, isFalse);
      expect(feedback.hapticsActive, isFalse);
      // The result itself is unaffected.
      expect(controller.state, isA<LookupBreached>());
    });

    test('a haptic or sound that throws never disturbs the result', () async {
      feedback.dispose();
      feedback = build(hapticsService: _BrokenHaptics(), soundService: _BrokenSounds());

      await finishBreached();
      await pumpEventQueue();

      expect(controller.state, isA<LookupBreached>());
    });
  });

  group('previews', () {
    test('play what a real result would, with the switches as they are', () async {
      feedback.give(CheckOutcome.breached);
      feedback.give(CheckOutcome.clean);

      expect(haptics.calls, ['breached', 'clean']);
      expect(sounds.played, ['breached', 'clean']);
    });

    test('play only the channel that is switched on', () async {
      await settings.setHapticsEnabled(false);

      feedback.give(CheckOutcome.clean);

      expect(haptics.calls, isEmpty);
      expect(sounds.played, ['clean']);
      expect(feedback.isActive, isTrue);
    });

    test('play nothing when both are switched off', () async {
      await settings.setHapticsEnabled(false);
      await settings.setSoundsEnabled(false);

      feedback.give(CheckOutcome.clean);

      expect(haptics.calls, isEmpty);
      expect(sounds.played, isEmpty);
      expect(feedback.isActive, isFalse);
    });
  });
}

/// Holds several requests open at once, so the test can answer them out of order.
class _TwoStepService implements BreachApiService {
  final Map<String, Completer<EmailCheckResult>> _pending = {};

  @override
  Future<EmailCheckResult> checkEmail(String email) {
    return (_pending[email] = Completer<EmailCheckResult>()).future;
  }

  void answer(String email, {required bool clean}) {
    _pending.remove(email)!.complete(
          clean ? EmailClean(email) : EmailBreached(email, const ['Adobe']),
        );
  }

  @override
  Future<List<Breach>> fetchBreachDetails(String email) async => const [];

  @override
  void close() {}
}

class _BrokenHaptics implements HapticsService {
  @override
  bool get isSupported => true;

  @override
  Future<void> breached() => throw StateError('no haptic engine');

  @override
  Future<void> clean() => Future.error(StateError('no haptic engine'));
}

class _BrokenSounds implements SoundService {
  @override
  Future<void> warmUp() => Future.error(StateError('no audio device'));

  @override
  Future<void> breached() => Future.error(StateError('no audio device'));

  @override
  Future<void> clean() => throw StateError('no audio device');

  @override
  Future<void> dispose() async {}
}
