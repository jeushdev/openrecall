import 'package:flutter/material.dart';

/// A single accent's two roles, per UI spec v1 §3.2.
///
/// [fill] is used at 30–45% opacity for stacked-deck / left-shadow accents;
/// [text] is full-strength and pre-checked for contrast on
/// `mutedFill`-tinted badges.
@immutable
class AccentPair {
  const AccentPair(this.fill, this.text);

  final Color fill;
  final Color text;

  static AccentPair lerp(AccentPair a, AccentPair b, double t) => AccentPair(
        Color.lerp(a.fill, b.fill, t)!,
        Color.lerp(a.text, b.text, t)!,
      );

  @override
  bool operator ==(Object other) =>
      other is AccentPair && other.fill == fill && other.text == text;

  @override
  int get hashCode => Object.hash(fill, text);
}

/// The app's strict visual identity, delivered as a [ThemeExtension] on the
/// single light [ThemeData] (UI spec v1 §3).
///
/// This class's [light] constant is the **only** place raw color literals are
/// allowed to appear anywhere in the app. Every screen resolves colors via
/// `Theme.of(context).extension<AppTokens>()!` and a course's accent via
/// [accent] — never a hardcoded hex.
///
/// Dark mode is deliberately not modelled here: it is deferred and undesigned
/// (UI spec v1 §3.1).
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.background,
    required this.cardFill,
    required this.mutedFill,
    required this.borderHairline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accents,
  });

  /// Screen background (§3.1).
  final Color background;

  /// Card / tile fill (§3.1).
  final Color cardFill;

  /// Stat blocks, inactive segmented-control track (§3.1).
  final Color mutedFill;

  /// 0.5px card / tile borders (§3.1).
  final Color borderHairline;

  /// Headings, primary labels (§3.1).
  final Color textPrimary;

  /// Captions, metadata (§3.1).
  final Color textSecondary;

  /// Placeholder / disabled (§3.1).
  final Color textTertiary;

  /// Accent map keyed by the eight `courses.accent_color` enum values
  /// (§3.2). Guaranteed to contain exactly those keys.
  final Map<String, AccentPair> accents;

  /// Resolves a course's accent key to its [AccentPair], falling back to the
  /// documented default (`slate`) for an unknown or legacy key rather than
  /// throwing.
  AccentPair accent(String key) => accents[key] ?? accents['slate']!;

  /// The one and only palette (§3.1, §3.2). Light theme; no dark counterpart.
  static const AppTokens light = AppTokens(
    background: Color(0xFFFFFFFF),
    cardFill: Color(0xFFFFFFFF),
    mutedFill: Color(0xFFF7F7F5),
    borderHairline: Color(0xFFEDEDED),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF8A8A8A),
    textTertiary: Color(0xFFB0B0B0),
    accents: <String, AccentPair>{
      'slate': AccentPair(Color(0xFFCBD5E1), Color(0xFF64748B)),
      'red': AccentPair(Color(0xFFD06C60), Color(0xFFB0453A)),
      'amber': AccentPair(Color(0xFFD6C08B), Color(0xFF8A7534)),
      'green': AccentPair(Color(0xFFAFC3A8), Color(0xFF6E8A65)),
      'teal': AccentPair(Color(0xFF8FC4BE), Color(0xFF3F7A73)),
      'blue': AccentPair(Color(0xFF9DBDD2), Color(0xFF4E7B95)),
      'violet': AccentPair(Color(0xFFB8AED9), Color(0xFF6D5FA8)),
      'pink': AccentPair(Color(0xFFE3AEBE), Color(0xFFB15C74)),
    },
  );

  @override
  AppTokens copyWith({
    Color? background,
    Color? cardFill,
    Color? mutedFill,
    Color? borderHairline,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Map<String, AccentPair>? accents,
  }) {
    return AppTokens(
      background: background ?? this.background,
      cardFill: cardFill ?? this.cardFill,
      mutedFill: mutedFill ?? this.mutedFill,
      borderHairline: borderHairline ?? this.borderHairline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accents: accents ?? this.accents,
    );
  }

  @override
  AppTokens lerp(covariant ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      background: Color.lerp(background, other.background, t)!,
      cardFill: Color.lerp(cardFill, other.cardFill, t)!,
      mutedFill: Color.lerp(mutedFill, other.mutedFill, t)!,
      borderHairline: Color.lerp(borderHairline, other.borderHairline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accents: <String, AccentPair>{
        for (final entry in accents.entries)
          entry.key: other.accents.containsKey(entry.key)
              ? AccentPair.lerp(entry.value, other.accents[entry.key]!, t)
              : entry.value,
      },
    );
  }
}
