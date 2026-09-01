import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_geometry.dart';
import 'app_tokens.dart';
import 'app_type.dart';

/// App-wide theming. A [light] and a [dark] [ThemeData], each carrying the
/// matching [AppTokens] extension. The active one is chosen by
/// `MaterialApp.themeMode` (see `themeModeProvider`); the dark palette and the
/// System/Light/Dark selector are speced in `docs/spec-v5-dark-mode.md`.
///
/// `_build` now also installs a [TextTheme] (`AppType`) and a full set of
/// component themes (ui-spec-v3 §4). Before v3 the only theming here was a
/// `ColorScheme.fromSeed` with no component themes, so every un-tokened Material
/// surface — `AppBar`, `Card`, `FilledButton`, `Dialog`, `Switch`, `SnackBar`,
/// `BottomSheet` — painted in M3's seeded grey. Every value below routes through
/// [AppTokens] / [AppRadii] / [AppBorders]; there is **no `BoxShadow`** anywhere
/// (app-wide ban), so every elevation is `0` and depth stays faked with borders
/// and offset fills.
abstract final class AppTheme {
  const AppTheme._();

  static final ThemeData light = _build(Brightness.light, AppTokens.light);
  static final ThemeData dark = _build(Brightness.dark, AppTokens.dark);

  static ThemeData _build(Brightness brightness, AppTokens tokens) {
    final scheme = ColorScheme.fromSeed(
      seedColor: tokens.textPrimary,
      brightness: brightness,
    ).copyWith(
      surface: tokens.background,
      surfaceContainerLowest: tokens.background,
      surfaceContainerLow: tokens.cardFill,
      surfaceContainer: tokens.mutedFill,
      surfaceContainerHigh: tokens.mutedFill,
      surfaceContainerHighest: tokens.mutedFill,
      onSurface: tokens.textPrimary,
      onSurfaceVariant: tokens.textSecondary,
      outline: tokens.borderHairline,
      outlineVariant: tokens.borderHairline,
      // The app's "primary action" is a solid near-ink button with an inverted
      // label — deliberate, and consistent light/dark.
      primary: tokens.textPrimary,
      onPrimary: tokens.background,
      error: tokens.accent('red').text,
      onError: tokens.background,
      surfaceTint: Colors.transparent,
    );

    final textTheme = AppType.textTheme(tokens);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: tokens.background,
      colorScheme: scheme,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      extensions: <ThemeExtension<dynamic>>[tokens],

      appBarTheme: AppBarTheme(
        backgroundColor: tokens.background,
        foregroundColor: tokens.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppType.title.copyWith(color: tokens.textPrimary),
      ),

      cardTheme: CardThemeData(
        color: tokens.cardFill,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.gridTileRadius,
          side: BorderSide(
            color: tokens.borderHairline,
            width: AppBorders.hairline,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.textPrimary,
          foregroundColor: tokens.background,
          disabledBackgroundColor: tokens.mutedFill,
          disabledForegroundColor: tokens.textTertiary,
          elevation: 0,
          shadowColor: Colors.transparent,
          // Height floor only — never a width floor. `Size.fromHeight` sets an
          // infinite minimum width, which breaks any button in an unbounded row
          // or app-bar action slot; callers that want a full-width CTA stretch
          // it themselves.
          minimumSize: const Size(64, 52),
          textStyle: AppType.label.copyWith(fontSize: 15),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.inputRadius,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.textSecondary,
          minimumSize: const Size(48, 44),
          textStyle: AppType.label.copyWith(fontSize: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.inputRadius,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          minimumSize: const Size(64, 52),
          textStyle: AppType.label.copyWith(fontSize: 15),
          side: BorderSide(
            color: tokens.borderHairline,
            width: AppBorders.hairline,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.inputRadius,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.mutedFill,
        hintStyle: AppType.bodyLarge.copyWith(color: tokens.textTertiary),
        labelStyle: AppType.body.copyWith(color: tokens.textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: BorderSide(
            color: tokens.borderHairline,
            width: AppBorders.hairline,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: BorderSide(
            color: tokens.borderHairline,
            width: AppBorders.hairline,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: BorderSide(color: tokens.textPrimary, width: 1),
        ),
        errorStyle: AppType.caption.copyWith(color: tokens.accent('red').text),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: tokens.cardFill,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardRadius,
          side: BorderSide(
            color: tokens.borderHairline,
            width: AppBorders.hairline,
          ),
        ),
        titleTextStyle: AppType.title.copyWith(color: tokens.textPrimary),
        contentTextStyle:
            AppType.bodyLarge.copyWith(color: tokens.textSecondary),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.cardFill,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: tokens.borderHairline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? tokens.background
                : tokens.cardFill),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? tokens.textPrimary
                : tokens.mutedFill),
        trackOutlineColor: WidgetStateProperty.all(tokens.borderHairline),
      ),

      dividerTheme: DividerThemeData(
        color: tokens.borderHairline,
        thickness: AppBorders.hairline,
        space: AppBorders.hairline,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.textPrimary,
        contentTextStyle: AppType.body.copyWith(color: tokens.background),
        actionTextColor: tokens.background,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.inputRadius,
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: tokens.textSecondary,
        textColor: tokens.textPrimary,
        titleTextStyle: AppType.bodyLarge.copyWith(color: tokens.textPrimary),
        subtitleTextStyle:
            AppType.caption.copyWith(color: tokens.textSecondary),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: tokens.mutedFill,
          foregroundColor: tokens.textSecondary,
          selectedBackgroundColor: tokens.cardFill,
          selectedForegroundColor: tokens.textPrimary,
          side: BorderSide(
            color: tokens.borderHairline,
            width: AppBorders.hairline,
          ),
          textStyle: AppType.label,
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.textPrimary,
        linearTrackColor: tokens.borderHairline,
        circularTrackColor: tokens.borderHairline,
      ),

      iconTheme: IconThemeData(color: tokens.textSecondary),
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
