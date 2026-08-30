import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/local_db/app_database.dart';
import 'core/local_db/local_db_providers.dart';
import 'features/notifications/application/notification_providers.dart';
import 'features/notifications/data/notification_service.dart';
import 'features/settings/application/settings_providers.dart';
import 'features/settings/data/notification_preferences.dart';
import 'features/settings/data/theme_mode_preference.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    // The anon / public key (Dashboard → Project Settings → API), NOT the
    // service role key. Passed as `publishableKey` — `anonKey` is deprecated.
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  final notifications = NotificationService();
  await notifications.init();
  // Honor the user's saved reminders on/off choice (spec §9) from cold start.
  await notifications.setEnabled(await NotificationPreferences().isEnabled());

  // Eagerly read the saved theme override so the first frame paints in the
  // right theme with no flash (`docs/spec-v5-dark-mode.md` §4.1).
  ThemeMode themeMode;
  try {
    themeMode = await ThemeModePreference().themeMode();
  } catch (_) {
    themeMode = ThemeMode.system;
  }

  // The device-local mirror for offline decks (spec §10). If it can't be
  // opened the app still runs — just online-only.
  AppDatabase? database;
  try {
    database = await AppDatabase.open();
  } catch (_) {
    database = null;
  }

  runApp(ProviderScope(
    overrides: [
      notificationServiceProvider.overrideWithValue(notifications),
      initialThemeModeProvider.overrideWithValue(themeMode),
      if (database != null) appDatabaseProvider.overrideWithValue(database),
    ],
    child: const OpenRecallApp(),
  ));
}
