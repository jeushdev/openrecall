import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../../decks/domain/card.dart';
import 'stacked_deck.dart';

/// The Flip-mode card surface (ui-spec-v1 §6.2).
///
/// Shows the card front; a tap anywhere flips it to the back. Resets to the
/// front whenever [card] changes (the screen also re-keys this widget per
/// queue position, so a requeued card always starts face-down).
///
/// Transition is a fade + slide via [AnimatedSwitcher]. The §6.5 "Card
/// transition" Settings toggle exists (`studyAppearanceProvider`) but is not
/// wired here yet — that, plus building the 3D-flip animation, is a follow-up.
// TODO: honour the §6.5 "Card transition" setting (3D flip / fade & slide).
class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.card,
    required this.onFlippedChanged,
  });

  final FlashCard card;

  /// Fired whenever the revealed side changes — the screen gates the rating row
  /// and swipe gestures on "has been flipped at least once".
  final ValueChanged<bool> onFlippedChanged;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> {
  bool _flipped = false;

  @override
  void didUpdateWidget(FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id && _flipped) {
      _flipped = false;
      widget.onFlippedChanged(false);
    }
  }

  void _toggle() {
    setState(() => _flipped = !_flipped);
    widget.onFlippedChanged(_flipped);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final text = _flipped ? widget.card.back : widget.card.front;

    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: StackedDeck(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 260),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey(_flipped),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _flipped ? 'ANSWER' : 'PROMPT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: tokens.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.4,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _flipped ? 'Rate your recall below' : 'Tap to reveal',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
