import 'package:flutter/services.dart';

/// The app's haptic vocabulary (ui-spec-v3 §3).
///
/// Before v3, haptics were three scattered `HapticFeedback.selectionClick()`
/// calls in the study loop. This names each distinct feedback and wraps it so a
/// platform-channel failure (or a test environment with no plugin) is swallowed
/// rather than thrown — a missed buzz must never break an interaction.
abstract final class AppHaptics {
  const AppHaptics._();

  static void _safe(void Function() run) {
    try {
      run();
    } catch (_) {
      // No haptics on this platform / in this test — ignore.
    }
  }

  /// A card flip or a generic selection.
  static void tap() => _safe(HapticFeedback.selectionClick);

  /// A rating button commit.
  static void rating() => _safe(HapticFeedback.lightImpact);

  /// A card leaving the queue for good (mastered or parked).
  static void commit() => _safe(HapticFeedback.mediumImpact);

  /// The Session Summary appearing — one firm tap. A landing, not a celebration
  /// jingle (ui-spec-v3 §5.4).
  static void sessionComplete() => _safe(HapticFeedback.heavyImpact);
}
