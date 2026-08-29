import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../../decks/domain/card.dart';
import '../../domain/list_content.dart';
import 'stacked_deck.dart';

/// The List-mode card surface (ui-spec-v1 §6.2).
///
/// The single-line side is the prompt; the multi-line side is a vertical
/// checklist where every item is independently revealable by tapping it, **in
/// any order**. [onAllRevealed] fires once every item has been tapped — gated on
/// interaction, not on scroll position (§6.2). Reveal state is widget-local and
/// resets when [card] changes.
///
/// No swipe gestures in this mode (tactile-only, §6.2).
class ListRevealCard extends StatefulWidget {
  const ListRevealCard({
    super.key,
    required this.card,
    required this.onAllRevealed,
  });

  final FlashCard card;
  final VoidCallback onAllRevealed;

  @override
  State<ListRevealCard> createState() => _ListRevealCardState();
}

class _ListRevealCardState extends State<ListRevealCard> {
  late ListContent _content;
  final Set<int> _revealed = {};

  @override
  void initState() {
    super.initState();
    _content = listContentOf(widget.card);
  }

  @override
  void didUpdateWidget(ListRevealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) {
      _revealed.clear();
      _content = listContentOf(widget.card);
      _maybeNotify();
    }
  }

  void _reveal(int index) {
    if (_revealed.contains(index)) return;
    setState(() => _revealed.add(index));
    _maybeNotify();
  }

  void _maybeNotify() {
    final total = _content.lines.length;
    if (total > 0 && _revealed.length >= total) {
      widget.onAllRevealed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return StackedDeck(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'RECALL THESE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: tokens.textTertiary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _content.prompt,
              style: TextStyle(
                fontSize: 16,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < _content.lines.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _Item(
                text: _content.lines[i],
                revealed: _revealed.contains(i),
                onTap: () => _reveal(i),
                tokens: tokens,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.text,
    required this.revealed,
    required this.onTap,
    required this.tokens,
  });

  final String text;
  final bool revealed;
  final VoidCallback onTap;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: revealed ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: revealed ? tokens.cardFill : tokens.mutedFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.borderHairline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              revealed ? Icons.check_rounded : Icons.visibility_off_outlined,
              size: 16,
              color: revealed ? tokens.textPrimary : tokens.textTertiary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                revealed ? text : 'Tap to reveal',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: revealed ? tokens.textPrimary : tokens.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
