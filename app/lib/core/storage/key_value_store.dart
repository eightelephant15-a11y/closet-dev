import 'package:shared_preferences/shared_preferences.dart';

/// Small string store used for local persistence (resume state, outbox, mock data).
abstract class KeyValueStore {
  String? read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class PrefsKeyValueStore implements KeyValueStore {
  PrefsKeyValueStore(this._prefs);
  final SharedPreferences _prefs;

  @override
  String? read(String key) => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _data = {};

  @override
  String? read(String key) => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> remove(String key) async => _data.remove(key);
}
