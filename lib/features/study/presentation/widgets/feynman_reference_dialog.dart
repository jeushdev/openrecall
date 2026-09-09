import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_geometry.dart';
import '../../../../theme/app_tokens.dart';
import '../../../decks/domain/card.dart';
import '../../../settings/application/settings_providers.dart';
import '../../../settings/data/study_appearance_preferences.dart';
import '../../domain/list_content.dart';

/// The Feynman "Reveal reference" overlay (ui-spec-v1 §6.2).
///
/// Opened by the reference chip once the timer has stopped. Uses
/// [showGeneralDialog] (not [showDialog]) with an explicit `barrierColor` scrim
/// per the spec; tapping the scrim outside the card dismisses it. Opening it is
/// fully independent of rating — the rating row underneath stays live whether or
/// not this is ever shown.
///
/// It opens via [showGeneralDialog], so it sits outside the study session's
/// widget subtree and can't inherit the screen's scoped [MediaQuery]. It reads
/// the §6.5 "Card text size" setting itself and applies its own `textScaler`
/// override so the reference matches the card just studied (milestone UX5).
class FeynmanReferenceDialog extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final scale =
        (ref.watch(studyAppearanceProvider).asData?.value.cardFontSize ??
                CardFontSize.medium)
            .scale;
    // The prompt is the concept card's front; the reference is its (possibly
    // multi-line / bulleted) back — docs/spec-v3-card-model.md.
    final prompt = card.front.trim();
    final lines = contentLines(card.back);

    final Widget reference = Center(
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
                    prompt,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < lines.length; i++) ...[
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
                            lines[i],
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

    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: reference,
    );
  }
}
