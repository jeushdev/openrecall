import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/application/profile_providers.dart';
import '../../features/stats/application/stats_providers.dart';
import '../../theme/app_tokens.dart';

/// The two stat blocks on the Profile tab (ui-spec-v1 §6.4): current streak and
/// aggregate mastery. Mastery reuses `overallMasteryProvider` (the same figure
/// the Mastery tab shows); streak comes from `currentStreakProvider`.
class ProfileStatsRow extends ConsumerWidget {
  const ProfileStatsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(currentStreakProvider);
    final mastery = ref.watch(overallMasteryProvider);

    final streakValue = streak.asData?.value;
    final masteryValue = mastery.asData?.value;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatBlock(
              label: 'Current streak',
              value: streakValue == null ? '—' : '$streakValue',
              caption: switch (streakValue) {
                null => ' ',
                0 => 'No streak yet',
                1 => 'day',
                _ => 'days',
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatBlock(
              label: 'Overall mastery',
              value: masteryValue == null ? '—' : '$masteryValue%',
              caption: ' ',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.mutedFill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.0,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: TextStyle(fontSize: 12, color: tokens.textTertiary),
          ),
        ],
      ),
    );
  }
}
