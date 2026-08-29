import 'package:shared_preferences/shared_preferences.dart';

/// Device-local store for the "study reminders" on/off preference (spec §9).
///
/// Notification preferences are not synced — like `available_offline` in §10,
/// this is a per-device choice, so it lives in `SharedPreferences` rather than
/// on `profiles`. Reminders default to on for a fresh install.
class NotificationPreferences {
  NotificationPreferences([SharedPreferences? prefs]) : _injected = prefs;

  static const String _key = 'notifications_enabled';

  final SharedPreferences? _injected;

  Future<SharedPreferences> get _prefs async =>
      _injected ?? await SharedPreferences.getInstance();

  /// Whether study reminders are enabled. `true` when never set.
  Future<bool> isEnabled() async => (await _prefs).getBool(_key) ?? true;

  Future<void> setEnabled(bool value) async {
    await (await _prefs).setBool(_key, value);
  }
}
