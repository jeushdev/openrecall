import 'package:flutter/material.dart';

import '../../core/format/mastery_delta_label.dart';
import '../../core/format/relative_time.dart';
import '../../features/stats/domain/activity_feed.dart';
import '../../theme/app_tokens.dart';
import 'mastery_section_header.dart';

/// The "Recent activity" block at the foot of the Mastery tab (milestone C):
/// completed sessions, created decks and created courses, newest first. Each row
/// is an icon, a short label, and a relative time; a completed-session row also
/// shows the run's "+X%" mastery delta, formatted exactly as the Session Summary
/// does ([masteryDeltaLabel]).
///
/// [items] is already merged, sorted and capped (see [buildActivityFeed]).
class ActivityFeedSection extends StatelessWidget {
  const ActivityFeedSection({super.key, required this.items});

  final List<ActivityItem> items;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MasterySectionHeader(title: 'Recent activity'),
        const SizedBox(height: 4),
        if (items.isEmpty)
          Text(
            'Your recent study activity will show up here.',
            style: TextStyle(fontSize: 13, color: tokens.textSecondary),
          )
        else
          for (final item in items) _ActivityRow(item: item),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final delta = item.masteryDelta;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _icon(item.kind),
            size: 18,
            color: tokens.textSecondary,
            semanticLabel: _iconLabel(item.kind),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _label(item),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: tokens.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          if (item.kind == ActivityKind.sessionCompleted && delta != null) ...[
            _DeltaBadge(delta: delta),
            const SizedBox(width: 8),
          ],
          Text(
            relativeTime(item.timestamp),
            style: TextStyle(fontSize: 12, color: tokens.textTertiary),
          ),
        ],
      ),
    );
  }

  static IconData _icon(ActivityKind kind) => switch (kind) {
        ActivityKind.sessionCompleted => Icons.school_outlined,
        ActivityKind.deckCreated => Icons.style_outlined,
        ActivityKind.courseCreated => Icons.folder_outlined,
      };

  static String _iconLabel(ActivityKind kind) => switch (kind) {
        ActivityKind.sessionCompleted => 'Session completed',
        ActivityKind.deckCreated => 'Deck created',
        ActivityKind.courseCreated => 'Course created',
      };

  static String _label(ActivityItem item) => switch (item.kind) {
        ActivityKind.sessionCompleted => 'Completed ${item.title}',
        ActivityKind.deckCreated => 'Created deck ${item.title}',
        ActivityKind.courseCreated => 'Created course ${item.title}',
      };
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.delta});

  final int delta;

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
        masteryDeltaLabel(delta),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: tokens.textSecondary,
        ),
      ),
    );
  }
}
