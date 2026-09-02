import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_routes.dart';
import '../../../theme/app_geometry.dart';
import '../../../theme/app_tokens.dart';
import '../../../theme/app_type.dart';
import '../../../ui/common/app_card.dart';
import '../../../ui/common/avatar.dart';
import '../../../ui/common/large_title_scaffold.dart';
import '../../../ui/mastery/overall_mastery_card.dart';
import '../../profile/application/profile_providers.dart';
import '../../stats/application/stats_providers.dart';
import '../../study/presentation/study_session_args.dart';
import '../application/home_providers.dart';

/// The Home tab (`/home`, ui-spec-v4-navigation §3) — the shell's default
/// branch.
///
/// The greeting is the collapsing large title (ui-spec-v5 §5.2). Below: the
/// reused Overall Mastery card, a horizontal
/// strip of unfinished sessions (tap resumes), and a layered stack of the
/// most-reviewed decks (tap opens deck detail). Every value comes from a
/// provider that degrades cleanly offline; nothing here is on the study path.
class HomeTabScreen extends ConsumerWidget {
  const HomeTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(userIdentityProvider).email;
    final overall = ref.watch(overallMasteryProvider);
    final active = ref.watch(activeSessionsProvider);
    final mostReviewed = ref.watch(mostReviewedDecksProvider);

    return LargeTitleScaffold(
      title: 'Hello, ${greetingName(email)}',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          sliver: SliverList.list(
            children: [
              overall.when(
                data: (percent) => OverallMasteryCard(percent: percent),
                loading: () => const _CardSkeleton(height: 132),
                error: (_, _) => _SectionError(
                  onRetry: () => ref.invalidate(overallMasteryProvider),
                ),
              ),

              // Unfinished sessions — hidden entirely when there are none, so
              // the screen doesn't carry an empty heading.
              ...active.maybeWhen(
                orElse: () => const <Widget>[],
                data: (sessions) => sessions.isEmpty
                    ? const <Widget>[]
                    : [
                        const SizedBox(height: 28),
                        _SectionHeader('Unfinished sessions'),
                        const SizedBox(height: 12),
                        _UnfinishedStrip(sessions: sessions),
                      ],
              ),

              ...mostReviewed.maybeWhen(
                orElse: () => const <Widget>[],
                data: (decks) => decks.isEmpty
                    ? const <Widget>[]
                    : [
                        const SizedBox(height: 32),
                        _SectionHeader('Most reviewed decks'),
                        const SizedBox(height: 16),
                        _DeckStack(decks: decks),
                      ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child:
          Text(text, style: AppType.title.copyWith(color: tokens.textPrimary)),
    );
  }
}

/// Horizontally scrolling list of in-progress sessions. Tapping a card resumes
/// that deck's session in its mode (the study route re-queues the deck's
/// unmastered cards and the session-conflict rule retires the stale row).
class _UnfinishedStrip extends StatelessWidget {
  const _UnfinishedStrip({required this.sessions});

  final List<UnfinishedSession> sessions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sessions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _UnfinishedCard(session: sessions[i]),
      ),
    );
  }
}

class _UnfinishedCard extends StatelessWidget {
  const _UnfinishedCard({required this.session});

  final UnfinishedSession session;

  void _resume(BuildContext context) {
    context.pushNamed(
      AppRoutes.studySessionName,
      pathParameters: {'deckId': session.deckId},
      extra: StudySessionArgs(
        deckId: session.deckId,
        deckName: session.deckName,
        mode: session.studyMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final blue = tokens.accent('blue');
    final fraction = (session.percentComplete / 100).clamp(0.0, 1.0);

    return AppCard(
      radius: AppRadii.gridTile,
      onTap: () => _resume(context),
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        width: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              session.deckName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.label.copyWith(color: tokens.textPrimary),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      height: 4,
                      color: tokens.borderHairline,
                      child: FractionallySizedBox(
                        widthFactor: fraction,
                        alignment: Alignment.centerLeft,
                        child: Container(color: blue.fill),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${session.percentComplete}%',
                  style: AppType.numeric.copyWith(color: tokens.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The most-reviewed decks as a layered card stack: the front card is fully
/// dressed with a "View Deck" button; up to two more peek from behind with a
/// slight offset + rotation. Tapping the stack body cycles the front card
/// (a lightweight carousel — no page dots, no gamified affordance).
class _DeckStack extends StatefulWidget {
  const _DeckStack({required this.decks});

  final List<MostReviewedDeck> decks;

  @override
  State<_DeckStack> createState() => _DeckStackState();
}

class _DeckStackState extends State<_DeckStack> {
  int _front = 0;

  void _advance() {
    setState(() => _front = (_front + 1) % widget.decks.length);
  }

  @override
  Widget build(BuildContext context) {
    // Cards to render, front last so it paints on top. Show at most 3.
    final count = math.min(3, widget.decks.length);
    final ordered = [
      for (var depth = count - 1; depth >= 0; depth--)
        (depth, widget.decks[(_front + depth) % widget.decks.length]),
    ];

    return SizedBox(
      height: 184,
      child: GestureDetector(
        onTap: widget.decks.length > 1 ? _advance : null,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            for (final (depth, deck) in ordered)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Transform.translate(
                  offset: Offset(depth * 10.0, depth * 8.0),
                  child: Transform.rotate(
                    angle: depth == 0 ? 0 : depth * 0.02,
                    alignment: Alignment.topCenter,
                    child: _DeckCard(deck: deck, isFront: depth == 0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({required this.deck, required this.isFront});

  final MostReviewedDeck deck;
  final bool isFront;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final accent = tokens.accent(deck.accentColor);

    return AppCard(
      radius: 18,
      padding: const EdgeInsets.all(18),
      child: SizedBox(
        height: 132,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (deck.courseName != null) ...[
              Text(
                deck.courseName!.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.overline.copyWith(color: accent.text),
              ),
              const SizedBox(height: 3),
              Container(width: 28, height: 2, color: accent.fill),
              const SizedBox(height: 10),
            ],
            Text(
              deck.deckName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.title.copyWith(color: tokens.textPrimary),
            ),
            const Spacer(),
            Row(
              children: [
                Text(
                  '${deck.cardCount} card${deck.cardCount == 1 ? '' : 's'}',
                  style: AppType.caption.copyWith(color: tokens.textSecondary),
                ),
                const Spacer(),
                if (isFront)
                  TextButton(
                    onPressed: () => context.pushNamed(
                      AppRoutes.deckDetailName,
                      pathParameters: {'deckId': deck.deckId},
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: accent.text,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('View Deck',
                        style: AppType.label.copyWith(color: accent.text)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A static (non-animating) placeholder block shown while a section loads —
/// a dashboard shouldn't spin, and an animating indicator would also keep the
/// widget tester from ever settling.
class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: tokens.mutedFill,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Row(
      children: [
        Expanded(
          child: Text(
            "Couldn't load this section.",
            style: AppType.body.copyWith(color: tokens.textSecondary),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
