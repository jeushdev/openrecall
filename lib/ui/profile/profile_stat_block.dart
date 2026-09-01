import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// One stat tile on the Profile tab: a small label, a big value, and a small
/// caption line. Used by the streak / mastery row (`ProfileStatsRow`) and the
/// Study habits metrics block (`ProfileMetricsSection`).
///
/// Pass `caption: ' '` to reserve the caption's height when a tile has nothing
/// to say there, so a row of tiles stays aligned.
class ProfileStatBlock extends StatelessWidget {
  const ProfileStatBlock({
    super.key,
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
