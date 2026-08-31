import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../../../../core/reorder.dart';
import '../../application/decks_tab_view.dart';
import 'create_deck_tile.dart';
import 'deck_grid_tile.dart';

/// The 2-column square-tile grid inside one expanded course section of the
/// Decks-tab accordion (ui-spec-v2 §5): `crossAxisCount: 2`,
/// `childAspectRatio: 1`, gap `14`.
///
/// Non-scrolling — the outer accordion `ListView` owns scrolling and the bottom
/// inset that clears the floating glass nav bar. [showCreateTile] appends the
/// dashed "Create" cell (→ `/deck-creator`) as a fixed footer; the tab shows it
/// in the default course's body so a user with no decks still has a call to
/// action.
///
/// Long-pressing a tile drags it to reorder decks within [courseId] (milestone
/// B): the move is applied optimistically through [tabOrderProvider] and
/// persisted in one batched call. The Create footer is never draggable.
class DeckGrid extends ConsumerWidget {
  const DeckGrid({
    super.key,
    required this.courseId,
    required this.decks,
    this.showCreateTile = false,
  });

  final String courseId;
  final List<DeckTileView> decks;
  final bool showCreateTile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReorderableGridView.count(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      onReorder: (oldIndex, newIndex) {
        final ids = [for (final d in decks) d.id];
        ref.read(tabOrderProvider.notifier).reorderDecks(
              courseId,
              moveItemToIndex(ids, oldIndex, newIndex),
            );
      },
      footer: showCreateTile ? const [CreateDeckTile()] : null,
      children: [
        for (final deck in decks)
          DeckGridTile(key: ValueKey(deck.id), deck: deck),
      ],
    );
  }
}
