import 'package:flutter/material.dart';

import '../../features/stats/domain/troublemaker_severity.dart';
import '../../theme/app_tokens.dart';
import 'mastery_section_header.dart';
import 'severity_badge.dart';

/// One resolved row for [TroublemakerSection] — the screen has already looked
/// the deck name up (`TroublemakerCard` only carries a deck id) and banded the
/// fail count.
typedef TroublemakerEntry = ({
  String frontExcerpt,
  String deckName,
  int failCount,
  TroublemakerSeverity severity,
});

/// The "Troublemaker cards" section on the Mastery tab (ui-spec-v1 §6.3): the
/// most-failed cards across every deck, worst first, each with a front-text
/// excerpt, its deck, a miss count, and a severity tint.
class TroublemakerSection extends StatelessWidget {
  const TroublemakerSection({super.key, required this.entries});

  final List<TroublemakerEntry> entries;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MasterySectionHeader(title: 'Troublemaker cards'),
        const SizedBox(height: 4),
        if (entries.isEmpty)
          Text(
            "Nothing's giving you much trouble right now.",
            style: TextStyle(fontSize: 13, color: tokens.textSecondary),
          )
        else
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.frontExcerpt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${entry.deckName} · missed ${entry.failCount} '
                          '${entry.failCount == 1 ? 'time' : 'times'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: SeverityBadge(severity: entry.severity),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
