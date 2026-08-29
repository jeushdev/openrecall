import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// App-wide theming. A single light [ThemeData] carrying the [AppTokens]
/// extension (UI spec v1 §3). Dark mode is deferred and undesigned — there is
/// deliberately no dark counterpart here.
abstract final class AppTheme {
  const AppTheme._();

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppTokens.light.background,
    colorScheme:
        ColorScheme.fromSeed(seedColor: AppTokens.light.textPrimary).copyWith(
      surface: AppTokens.light.background,
    ),
    extensions: const <ThemeExtension<dynamic>>[AppTokens.light],
  );
}
