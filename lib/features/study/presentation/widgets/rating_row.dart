import 'package:flutter/material.dart';

import '../../../../theme/app_geometry.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/flip_rating.dart';

/// The 0–4 rating row shared by every study mode (ui-spec-v1 §6.2).
///
/// Five equal-flex buttons, Unfamiliar → Mastered. Buttons 0–3 are white with a
/// hairline border; **button 4 ("Mastered") is always filled with the fixed
/// `red` accent (`#D06C60`)** regardless of the deck's own accent, so the
/// "Mastered" action stays one instantly-recognisable signal across every deck
/// (§6.2, resolved).
///
/// [enabled] gates the whole row — Flip mode enables it once the card is
/// flipped; Cloze and List enable it once every blank / item is revealed.
class RatingRow extends StatelessWidget {
  const RatingRow({
    super.key,
    required this.enabled,
    required this.onRate,
  });

  final bool enabled;
  final ValueChanged<FlipRating> onRate;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final mastered = tokens.accent('red');

    return Row(
      children: [
        for (final rating in FlipRating.values) ...[
          if (rating.index != 0) const SizedBox(width: 8),
          Expanded(
            child: _RatingButton(
              label: rating.label,
              onTap: enabled ? () => onRate(rating) : null,
              fill: rating == FlipRating.mastered ? mastered.fill : tokens.cardFill,
              labelColor: rating == FlipRating.mastered
                  ? tokens.cardFill
                  : tokens.textPrimary,
              borderColor: rating == FlipRating.mastered
                  ? mastered.fill
                  : tokens.borderHairline,
            ),
          ),
        ],
      ],
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.label,
    required this.onTap,
    required this.fill,
    required this.labelColor,
    required this.borderColor,
  });

  final String label;
  final VoidCallback? onTap;
  final Color fill;
  final Color labelColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: borderColor,
                width: AppBorders.hairline,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
