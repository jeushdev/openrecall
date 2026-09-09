import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show Brightness;

/// Corner radii (ui-spec-v5 §3).
abstract final class AppRadii {
  const AppRadii._();

  /// Cards, study surfaces, sheet & dialog corners.
  static const double card = 20.0;

  /// Deck grid tile.
  static const double gridTile = 16.0;

  /// Grouped-list section container.
  static const double section = 12.0;

  /// Form fields, segmented controls, small chips.
  static const double control = 12.0;

  /// Filled / outlined / text buttons.
  static const double button = 14.0;

  /// Legacy alias for [control] — kept so existing input call sites compile.
  static const double input = 12.0;

  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius gridTileRadius = BorderRadius.all(
    Radius.circular(gridTile),
  );
  static const BorderRadius sectionRadius = BorderRadius.all(
    Radius.circular(section),
  );
  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(button),
  );
  static const BorderRadius inputRadius = BorderRadius.all(
    Radius.circular(control),
  );
}

/// Separator / control-border width (ui-spec-v5 §3). iOS uses a 1px hairline.
abstract final class AppBorders {
  const AppBorders._();

  static const double hairline = 1.0;
}

/// Soft elevation (ui-spec-v5 §3). The app-wide BoxShadow ban is lifted; this is
/// the whole vocabulary. Dark mode carries no card shadow — separation there is
/// `cardFill` vs `background` contrast.
abstract final class AppShadows {
  const AppShadows._();

  static List<BoxShadow> card(Brightness b) => b == Brightness.dark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ];

  static List<BoxShadow> raised(Brightness b) => b == Brightness.dark
      ? const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ];
}
