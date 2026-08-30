import 'package:flutter/material.dart';

import '../../../../theme/app_geometry.dart';
import '../../../../theme/app_tokens.dart';

/// The "stacked-deck" study surface (ui-spec-v1 §6.2).
///
/// Two solid offset layers behind the foreground card give it a sense
/// of depth without a [BoxShadow] — blur on the frequently-rebuilt study card is
/// banned app-wide (§3.3) because it risks frame drops on mid-range Android,
/// which would undercut the zero-network / optimistic-UI responsiveness
/// invariant (§2). The two backing layers peek out below the foreground card in
/// a short staircase.
///
/// The depth is **static**: it represents "the queue as it was when you
/// started", so it takes no live card count and never reflows if a background
/// sync pulls in new cards mid-session.
class StackedDeck extends StatelessWidget {
  const StackedDeck({super.key, required this.child});

  /// How far the deepest backing layer sits below the foreground card.
  static const double _depth = 14;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return Stack(
      children: [
        // Layer 1 — furthest back, narrowest, peeks lowest. The darker of the
        // two backing greys; routed through `borderHairline` so it inverts with
        // the theme (`docs/spec-v5-dark-mode.md` §6) instead of the old
        // hardcoded `#EEF1F5`.
        Positioned(
          top: _depth,
          left: 10,
          right: 10,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.borderHairline,
              borderRadius: AppRadii.cardRadius,
            ),
          ),
        ),
        // Layer 2 — between the foreground and layer 1; the lighter backing
        // grey, `mutedFill` (was `#F5F7FA`).
        Positioned(
          top: 7,
          left: 5,
          right: 5,
          bottom: 7,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.mutedFill,
              borderRadius: AppRadii.cardRadius,
            ),
          ),
        ),
        // Foreground card — the sizing child; stops [_depth] short of the
        // bottom so the backing layers show through.
        Padding(
          padding: const EdgeInsets.only(bottom: _depth),
          child: Container(
            decoration: BoxDecoration(
              color: tokens.cardFill,
              borderRadius: AppRadii.cardRadius,
              border: Border.all(
                color: tokens.borderHairline,
                width: AppBorders.hairline,
              ),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}
