import 'package:breach_checker/services/key_value_store.dart';
import 'package:breach_checker/state/settings_controller.dart';
import 'package:breach_checker/state/shake_to_hide.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  late SettingsController settings;
  late FakeShakeSource source;
  late int shakes;
  late ShakeToHide shakeToHide;

  setUp(() {
    settings = SettingsController(MemoryKeyValueStore());
    source = FakeShakeSource();
    shakes = 0;
    shakeToHide = ShakeToHide(source: source, settings: settings, onShake: () => shakes++);
  });

  tearDown(() {
    shakeToHide.dispose();
    settings.dispose();
  });

  test('does nothing, and does not read the sensor, while the setting is off', () async {
    expect(source.hasListener, isFalse);

    source.shake();
    await pumpEventQueue();

    expect(shakes, 0);
  });

  test('reacts to a shake once the setting is on', () async {
    await settings.setShakeToHideEnabled(true);
    expect(source.hasListener, isTrue);

    source.shake();
    await pumpEventQueue();

    expect(shakes, 1);
  });

  test('stops listening as soon as the setting goes off again', () async {
    await settings.setShakeToHideEnabled(true);
    await settings.setShakeToHideEnabled(false);

    expect(source.hasListener, isFalse);

    source.shake();
    await pumpEventQueue();

    expect(shakes, 0);
  });

  test('is already listening if the setting was saved as on', () async {
    final store = MemoryKeyValueStore();
    await store.setBool('settings.shakeToHide', true);
    final saved = SettingsController(store);
    final other = FakeShakeSource();

    final started = ShakeToHide(source: other, settings: saved, onShake: () => shakes++);
    addTearDown(started.dispose);

    expect(other.hasListener, isTrue);
  });
}
