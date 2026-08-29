import 'package:flutter/material.dart';

import '../../features/stats/domain/troublemaker_severity.dart';
import '../../theme/app_tokens.dart';

/// The trailing tint pill on a troublemaker row (ui-spec-v1 §6.3).
///
/// Purely a display of [severityFor]'s UI-only banding — see
/// `troublemaker_severity.dart` for why the thresholds are not an engine
/// concept. Reuses the deck-badge pill recipe (accent text on a 12%-tint of the
/// same colour); §3.2 says to reuse `red` rather than introduce a status hue, so
/// the two bands sit on `red` / `amber`.
class SeverityBadge extends StatelessWidget {
  const SeverityBadge({super.key, required this.severity});

  final TroublemakerSeverity severity;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    final (String label, String accentKey) = switch (severity) {
      TroublemakerSeverity.high => ('High', 'red'),
      TroublemakerSeverity.moderate => ('Watch', 'amber'),
      TroublemakerSeverity.none => ('', ''),
    };
    if (label.isEmpty) return const SizedBox.shrink();

    final accent = tokens.accent(accentKey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.text.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: accent.text,
        ),
      ),
    );
  }
}
