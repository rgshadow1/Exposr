import 'package:breach_checker/services/key_value_store.dart';
import 'package:breach_checker/state/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryKeyValueStore store;

  setUp(() => store = MemoryKeyValueStore());

  test('starts with haptics on, shake-to-hide off and the lock off', () {
    final settings = SettingsController(store);

    expect(settings.hapticsEnabled, isTrue);
    expect(settings.shakeToHideEnabled, isFalse);
    expect(settings.lockEnabled, isFalse);
  });

  test('a change notifies listeners and is saved', () async {
    final settings = SettingsController(store);
    var notified = 0;
    settings.addListener(() => notified++);

    await settings.setHapticsEnabled(false);
    await settings.setShakeToHideEnabled(true);
    await settings.setLockEnabled(true);

    expect(notified, 3);
    expect(store.getBool('settings.haptics'), isFalse);
    expect(store.getBool('settings.shakeToHide'), isTrue);
    expect(store.getBool('settings.appLock'), isTrue);
  });

  test('setting the value it already has does nothing', () async {
    final settings = SettingsController(store);
    var notified = 0;
    settings.addListener(() => notified++);

    await settings.setHapticsEnabled(true);

    expect(notified, 0);
  });

  test('a new controller reads back what an old one saved', () async {
    final first = SettingsController(store);
    await first.setHapticsEnabled(false);
    await first.setShakeToHideEnabled(true);

    final second = SettingsController(store);

    expect(second.hapticsEnabled, isFalse);
    expect(second.shakeToHideEnabled, isTrue);
  });

  test('resetToDefaults restores the defaults and forgets the saved values', () async {
    final settings = SettingsController(store);
    await settings.setHapticsEnabled(false);
    await settings.setShakeToHideEnabled(true);
    await settings.setLockEnabled(true);

    await settings.resetToDefaults();

    expect(settings.hapticsEnabled, isTrue);
    expect(settings.shakeToHideEnabled, isFalse);
    expect(settings.lockEnabled, isFalse);
    expect(store.getBool('settings.haptics'), isNull);
    expect(store.getBool('settings.shakeToHide'), isNull);
    expect(store.getBool('settings.appLock'), isNull);
  });
}
