import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../application/decks_tab_view.dart';
import '../deck_segment.dart';

/// The single badge under a deck tile's name (ui-spec-v1 §6.1).
///
/// Its content depends on the active segment:
/// - **Due**: `"{n} due"` in the deck's accent text colour on a 12%-tinted
///   background of the same accent, or a neutral `"up to date"` when nothing is
///   due.
/// - **All**: `"×{n} cleared"` (same accent-tinted pill), or a neutral
///   `"not attempted"` when the deck has never been run through — deliberately
///   not `"×0"`, to avoid a discouraging zero.
class DeckBadge extends StatelessWidget {
  const DeckBadge({
    super.key,
    required this.deck,
    required this.segment,
    required this.accent,
  });

  final DeckTileView deck;
  final DeckSegment segment;
  final AccentPair accent;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    final (String label, bool tinted) = switch (segment) {
      DeckSegment.due => deck.dueCount > 0
          ? ('${deck.dueCount} due', true)
          : ('up to date', false),
      DeckSegment.all => deck.clearedCount > 0
          ? ('×${deck.clearedCount} cleared', true)
          : ('not attempted', false),
    };

    if (!tinted) {
      return Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: tokens.textSecondary,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.text.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: accent.text,
        ),
      ),
    );
  }
}
