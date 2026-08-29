import 'package:flutter/material.dart';

import '../../domain/deck.dart';
import 'mastery_bar.dart';

/// One row in the Deck Library: name, mastery bar, due/total count, and when it
/// was last studied (spec §2). A downloaded deck also shows an offline
/// indicator (spec §10).
class DeckTile extends StatelessWidget {
  const DeckTile({
    super.key,
    required this.summary,
    required this.onTap,
    this.offline = false,
  });

  final DeckSummary summary;
  final VoidCallback onTap;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(summary.name, style: theme.textTheme.titleMedium),
                  ),
                  if (offline)
                    Icon(
                      Icons.download_done,
                      size: 18,
                      color: theme.colorScheme.primary,
                      semanticLabel: 'Available offline',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              MasteryBar(percent: summary.masteryPercent),
              const SizedBox(height: 8),
              Text(
                '${summary.dueCards}/${summary.totalCards} cards due  ·  '
                '${_lastStudiedLabel(summary.lastStudiedAt)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _lastStudiedLabel(DateTime? at) {
  if (at == null) return 'Never studied';
  final days = DateTime.now().difference(at).inDays;
  return switch (days) {
    <= 0 => 'Studied today',
    1 => 'Studied yesterday',
    < 7 => 'Studied $days days ago',
    _ => 'Studied on ${at.year}-${_two(at.month)}-${_two(at.day)}',
  };
}

String _two(int n) => n.toString().padLeft(2, '0');
