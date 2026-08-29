import 'package:flutter/material.dart';

import '../../../decks/domain/card.dart';

/// The flip card for Flip mode (spec §5A): shows the front, and reveals the
/// back on tap. Resets to the front whenever the [card] changes.
class FlipCardView extends StatefulWidget {
  const FlipCardView({
    super.key,
    required this.card,
    this.onFlippedChanged,
  });

  final FlashCard card;

  /// Called whenever the revealed/hidden state changes — lets the screen gate
  /// the rating bar on "has been flipped".
  final ValueChanged<bool>? onFlippedChanged;

  @override
  State<FlipCardView> createState() => _FlipCardViewState();
}

class _FlipCardViewState extends State<FlipCardView> {
  bool _flipped = false;

  @override
  void didUpdateWidget(FlipCardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id && _flipped) {
      _flipped = false;
      widget.onFlippedChanged?.call(false);
    }
  }

  void _toggle() {
    setState(() => _flipped = !_flipped);
    widget.onFlippedChanged?.call(_flipped);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = _flipped ? widget.card.back : widget.card.front;

    return GestureDetector(
      onTap: _toggle,
      child: Card(
        child: Container(
          constraints: const BoxConstraints(minHeight: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _flipped ? 'Answer' : 'Prompt',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 12),
              Text(text, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                _flipped ? 'Rate your recall below' : 'Tap to reveal',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
