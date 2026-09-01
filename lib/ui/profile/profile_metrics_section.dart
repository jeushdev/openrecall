import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/study_duration.dart';
import '../../features/stats/application/stats_providers.dart';
import '../../features/stats/domain/study_metrics.dart';
import '../../theme/app_tokens.dart';
import 'profile_stat_block.dart';

/// The Profile tab's "Study habits" block (offline-and-ux milestone D): longest
/// streak and study-volume totals as single-value tiles, plus a this-week
/// rollup. Reads [studyMetricsProvider]; each tile shows an em dash until it
/// resolves, matching how the streak / mastery row above loads.
class ProfileMetricsSection extends ConsumerWidget {
  const ProfileMetricsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final m = ref.watch(studyMetricsProvider).asData?.value;

    String number(int? Function(StudyMetrics m) pick) =>
        m == null ? '—' : '${pick(m)}';
    String time(Duration? Function(StudyMetrics m) pick) =>
        m == null ? '—' : formatStudyDuration(pick(m)!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Study habits',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _TileRow(
          children: [
            ProfileStatBlock(
              label: 'Longest streak',
              value: number((m) => m.longestStreak),
              caption: switch (m?.longestStreak) {
                null => ' ',
                1 => 'day',
                _ => 'days',
              },
            ),
            ProfileStatBlock(
              label: 'Sessions completed',
              value: number((m) => m.sessionsCompleted),
              caption: ' ',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _TileRow(
          children: [
            ProfileStatBlock(
              label: 'Cards reviewed',
              value: number((m) => m.totalCardsReviewed),
              caption: ' ',
            ),
            ProfileStatBlock(
              label: 'Study time',
              value: time((m) => m.totalStudyTime),
              caption: ' ',
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'This week',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        _TileRow(
          children: [
            ProfileStatBlock(
              label: 'Cards',
              value: number((m) => m.thisWeekCards),
              caption: ' ',
            ),
            ProfileStatBlock(
              label: 'Sessions',
              value: number((m) => m.thisWeekSessions),
              caption: ' ',
            ),
            ProfileStatBlock(
              label: 'Time',
              value: time((m) => m.thisWeekStudyTime),
              caption: ' ',
            ),
          ],
        ),
      ],
    );
  }
}

/// A row of equal-width tiles with the same 12px gutter and stretch alignment
/// the streak / mastery row uses.
class _TileRow extends StatelessWidget {
  const _TileRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}
