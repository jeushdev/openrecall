import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local store for the app theme override
/// (`docs/spec-v5-dark-mode.md` §4).
///
/// Like `NotificationPreferences` and `StudyAppearancePreferences` this is a
/// per-device display choice, not synced app data, so it lives in
/// `SharedPreferences` rather than on `profiles`. Same injectable-prefs shape so
/// a test can pass `SharedPreferences.setMockInitialValues`.
///
/// The value is persisted as [ThemeMode.name] (`system` / `light` / `dark`).
/// A missing or unrecognised value resolves to [ThemeMode.system].
class ThemeModePreference {
  ThemeModePreference([SharedPreferences? prefs]) : _injected = prefs;

  static const String _key = 'theme_mode';

  final SharedPreferences? _injected;

  Future<SharedPreferences> get _prefs async =>
      _injected ?? await SharedPreferences.getInstance();

  Future<ThemeMode> themeMode() async {
    final raw = (await _prefs).getString(_key);
    for (final mode in ThemeMode.values) {
      if (mode.name == raw) return mode;
    }
    return ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode value) async {
    await (await _prefs).setString(_key, value.name);
  }
}
