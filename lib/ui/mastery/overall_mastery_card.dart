import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../common/app_card.dart';

/// The aggregate mastery figure at the top of the Mastery tab (ui-spec-v1
/// §6.3): the app-wide, card-weighted percentage on an [AppCard] elevated
/// surface with a thin blue progress bar beneath.
///
/// [percent] is `overallMasteryProvider`'s value, already 0–100 and rounded.
class OverallMasteryCard extends StatelessWidget {
  const OverallMasteryCard({super.key, required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final blue = tokens.accent('blue').fill;
    final fraction = (percent / 100).clamp(0.0, 1.0);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall mastery',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$percent%',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              height: 1.0,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // Thin progress bar — a plain clipped track + fill, never a
          // LinearProgressIndicator (which would pull a Material theme colour).
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 4,
              color: tokens.borderHairline,
              child: FractionallySizedBox(
                widthFactor: fraction,
                alignment: Alignment.centerLeft,
                child: Container(color: blue),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
