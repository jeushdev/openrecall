import 'package:flutter/material.dart';

import '../../../../theme/app_geometry.dart';
import '../../../../theme/app_motion.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../theme/app_type.dart';
import '../../domain/flip_rating.dart';

/// The rating row shared by every study mode (ui-spec-v1 §6.2).
///
/// Four equal-flex buttons, Unfamiliar → Mastered. The first three are white
/// with a hairline border; **"Mastered" is always filled with the fixed `red`
/// accent (`#D06C60`)** regardless of the deck's own accent, so the "Mastered"
/// action stays one instantly-recognisable signal across every deck (§6.2,
/// resolved).
///
/// [enabled] gates the whole row — Flip mode enables it once the card is
/// flipped; Cloze and List enable it once every blank / item is revealed.
class RatingRow extends StatelessWidget {
  const RatingRow({super.key, required this.enabled, required this.onRate});

  final bool enabled;
  final ValueChanged<FlipRating> onRate;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final mastered = tokens.accent('red');

    Widget button(FlipRating rating) => _RatingButton(
      label: rating.label,
      onTap: enabled ? () => onRate(rating) : null,
      fill: rating == FlipRating.mastered ? mastered.fill : tokens.cardFill,
      labelColor: rating == FlipRating.mastered
          ? tokens.cardFill
          : tokens.textPrimary,
      borderColor: rating == FlipRating.mastered
          ? mastered.fill
          : tokens.borderHairline,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final style = AppType.label.copyWith(fontSize: 15);
        final scaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        final widestLabel = FlipRating.values.fold<double>(0, (width, rating) {
          final painter = TextPainter(
            text: TextSpan(text: rating.label, style: style),
            textScaler: scaler,
            textDirection: direction,
          )..layout();
          return width > painter.width ? width : painter.width;
        });
        final fourColumnWidth = (constraints.maxWidth - gap * 3) / 4;
        final useTwoColumns = widestLabel + 16 > fourColumnWidth;

        if (!useTwoColumns) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final rating in FlipRating.values) ...[
                  if (rating.index != 0) const SizedBox(width: gap),
                  Expanded(child: button(rating)),
                ],
              ],
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var row = 0; row < 2; row++) ...[
              if (row != 0) const SizedBox(height: gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: button(FlipRating.values[row * 2])),
                    const SizedBox(width: gap),
                    Expanded(child: button(FlipRating.values[row * 2 + 1])),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _RatingButton extends StatefulWidget {
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
  State<_RatingButton> createState() => _RatingButtonState();
}

class _RatingButtonState extends State<_RatingButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;

    return Opacity(
      opacity: disabled ? 0.4 : 1,
      // Press-in weight: a small scale dip while held, releasing on an
      // emphasized curve (ui-spec-v3 §5.2).
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: AppMotion.instant,
        curve: _pressed ? AppMotion.decelerate : AppMotion.emphasized,
        child: Material(
          color: Color.alphaBlend(
            _pressed
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.transparent,
            widget.fill,
          ),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: _setPressed,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              constraints: const BoxConstraints(minHeight: 60),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.borderColor,
                  width: AppBorders.hairline,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: AppType.label.copyWith(
                  fontSize: 15,
                  color: widget.labelColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
