import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'features/notifications/application/notification_providers.dart';
import 'features/notifications/data/notification_service.dart';

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

  runApp(ProviderScope(
    overrides: [notificationServiceProvider.overrideWithValue(notifications)],
    child: const OpenRecallApp(),
  ));
}
