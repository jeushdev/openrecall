import 'package:flutter/material.dart';

import '../../domain/flip_rating.dart';

/// The direct 0–4 rating input for Flip mode (spec §5A). One button per rating,
/// Unfamiliar → Mastered. Disabled until the card is flipped so a rating is
/// always a check against the revealed answer, not a blind guess.
class RatingBar extends StatelessWidget {
  const RatingBar({
    super.key,
    required this.enabled,
    required this.onRate,
  });

  final bool enabled;
  final ValueChanged<FlipRating> onRate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final rating in FlipRating.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FilledButton.tonal(
              onPressed: enabled ? () => onRate(rating) : null,
              child: Text(rating.label),
            ),
          ),
      ],
    );
  }
}
