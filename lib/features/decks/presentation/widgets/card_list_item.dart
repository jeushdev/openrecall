import 'package:flutter/material.dart';

import '../../domain/card.dart';

/// One existing card in the Deck Creator list, with edit and delete actions
/// (spec §3).
class CardListItem extends StatelessWidget {
  const CardListItem({
    super.key,
    required this.card,
    required this.onEdit,
    required this.onDelete,
  });

  final FlashCard card;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.front, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(card.back, style: theme.textTheme.bodyMedium),
                  if (card.keyword != null) ...[
                    const SizedBox(height: 8),
                    Chip(
                      label: Text(card.keyword!),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit card',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete card',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
