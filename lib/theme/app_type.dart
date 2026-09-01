import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// The app's type scale (ui-spec-v3 §1).
///
/// **Pairing: editorial serif + sans.** [_serif] is Fraunces — it carries
/// character: headings, big numbers, and card content. [_sans] is Inter — it
/// runs every piece of UI chrome (tabs, badges, buttons, captions, settings
/// rows) and every changing number (via [numeric]'s tabular figures).
///
/// Both are bundled variable TTFs (`pubspec.yaml` / `assets/fonts/`), never
/// fetched at runtime — the app reads its theme before `runApp` and is
/// offline-first. Flutter maps [FontWeight] onto the `wght` axis automatically;
/// the display styles additionally pin the `opsz` axis for their size.
///
/// [textTheme] maps these onto the Material `TextTheme` slots so un-styled
/// Material widgets inherit the scale. The serif-only and tabular styles are
/// also exposed directly for widgets that need them by name.
abstract final class AppType {
  const AppType._();

  static const String _serif = 'Fraunces';
  static const String _sans = 'Inter';

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  // ---------------------------------------------------------------------------
  // Named roles. Colourless — callers/`textTheme` apply an `AppTokens` colour.
  // ---------------------------------------------------------------------------

  /// The one big number — the Session-Summary mastery percentage.
  static const TextStyle display = TextStyle(
    fontFamily: _serif,
    fontSize: 40,
    fontWeight: FontWeight.w600,
    height: 1.05,
    fontVariations: [FontVariation('opsz', 40)],
    fontFeatures: _tabular,
  );

  /// Screen titles.
  static const TextStyle headline = TextStyle(
    fontFamily: _serif,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    height: 1.15,
    fontVariations: [FontVariation('opsz', 28)],
  );

  /// Card titles, section headers, summary-card headings.
  static const TextStyle title = TextStyle(
    fontFamily: _serif,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  /// Flip card front & back, Feynman prompt — the content the user is studying.
  static const TextStyle cardBody = TextStyle(
    fontFamily: _serif,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Primary UI text and metric labels.
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _sans,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Secondary UI text.
  static const TextStyle body = TextStyle(
    fontFamily: _sans,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Buttons, badges, rating-row labels.
  static const TextStyle label = TextStyle(
    fontFamily: _sans,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Metadata and the study counter.
  static const TextStyle caption = TextStyle(
    fontFamily: _sans,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  /// The `PROMPT` / `ANSWER` kickers — small, tracked, meant to be uppercased
  /// by the caller.
  static const TextStyle overline = TextStyle(
    fontFamily: _sans,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    height: 1.2,
  );

  /// Any changing number (stat tiles, counts) — Inter with tabular figures so
  /// digits don't jitter as they count.
  static const TextStyle numeric = TextStyle(
    fontFamily: _sans,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFeatures: _tabular,
  );

  /// A big tabular number for the count-up metric values.
  static const TextStyle numericLarge = TextStyle(
    fontFamily: _sans,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
    height: 1.1,
  );

  // ---------------------------------------------------------------------------
  // Material TextTheme mapping.
  // ---------------------------------------------------------------------------

  /// Builds the Material [TextTheme] from the roles above, coloured for the
  /// given [tokens]. Chrome-ish slots (`title{Medium,Small}`, `label*`, the
  /// small `body`) fall to Inter; the character slots stay Fraunces.
  static TextTheme textTheme(AppTokens tokens) {
    final primary = tokens.textPrimary;
    final secondary = tokens.textSecondary;

    TextStyle p(TextStyle s) => s.copyWith(color: primary);
    TextStyle s2(TextStyle s) => s.copyWith(color: secondary);

    return TextTheme(
      displayLarge: p(display),
      displayMedium: p(display.copyWith(fontSize: 34)),
      displaySmall: p(display.copyWith(fontSize: 28)),
      headlineLarge: p(headline.copyWith(fontSize: 30)),
      headlineMedium: p(headline),
      headlineSmall: p(headline.copyWith(fontSize: 22)),
      titleLarge: p(title.copyWith(fontSize: 22)),
      titleMedium: p(label.copyWith(fontSize: 15)),
      titleSmall: p(label.copyWith(fontSize: 13)),
      bodyLarge: p(bodyLarge),
      bodyMedium: p(body),
      bodySmall: s2(caption),
      labelLarge: p(label),
      labelMedium: s2(label.copyWith(fontSize: 12)),
      labelSmall: s2(overline),
    );
  }
}
