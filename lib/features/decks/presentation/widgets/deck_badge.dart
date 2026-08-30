import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../application/decks_tab_view.dart';

/// The single badge under a deck tile's name (ui-spec-v2 §5): the deck's card
/// count.
///
/// - Non-empty: `"{n} cards"` in the deck's accent text colour on a 12%-tinted
///   background of the same accent.
/// - Empty: a neutral `"no cards yet"` — deliberately not `"0 cards"`, to avoid
///   a discouraging zero.
class DeckBadge extends StatelessWidget {
  const DeckBadge({
    super.key,
    required this.deck,
    required this.accent,
  });

  final DeckTileView deck;
  final AccentPair accent;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    if (deck.cardCount == 0) {
      return Text(
        'no cards yet',
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
        '${deck.cardCount} cards',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: accent.text,
        ),
      ),
    );
  }
}
