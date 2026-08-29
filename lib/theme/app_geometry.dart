import 'package:flutter/painting.dart';

/// Corner radii, per UI spec v1 §3.3.
abstract final class AppRadii {
  const AppRadii._();

  /// Card / study-surface corner radius.
  static const double card = 28.0;

  /// Grid deck-tile corner radius (smaller surface, tighter radius).
  static const double gridTile = 16.0;

  /// Form-field corner radius — tighter than a grid tile. `ui-spec-v1.md` §3.3
  /// only specs the card (28) and grid-tile (16) radii; this names what would
  /// otherwise be an inline one-off on text inputs.
  static const double input = 12.0;

  static const BorderRadius cardRadius =
      BorderRadius.all(Radius.circular(card));

  static const BorderRadius gridTileRadius =
      BorderRadius.all(Radius.circular(gridTile));

  static const BorderRadius inputRadius =
      BorderRadius.all(Radius.circular(input));
}

/// Border widths, per UI spec v1 §3.3.
///
/// There is deliberately no elevation or shadow constant here: `BoxShadow` is
/// banned app-wide (§3.3) and all depth is simulated with solid offset
/// containers.
abstract final class AppBorders {
  const AppBorders._();

  /// Hairline border on every card / tile / nav surface.
  static const double hairline = 0.5;
}
