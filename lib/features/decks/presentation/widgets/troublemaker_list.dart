import 'package:flutter/material.dart';

import '../../domain/card.dart';

/// The "Troublemaker cards" section on the Deck Overview (spec §4): cards with
/// the highest lifetime `fail_count`. Read-only — parking is session-scoped and
/// lives elsewhere (spec §6).
///
/// Render nothing when [cards] is empty; the caller decides placement.
class TroublemakerList extends StatelessWidget {
  const TroublemakerList({super.key, required this.cards});

  final List<FlashCard> cards;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Troublemaker cards', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'The cards you fail most often.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final card in cards)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(card.front, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: Text(
              _failLabel(card.failCount),
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }
}

String _failLabel(int fails) => fails == 1 ? 'Failed once' : 'Failed $fails times';
