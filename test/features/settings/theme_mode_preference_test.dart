import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/settings/data/theme_mode_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ThemeModePreference> prefs(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    return ThemeModePreference(await SharedPreferences.getInstance());
  }

  test('defaults to system when nothing is stored', () async {
    final p = await prefs({});
    expect(await p.themeMode(), ThemeMode.system);
  });

  test('round-trips every ThemeMode', () async {
    for (final mode in ThemeMode.values) {
      final p = await prefs({});
      await p.setThemeMode(mode);
      expect(await p.themeMode(), mode);
    }
  });

  test('reads back a previously persisted value', () async {
    final p = await prefs({'theme_mode': 'dark'});
    expect(await p.themeMode(), ThemeMode.dark);
  });

  test('falls back to system on an unrecognized stored string', () async {
    final p = await prefs({'theme_mode': 'sepia'});
    expect(await p.themeMode(), ThemeMode.system);
  });

  test('persists as ThemeMode.name', () async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    await ThemeModePreference(sp).setThemeMode(ThemeMode.light);
    expect(sp.getString('theme_mode'), 'light');
  });
}
