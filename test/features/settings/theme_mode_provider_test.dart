import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/settings/application/settings_providers.dart';
import 'package:open_recall/features/settings/data/theme_mode_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> container(
    Map<String, Object> initial, {
    ThemeMode? seed,
  }) async {
    SharedPreferences.setMockInitialValues(initial);
    final sp = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        themeModePreferenceProvider.overrideWithValue(ThemeModePreference(sp)),
        if (seed != null) initialThemeModeProvider.overrideWithValue(seed),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('defaults to system with no seed and nothing stored', () async {
    final c = await container({});
    expect(await c.read(themeModeProvider.future), ThemeMode.system);
  });

  test('build() surfaces the persisted selection when there is no seed',
      () async {
    final c = await container({'theme_mode': 'dark'});
    expect(await c.read(themeModeProvider.future), ThemeMode.dark);
  });

  test('the cold-start seed resolves synchronously', () async {
    final c = await container({}, seed: ThemeMode.dark);
    // No await on `.future`: with the seed in place the first read is AsyncData.
    expect(c.read(themeModeProvider).value, ThemeMode.dark);
  });

  test('setThemeMode updates state and persists', () async {
    final c = await container({});
    await c.read(themeModeProvider.future);

    await c.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
    expect(c.read(themeModeProvider).value, ThemeMode.light);

    c.invalidate(themeModeProvider);
    expect(await c.read(themeModeProvider.future), ThemeMode.light);
  });
}
