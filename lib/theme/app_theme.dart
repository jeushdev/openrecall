import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_tokens.dart';

/// App-wide theming. A [light] and a [dark] [ThemeData], each carrying the
/// matching [AppTokens] extension. The active one is chosen by
/// `MaterialApp.themeMode` (see `themeModeProvider`); the dark palette and the
/// System/Light/Dark selector are speced in `docs/spec-v5-dark-mode.md`, which
/// supersedes the earlier "dark mode deferred" note.
abstract final class AppTheme {
  const AppTheme._();

  static final ThemeData light = _build(Brightness.light, AppTokens.light);
  static final ThemeData dark = _build(Brightness.dark, AppTokens.dark);

  static ThemeData _build(Brightness brightness, AppTokens tokens) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: tokens.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: tokens.textPrimary,
        brightness: brightness,
      ).copyWith(surface: tokens.background),
      extensions: <ThemeExtension<dynamic>>[tokens],
    );
  }

  /// System status-bar / navigation-bar treatment per theme
  /// (`docs/spec-v5-dark-mode.md` §5). Applied app-wide via an
  /// `AnnotatedRegion` in `MaterialApp.router`'s builder — the app has no
  /// `AppBar`, so `AppBarTheme.systemOverlayStyle` never fires.
  static const SystemUiOverlayStyle lightOverlay = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarBrightness: Brightness.light, // iOS
    statusBarIconBrightness: Brightness.dark, // Android
    systemNavigationBarColor: Color(0xFFFFFFFF),
    systemNavigationBarDividerColor: Color(0x00000000),
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static const SystemUiOverlayStyle darkOverlay = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarBrightness: Brightness.dark, // iOS
    statusBarIconBrightness: Brightness.light, // Android
    systemNavigationBarColor: Color(0xFF121212),
    systemNavigationBarDividerColor: Color(0x00000000),
    systemNavigationBarIconBrightness: Brightness.light,
  );
}
