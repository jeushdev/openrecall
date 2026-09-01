import 'package:flutter/widgets.dart';

/// The app's spacing scale (ui-spec-v3 §1).
///
/// Names the small set of gaps and paddings the layout code was expressing as
/// bare `SizedBox(height: 16)` / `EdgeInsets.all(24)` literals, so vertical
/// rhythm is consistent across screens. A 4px base step.
abstract final class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// A vertical gap of [xs].
  static const SizedBox gapXs = SizedBox(height: xs);

  /// A vertical gap of [sm].
  static const SizedBox gapSm = SizedBox(height: sm);

  /// A vertical gap of [md].
  static const SizedBox gapMd = SizedBox(height: md);

  /// A vertical gap of [lg].
  static const SizedBox gapLg = SizedBox(height: lg);

  /// A vertical gap of [xl].
  static const SizedBox gapXl = SizedBox(height: xl);

  /// Standard screen edge padding.
  static const EdgeInsets screen = EdgeInsets.all(lg);
}
