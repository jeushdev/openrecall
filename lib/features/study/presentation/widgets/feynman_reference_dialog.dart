import 'package:flutter/material.dart';

import '../../../../theme/app_geometry.dart';
import '../../../../theme/app_tokens.dart';
import '../../../decks/domain/card.dart';
import '../../domain/list_content.dart';

/// The Feynman "Reveal reference" overlay (ui-spec-v1 §6.2).
///
/// Opened by the reference chip once the timer has stopped. Uses
/// [showGeneralDialog] (not [showDialog]) with an explicit `barrierColor` scrim
/// per the spec; tapping the scrim outside the card dismisses it. Opening it is
/// fully independent of rating — the rating row underneath stays live whether or
/// not this is ever shown.
class FeynmanReferenceDialog extends StatelessWidget {
  const FeynmanReferenceDialog._({required this.card});

  final FlashCard card;

  static Future<void> show(BuildContext context, FlashCard card) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss reference',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, _, _) => FeynmanReferenceDialog._(card: card),
      transitionBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final content = listContentOf(card);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              decoration: BoxDecoration(
                color: tokens.cardFill,
                borderRadius: AppRadii.cardRadius,
                border: Border.all(
                  color: tokens.borderHairline,
                  width: AppBorders.hairline,
                ),
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REFERENCE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: tokens.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    content.prompt,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < content.lines.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '•  ',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: tokens.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            content.lines[i],
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
