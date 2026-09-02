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
/// This class's [light] and [dark] constants are the **only** place raw color
/// literals are allowed to appear anywhere in the app. Every screen resolves
/// colors via `Theme.of(context).extension<AppTokens>()!` and a course's accent
/// via [accent] — never a hardcoded hex.
///
/// [dark] is the dark-mode counterpart, derived from [light] by inversion and
/// documented decision-by-decision (with the WCAG AA contrast math) in
/// `docs/spec-v5-dark-mode.md`. That spec supersedes the earlier
/// "dark mode deferred" note in UI spec v1 §3.1.
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
    required this.tint,
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

  /// Interactive / accent colour — primary buttons, links, selected tab, focus
  /// ring (ui-spec-v5 §3).
  final Color tint;

  /// Accent map keyed by the eight `courses.accent_color` enum values
  /// (§3.2). Guaranteed to contain exactly those keys.
  final Map<String, AccentPair> accents;

  /// Resolves a course's accent key to its [AccentPair], falling back to the
  /// documented default (`slate`) for an unknown or legacy key rather than
  /// throwing.
  AccentPair accent(String key) => accents[key] ?? accents['slate']!;

  /// The light palette (ui-spec-v5 §3) — iOS system surfaces on a grouped
  /// `systemGroupedBackground` ground, `systemBlue` tint, and the iOS system
  /// colours as the eight course accents.
  static const AppTokens light = AppTokens(
    background: Color(0xFFF2F2F7),
    cardFill: Color(0xFFFFFFFF),
    mutedFill: Color(0xFFEFEFF4),
    borderHairline: Color(0xFFC6C6C8),
    textPrimary: Color(0xFF1C1C1E),
    textSecondary: Color(0xFF8E8E93),
    textTertiary: Color(0xFFC7C7CC),
    tint: Color(0xFF007AFF),
    accents: <String, AccentPair>{
      'slate': AccentPair(Color(0xFFC7C7CC), Color(0xFF8E8E93)),
      'red': AccentPair(Color(0xFFFF6961), Color(0xFFFF3B30)),
      'amber': AccentPair(Color(0xFFFFB340), Color(0xFFFF9500)),
      'green': AccentPair(Color(0xFF63DA83), Color(0xFF34C759)),
      'teal': AccentPair(Color(0xFF5AC8E0), Color(0xFF30B0C7)),
      'blue': AccentPair(Color(0xFF4DA2FF), Color(0xFF007AFF)),
      'violet': AccentPair(Color(0xFF8886E0), Color(0xFF5856D6)),
      'pink': AccentPair(Color(0xFFFF6482), Color(0xFFFF2D55)),
    },
  );

  /// The dark palette (ui-spec-v5 §3; `docs/spec-v5-dark-mode.md` §4 for the
  /// theme-mode mechanism). True-black `systemBackground` with two raised
  /// `systemGray6`/`systemGray5` steps and no shadow. Accent `fill`s are shared
  /// with the light palette; accent `text`s move to the iOS dark system-colour
  /// values so each label clears WCAG AA on the dark `mutedFill` badge ground.
  static const AppTokens dark = AppTokens(
    background: Color(0xFF000000),
    cardFill: Color(0xFF1C1C1E),
    mutedFill: Color(0xFF2C2C2E),
    borderHairline: Color(0xFF38383A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF98989F),
    textTertiary: Color(0xFF48484A),
    tint: Color(0xFF0A84FF),
    accents: <String, AccentPair>{
      'slate': AccentPair(Color(0xFF48484A), Color(0xFFAEAEB2)),
      'red': AccentPair(Color(0xFFFF6961), Color(0xFFFF453A)),
      'amber': AccentPair(Color(0xFFFFB340), Color(0xFFFF9F0A)),
      'green': AccentPair(Color(0xFF63DA83), Color(0xFF30D158)),
      'teal': AccentPair(Color(0xFF5AC8E0), Color(0xFF40C8E0)),
      'blue': AccentPair(Color(0xFF4DA2FF), Color(0xFF0A84FF)),
      'violet': AccentPair(Color(0xFF8886E0), Color(0xFF5E5CE6)),
      'pink': AccentPair(Color(0xFFFF6482), Color(0xFFFF375F)),
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
    Color? tint,
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
      tint: tint ?? this.tint,
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
      tint: Color.lerp(tint, other.tint, t)!,
      accents: <String, AccentPair>{
        for (final entry in accents.entries)
          entry.key: other.accents.containsKey(entry.key)
              ? AccentPair.lerp(entry.value, other.accents[entry.key]!, t)
              : entry.value,
      },
    );
  }
}
