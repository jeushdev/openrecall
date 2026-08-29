import 'package:flutter/material.dart';

/// The session progress bar (spec §5 "progress indicator"). Counts a card as
/// resolved once it is Mastered or parked — the two ways a card leaves the
/// queue for good — over the distinct-card total frozen at seed time.
class SessionProgressIndicator extends StatelessWidget {
  const SessionProgressIndicator({
    super.key,
    required this.resolved,
    required this.total,
  });

  final int resolved;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = total == 0 ? 0.0 : resolved / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(value: value),
        const SizedBox(height: 4),
        Text('$resolved / $total mastered', style: theme.textTheme.bodySmall),
      ],
    );
  }
}
