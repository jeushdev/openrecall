import 'package:flutter/material.dart';

import '../../../decks/domain/card.dart';
import '../../domain/list_content.dart';
import '../../domain/list_outcome.dart';

/// The List study widget (spec §5C). Shows the single-line side as the prompt
/// and the multi-line side masked; each tap reveals the next line in order.
/// "I recalled the rest" finishes with however many lines were revealed, mapped
/// to a `mastery_level` by [listMasteryFromReveals]. Emits that level once.
///
/// Resets on card change; the study screen also re-keys it per card, so a
/// requeue of the same card always starts fresh.
class ListCardView extends StatefulWidget {
  const ListCardView({
    super.key,
    required this.card,
    required this.onResult,
  });

  final FlashCard card;

  /// Called once with the resolved `cards.mastery_level` (0–4).
  final ValueChanged<int> onResult;

  @override
  State<ListCardView> createState() => _ListCardViewState();
}

class _ListCardViewState extends State<ListCardView> {
  late ListContent _content = listContentOf(widget.card);
  int _revealed = 0;

  @override
  void didUpdateWidget(ListCardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) {
      setState(() {
        _content = listContentOf(widget.card);
        _revealed = 0;
      });
    }
  }

  bool get _allRevealed => _revealed >= _content.lines.length;

  void _revealNext() {
    if (_allRevealed) return;
    setState(() => _revealed++);
  }

  void _finish() {
    widget.onResult(
      listMasteryFromReveals(
        revealed: _revealed,
        total: _content.lines.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recall these',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 12),
                Text(_content.prompt, style: theme.textTheme.titleMedium),
                const Divider(height: 32),
                for (var i = 0; i < _content.lines.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _ContentLine(
                    text: _content.lines[i],
                    revealed: i < _revealed,
                    isNext: i == _revealed,
                    onReveal: _revealNext,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _allRevealed
              ? 'All lines revealed.'
              : '$_revealed of ${_content.lines.length} revealed · '
                  'tap the next line to reveal it',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _finish,
          child: Text(_allRevealed ? 'Continue' : 'I recalled the rest'),
        ),
      ],
    );
  }
}

class _ContentLine extends StatelessWidget {
  const _ContentLine({
    required this.text,
    required this.revealed,
    required this.isNext,
    required this.onReveal,
  });

  final String text;
  final bool revealed;
  final bool isNext;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (revealed) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      );
    }

    final placeholder = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isNext ? scheme.secondaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: isNext ? Border.all(color: scheme.secondary) : null,
      ),
      child: Text(
        isNext ? 'Tap to reveal' : 'Hidden',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isNext ? scheme.onSecondaryContainer : scheme.outline,
        ),
      ),
    );

    if (!isNext) return placeholder;
    return InkWell(
      onTap: onReveal,
      borderRadius: BorderRadius.circular(8),
      child: placeholder,
    );
  }
}
