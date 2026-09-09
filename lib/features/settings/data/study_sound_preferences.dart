import 'package:shared_preferences/shared_preferences.dart';

/// Device-local storage for the opt-in study-sound preference.
///
/// Sounds default to off and are not synced between devices. The optional
/// [SharedPreferences] instance keeps storage injectable without coupling
/// playback code to the preference package.
class StudySoundPreferences {
  StudySoundPreferences([SharedPreferences? prefs]) : _injected = prefs;

  static const String _key = 'study_sounds_enabled';

  final SharedPreferences? _injected;

  Future<SharedPreferences> get _prefs async =>
      _injected ?? await SharedPreferences.getInstance();

  Future<bool> isEnabled() async => (await _prefs).getBool(_key) ?? false;

  Future<void> setEnabled(bool value) async {
    final stored = await (await _prefs).setBool(_key, value);
    if (!stored) {
      throw StateError('Could not persist the study-sound preference.');
    }
  }
}
