import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/stats/application/stats_providers.dart';
import '../../features/profile/application/profile_providers.dart';
import 'profile_stat_block.dart';

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
            child: ProfileStatBlock(
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
            child: ProfileStatBlock(
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
