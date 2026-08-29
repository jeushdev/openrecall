import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/sync/sync_providers.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

/// Root widget. Wires the router and theme into [MaterialApp.router].
class OpenRecallApp extends ConsumerWidget {
  const OpenRecallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // Keeps the sync-on-reconnect subscription alive for the app's lifetime
    // (spec §10).
    ref.watch(syncCoordinatorProvider);

    return MaterialApp.router(
      title: 'OpenRecall',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
