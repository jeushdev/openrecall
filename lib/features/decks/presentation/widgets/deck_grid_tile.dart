import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../routing/app_routes.dart';
import '../../../../theme/app_geometry.dart';
import '../../../../theme/app_tokens.dart';
import '../../application/decks_tab_view.dart';
import '../deck_segment.dart';
import 'deck_badge.dart';

/// One square tile in the Decks-tab grid (ui-spec-v1 §6.1).
///
/// The "stacked deck" depth is a single solid offset [Container] behind the
/// foreground card — **never** a [BoxShadow] (§3.3, a hard perf constraint).
/// The accent sliver peeks ~8px past the **left** edge only; this direction is
/// locked (§6.1).
///
/// Tapping the foreground card pushes `/study/:deckId?scope=due|all` (§4), the
/// `scope` taken from the currently active [segment]. The push (not a `go`)
/// keeps the Decks tab underneath so back-navigation returns to it.
class DeckGridTile extends StatelessWidget {
  const DeckGridTile({
    super.key,
    required this.deck,
    required this.segment,
  });

  final DeckTileView deck;
  final DeckSegment segment;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    // Resolve the deck's accent through its parent course's named key (§6.1);
    // `accent()` falls back to `slate` for an unknown key.
    final accent = tokens.accent(deck.accentKey);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Backing accent layer: shifted so only a left sliver shows.
        Positioned(
          left: 0,
          right: 8,
          top: 8,
          bottom: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: accent.fill.withValues(alpha: 0.4),
              borderRadius: AppRadii.gridTileRadius,
            ),
          ),
        ),
        // Foreground card, inset 8px from the left to reveal the sliver.
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Container(
            decoration: BoxDecoration(
              color: tokens.cardFill,
              borderRadius: AppRadii.gridTileRadius,
              border: Border.all(
                color: tokens.borderHairline,
                width: AppBorders.hairline,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => context.pushNamed(
                  AppRoutes.studySessionName,
                  pathParameters: {'deckId': deck.id},
                  queryParameters: {'scope': segment.scopeQueryValue},
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        deck.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DeckBadge(deck: deck, segment: segment, accent: accent),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
