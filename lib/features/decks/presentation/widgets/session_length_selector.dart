import 'package:flutter/material.dart';

/// Whether a session runs until every card is Mastered or parked (spec §5), or
/// stops after a fixed number of distinct cards (spec §4).
enum SessionLengthMode { untilMastered, capped }

/// The fixed cap presets (spec §4: "10/20/30/All", not freeform entry). `null`
/// is the "All" preset — capped in name only, i.e. every card enters the queue.
const List<int?> sessionCapPresets = [10, 20, 30, null];

/// The session-length toggle on the Deck Overview (spec §4).
///
/// Visual-only for milestone 5 — milestone 6 reads [mode] / [cap] when it builds
/// the session queue.
class SessionLengthSelector extends StatelessWidget {
  const SessionLengthSelector({
    super.key,
    required this.mode,
    required this.cap,
    required this.onModeChanged,
    required this.onCapChanged,
  });

  final SessionLengthMode mode;

  /// The chosen cap when [mode] is [SessionLengthMode.capped]; `null` is "All".
  final int? cap;

  final ValueChanged<SessionLengthMode> onModeChanged;
  final ValueChanged<int?> onCapChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Session length', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<SessionLengthMode>(
          segments: const [
            ButtonSegment(
              value: SessionLengthMode.untilMastered,
              label: Text('Until mastered'),
            ),
            ButtonSegment(
              value: SessionLengthMode.capped,
              label: Text('Capped'),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (s) => onModeChanged(s.first),
        ),
        if (mode == SessionLengthMode.capped) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final preset in sessionCapPresets)
                ChoiceChip(
                  label: Text(preset?.toString() ?? 'All'),
                  selected: cap == preset,
                  onSelected: (_) => onCapChanged(preset),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
