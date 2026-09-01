import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/local_db/mirror_scope_guard.dart';
import 'core/sync/sync_providers.dart';
import 'core/ui/app_messenger.dart';
import 'features/settings/application/settings_providers.dart';
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
    // Drops the local mirror if the signed-in account changes (design spec §E.3).
    ref.watch(mirrorScopeGuardProvider);

    // System / Light / Dark override (`docs/spec-v5-dark-mode.md` §4). Falls
    // back to System until the preference read resolves — with the cold-start
    // seed from `main()` in place, that resolution is synchronous.
    final themeMode =
        ref.watch(themeModeProvider).asData?.value ?? ThemeMode.system;

    return MaterialApp.router(
      title: 'OpenRecall',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        // Match the status-bar / nav-bar icon brightness to whichever theme
        // actually resolved (§5). Keyed off the resolved brightness so it
        // tracks System, Light and Dark alike.
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: isDark ? AppTheme.darkOverlay : AppTheme.lightOverlay,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
