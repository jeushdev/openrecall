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
/// `_build` installs a [TextTheme] (`AppType`) and a full set of component
/// themes (ui-spec-v5 §4). Every value routes through [AppTokens] / [AppRadii] /
/// [AppBorders]; `ColorScheme.primary` is `tokens.tint` (iOS `systemBlue`) so
/// stock Material controls pick up the tint. Flutter `elevation` stays `0`
/// everywhere — the v5 soft elevation is drawn at the widget layer by `AppCard`
/// / `AppShadows`, and sheets & dialogs get their depth from the scrim.
abstract final class AppTheme {
  const AppTheme._();

  static final ThemeData light = _build(Brightness.light, AppTokens.light);
  static final ThemeData dark = _build(Brightness.dark, AppTokens.dark);

  static ThemeData _build(Brightness brightness, AppTokens tokens) {
    final scheme = ColorScheme.fromSeed(
      seedColor: tokens.tint,
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
      // The app's "primary action" is a solid tint button with a white label
      // (ui-spec-v5 §4) — deliberate, and consistent light/dark.
      primary: tokens.tint,
      onPrimary: Colors.white,
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
        titleTextStyle: AppType.headline.copyWith(color: tokens.textPrimary),
      ),

      cardTheme: CardThemeData(
        color: tokens.cardFill,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.cardRadius,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.tint,
          foregroundColor: Colors.white,
          disabledBackgroundColor: tokens.mutedFill,
          disabledForegroundColor: tokens.textTertiary,
          elevation: 0,
          shadowColor: Colors.transparent,
          // Height floor only — never a width floor. `Size.fromHeight` sets an
          // infinite minimum width, which breaks any button in an unbounded row
          // or app-bar action slot; callers that want a full-width CTA stretch
          // it themselves.
          minimumSize: const Size(64, 50),
          textStyle: AppType.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.buttonRadius,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.tint,
          minimumSize: const Size(48, 44),
          textStyle: AppType.bodyLarge,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.buttonRadius,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          minimumSize: const Size(64, 50),
          textStyle: AppType.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          side: BorderSide(
            color: tokens.borderHairline,
            width: AppBorders.hairline,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.buttonRadius,
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
        border: const OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: BorderSide(color: tokens.tint, width: 1),
        ),
        errorStyle: AppType.caption.copyWith(color: tokens.accent('red').text),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: tokens.cardFill,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.cardRadius,
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
        dragHandleColor: tokens.textTertiary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
        ),
      ),

      switchTheme: SwitchThemeData(
        // iOS green track when on — the one non-tint accent (ui-spec-v5 §4).
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? const Color(0xFF34C759)
                : tokens.mutedFill),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
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
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadii.control)),
          ),
          textStyle: AppType.label,
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.tint,
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
    systemNavigationBarColor: Color(0xFFF2F2F7),
    systemNavigationBarDividerColor: Color(0x00000000),
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static const SystemUiOverlayStyle darkOverlay = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarBrightness: Brightness.dark, // iOS
    statusBarIconBrightness: Brightness.light, // Android
    systemNavigationBarColor: Color(0xFF000000),
    systemNavigationBarDividerColor: Color(0x00000000),
    systemNavigationBarIconBrightness: Brightness.light,
  );
}
