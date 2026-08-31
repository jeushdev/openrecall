import 'package:flutter/animation.dart';

/// Shared motion constants.
///
/// Milestones UX3 (flip card) and UX4 (branch slide) introduced motion as
/// inline literals scattered per widget. This names the UX4 pairing —
/// 240ms / `easeOutCubic`, from the branch slide in
/// `routing/scaffold_with_nav_bar.dart` — so new animated surfaces read as part
/// of the same system.
abstract final class AppMotion {
  const AppMotion._();

  /// Expand / collapse of disclosure surfaces (e.g. the Settings sections).
  static const Duration expandDuration = Duration(milliseconds: 240);
  static const Curve expandCurve = Curves.easeOutCubic;
}
