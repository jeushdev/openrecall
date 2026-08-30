import 'package:flutter/material.dart';

import '../../application/decks_tab_view.dart';
import 'create_deck_tile.dart';
import 'deck_grid_tile.dart';

/// The 2-column square-tile grid inside one expanded course section of the
/// Decks-tab accordion (ui-spec-v2 §5): `crossAxisCount: 2`,
/// `childAspectRatio: 1`, gap `14`.
///
/// Non-scrolling — the outer accordion `ListView` owns scrolling and the bottom
/// inset that clears the floating glass nav bar. [showCreateTile] appends the
/// dashed "Create" cell (→ `/deck-creator`); the tab shows it in the default
/// course's body so a user with no decks still has a call to action.
class DeckGrid extends StatelessWidget {
  const DeckGrid({
    super.key,
    required this.decks,
    this.showCreateTile = false,
  });

  final List<DeckTileView> decks;
  final bool showCreateTile;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      children: [
        for (final deck in decks) DeckGridTile(deck: deck),
        if (showCreateTile) const CreateDeckTile(),
      ],
    );
  }
}
