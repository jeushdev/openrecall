import 'package:flutter/material.dart';

import '../../features/stats/domain/deck_completion.dart';
import '../../theme/app_tokens.dart';
import 'mastery_section_header.dart';

/// The "Deck completions" section on the Mastery tab (ui-spec-v1 §6.3): decks
/// sorted by run-through count descending, each with a plain `"×{n}"` count
/// badge. Neutral styling on purpose — this is a cross-deck list, not tied to
/// any one course's accent.
///
/// [completions] is already sorted (see [deckCompletions]).
class DeckCompletionsSection extends StatelessWidget {
  const DeckCompletionsSection({super.key, required this.completions});

  final List<DeckCompletion> completions;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MasterySectionHeader(title: 'Deck completions'),
        const SizedBox(height: 4),
        if (completions.isEmpty)
          Text(
            "No decks fully cleared yet — finish an 'All' run to land one here.",
            style: TextStyle(fontSize: 13, color: tokens.textSecondary),
          )
        else
          for (final completion in completions)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      completion.deckName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CountBadge(count: completion.runThroughs),
                ],
              ),
            ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.mutedFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '×$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: tokens.textSecondary,
        ),
      ),
    );
  }
}
