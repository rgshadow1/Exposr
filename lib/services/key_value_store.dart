import 'package:shared_preferences/shared_preferences.dart';

/// The little bit of local storage the app needs: a few settings and the
/// watchlist.
///
/// It is an interface so tests can use [MemoryKeyValueStore] and never touch
/// the real device storage.
abstract interface class KeyValueStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
  bool? getBool(String key);
  Future<void> setBool(String key, bool value);
  Future<void> remove(String key);
}

/// Keeps values in a map. Used by tests, and as the default when no real store
/// is supplied.
class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, Object> _values = {};

  @override
  String? getString(String key) {
    final value = _values[key];
    return value is String ? value : null;
  }

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }

  @override
  bool? getBool(String key) {
    final value = _values[key];
    return value is bool ? value : null;
  }

  @override
  Future<void> setBool(String key, bool value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}

/// Stores values with the `shared_preferences` package: a small key-value file
/// in the app's private storage. It is not encrypted, which is why the watchlist
/// holds only email addresses and breach names, and nothing secret.
class SharedPrefsKeyValueStore implements KeyValueStore {
  SharedPrefsKeyValueStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }
}
