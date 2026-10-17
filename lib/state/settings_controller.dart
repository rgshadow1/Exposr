import 'package:flutter/foundation.dart';

import '../services/key_value_store.dart';

/// The user's choices, saved on the device.
///
/// A [ChangeNotifier] like the other controllers: each setter updates the value,
/// tells listeners, then saves. The screen updates instantly and the save
/// happens in the background.
class SettingsController extends ChangeNotifier {
  SettingsController(this._store) {
    _hapticsEnabled = _store.getBool(_hapticsKey) ?? true;
    _shakeToHideEnabled = _store.getBool(_shakeKey) ?? false;
    _lockEnabled = _store.getBool(_lockKey) ?? false;
  }

  static const String _hapticsKey = 'settings.haptics';
  static const String _shakeKey = 'settings.shakeToHide';
  static const String _lockKey = 'settings.appLock';

  final KeyValueStore _store;

  bool _hapticsEnabled = true;
  bool _shakeToHideEnabled = false;
  bool _lockEnabled = false;

  /// Vibrate when a check finishes.
  bool get hapticsEnabled => _hapticsEnabled;

  /// Clear the address and results when the phone is shaken.
  bool get shakeToHideEnabled => _shakeToHideEnabled;

  /// Ask for fingerprint, face or PIN when the app opens.
  bool get lockEnabled => _lockEnabled;

  Future<void> setHapticsEnabled(bool value) async {
    if (_hapticsEnabled == value) return;
    _hapticsEnabled = value;
    notifyListeners();
    await _store.setBool(_hapticsKey, value);
  }

  Future<void> setShakeToHideEnabled(bool value) async {
    if (_shakeToHideEnabled == value) return;
    _shakeToHideEnabled = value;
    notifyListeners();
    await _store.setBool(_shakeKey, value);
  }

  Future<void> setLockEnabled(bool value) async {
    if (_lockEnabled == value) return;
    _lockEnabled = value;
    notifyListeners();
    await _store.setBool(_lockKey, value);
  }

  /// Back to the defaults, and forget the saved choices.
  Future<void> resetToDefaults() async {
    _hapticsEnabled = true;
    _shakeToHideEnabled = false;
    _lockEnabled = false;
    notifyListeners();
    await _store.remove(_hapticsKey);
    await _store.remove(_shakeKey);
    await _store.remove(_lockKey);
  }
}
