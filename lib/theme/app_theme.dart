import 'package:flutter/material.dart';

/// App-wide theming. Deliberately minimal for the scaffold — a seeded
/// [ColorScheme] and Material 3. Real visual design comes later.
abstract final class AppTheme {
  const AppTheme._();

  static const Color _seed = Color(0xFF3D5AFE);

  static ThemeData get light => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed),
    useMaterial3: true,
  );

  static ThemeData get dark => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );
}
