import 'package:shared_preferences/shared_preferences.dart';

/// Device-local store for the **last-used** Feynman timer preset, in seconds.
///
/// The preset is chosen per-session (ui-spec-v1 §6.2.1), never forced as a
/// default — this only records the most recent choice so the Settings screen
/// can show it as information (§6.5). Per-device, not synced, so
/// `SharedPreferences` rather than `profiles`.
class FeynmanTimerPreference {
  FeynmanTimerPreference([SharedPreferences? prefs]) : _injected = prefs;

  static const String _key = 'feynman_timer_seconds_last_used';

  final SharedPreferences? _injected;

  Future<SharedPreferences> get _prefs async =>
      _injected ?? await SharedPreferences.getInstance();

  /// The last preset the user picked, or `null` if they have never run a
  /// Feynman session on this device.
  Future<int?> lastUsedSeconds() async => (await _prefs).getInt(_key);

  Future<void> setLastUsed(int seconds) async {
    await (await _prefs).setInt(_key, seconds);
  }
}
