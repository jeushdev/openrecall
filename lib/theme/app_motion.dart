import 'package:flutter/animation.dart';

/// The app's motion vocabulary (ui-spec-v3 §2).
///
/// Milestones UX3 (flip card) and UX4 (branch slide) introduced motion as inline
/// `Duration(milliseconds: …)` literals scattered per widget. This names one set
/// of durations and curves so every animated surface reads as part of the same
/// system.
///
/// **Motion never gates state** (`ui-spec-v1.md` §2). Every use of these in the
/// study loop is cosmetic — the queue advances, the rating records and the
/// progress bar updates synchronously regardless of animation status.
abstract final class AppMotion {
  const AppMotion._();

  /// Press-in / press-release on a button.
  static const Duration instant = Duration(milliseconds: 90);

  /// Cross-fades and small state flips.
  static const Duration fast = Duration(milliseconds: 140);

  /// Card-to-card advance and most transitions.
  static const Duration base = Duration(milliseconds: 220);

  /// Expand / collapse of disclosure surfaces (e.g. the Settings sections).
  /// Unchanged from the original UX4 pairing.
  static const Duration expand = Duration(milliseconds: 240);

  /// The Session Summary reveal — count-ups and the mastery arc.
  static const Duration slow = Duration(milliseconds: 520);

  /// Standard easing for expand / collapse and directional slides.
  static const Curve standard = Curves.easeOutCubic;

  /// Deceleration for fills that glide toward a new value (progress bar,
  /// count-ups).
  static const Curve decelerate = Curves.easeOut;

  /// A small overshoot, used only where it reads as physical weight — the card
  /// settling after a flip, a rating button releasing.
  static const Curve emphasized = Curves.easeOutBack;

  // ---------------------------------------------------------------------------
  // Back-compat aliases for call sites that predate the v3 vocabulary.
  // ---------------------------------------------------------------------------

  /// @Deprecated Use [expand].
  static const Duration expandDuration = expand;

  /// @Deprecated Use [standard].
  static const Curve expandCurve = standard;
}
