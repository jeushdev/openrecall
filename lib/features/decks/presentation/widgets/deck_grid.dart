import 'package:flutter/material.dart';

import '../deck_segment.dart';
import '../mock/mock_decks.dart';
import 'create_deck_tile.dart';
import 'deck_grid_tile.dart';

/// The 2-column square-tile grid on the Decks tab (ui-spec-v1 §6.1):
/// `crossAxisCount: 2`, `childAspectRatio: 1`, gap `14`.
///
/// The trailing cell is always the dashed "Create" tile. Bottom padding clears
/// the floating glass nav bar so the last row isn't hidden under it.
class DeckGrid extends StatelessWidget {
  const DeckGrid({
    super.key,
    required this.decks,
    required this.segment,
  });

  final List<MockDeck> decks;
  final DeckSegment segment;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      crossAxisCount: 2,
      childAspectRatio: 1,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      children: [
        for (final deck in decks)
          DeckGridTile(deck: deck, segment: segment),
        const CreateDeckTile(),
      ],
    );
  }
}
