import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_routes.dart';
import '../../../core/local_db/local_db_providers.dart';
import '../../../theme/app_geometry.dart';
import '../../../theme/app_tokens.dart';
import '../../../theme/app_type.dart';
import '../../../ui/common/app_card.dart';
import '../../../ui/common/avatar.dart';
import '../../../ui/common/large_title_scaffold.dart';
import '../../profile/application/profile_providers.dart';
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
    final profile = ref.watch(profileProvider);
    final waitingForLocalProfile =
        ref.watch(localStorageAvailableProvider) && profile.isLoading;
    final email = waitingForLocalProfile
        ? null
        : ref.watch(userIdentityProvider).email;
    final username = profile.asData?.value?.username;
    final active = ref.watch(activeSessionsProvider);
    final mostReviewed = ref.watch(mostReviewedDecksProvider);
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return LargeTitleScaffold(
      title: 'Hello, ${displayNameOr(username, email)}!',
      backgroundDecoration: Stack(
        children: [
          Positioned(
            top: -30,
            right: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.tint.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            top: 225,
            right: 145,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.tint.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            top: 360,
            left: -70,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.tint.withValues(alpha: 0.05),
              ),
            ),
          ),
        ],
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
          sliver: SliverList.list(
            children: [
              const _WelcomeSubheader(),
              // Unfinished sessions — hidden entirely when there are none, so
              // the screen doesn't carry an empty heading.
              ...active.maybeWhen(
                orElse: () => const <Widget>[],
                data: (sessions) => sessions.isEmpty
                    ? const <Widget>[]
                    : [
                        const SizedBox(height: 28),
                        _SectionHeader('Pick up where you left off'),
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
  const _SectionHeader(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: (style ?? AppType.title).copyWith(color: tokens.textPrimary),
      ),
    );
  }
}

class _WelcomeSubheader extends StatelessWidget {
  const _WelcomeSubheader();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        'What would you like to do today?',
        style: AppType.body.copyWith(color: tokens.textSecondary),
      ),
    );
  }
}

/// Compact list of up to three in-progress sessions. Tapping a card resumes
/// that deck's session in its mode (the study route re-queues the deck's
/// unmastered cards and the session-conflict rule retires the stale row).
class _UnfinishedStrip extends StatelessWidget {
  const _UnfinishedStrip({required this.sessions});

  final List<UnfinishedSession> sessions;

  static const int _maxSlots = 3;
  static const double _rowGap = 8;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) return const SizedBox.shrink();

    final shown = sessions.take(_maxSlots).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: _rowGap),
          _UnfinishedCard(session: shown[i]),
        ],
      ],
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
    final accent = tokens.accent('blue');
    final fraction = (session.percentComplete / 100).clamp(0.0, 1.0);

    return AppCard(
      radius: AppRadii.gridTile,
      onTap: () => _resume(context),
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final percentage = '${session.percentComplete}%';
          final percentageStyle = AppType.numeric.copyWith(
            color: tokens.textSecondary,
          );
          final percentageWidth = _measureText(
            context,
            percentage,
            percentageStyle,
            double.infinity,
          ).width;
          final contentWidth = constraints.maxWidth - 35;
          final reflow = contentWidth < percentageWidth + 204;

          final progress = ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 4,
              color: tokens.borderHairline,
              child: FractionallySizedBox(
                widthFactor: fraction,
                alignment: Alignment.centerLeft,
                child: Container(color: accent.fill),
              ),
            ),
          );
          final name = Text(
            session.deckName,
            style: AppType.label.copyWith(color: tokens.textPrimary),
          );
          final percent = Text(
            percentage,
            textAlign: TextAlign.right,
            style: percentageStyle,
          );

          final content = reflow
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    name,
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: progress),
                        const SizedBox(width: 10),
                        percent,
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(flex: 2, child: name),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: progress),
                    const SizedBox(width: 10),
                    percent,
                  ],
                );

          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Stack(
              children: [
                Positioned.fill(
                  right: null,
                  child: Container(width: 7, color: accent.fill),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(21, 12, 14, 12),
                  child: content,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Size _measureText(
  BuildContext context,
  String text,
  TextStyle style,
  double maxWidth,
) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: maxWidth);
  return painter.size;
}

double _deckStackHeight(
  BuildContext context,
  double availableWidth,
  List<MostReviewedDeck> decks,
) {
  const pageFraction = 0.82;
  const pagePadding = 16.0;
  const cardPadding = 36.0;
  final contentWidth =
      (availableWidth * pageFraction - pagePadding - cardPadding).clamp(
        1.0,
        double.infinity,
      );
  var requiredHeight = 260.0;

  for (final deck in decks) {
    var headingHeight = 0.0;
    if (deck.courseName != null) {
      headingHeight =
          _measureText(
            context,
            deck.courseName!.toUpperCase(),
            AppType.overline,
            contentWidth,
          ).height +
          15;
    }
    final titleHeight = _measureText(
      context,
      deck.deckName,
      AppType.title,
      contentWidth,
    ).height;
    final countText = '${deck.cardCount} card${deck.cardCount == 1 ? '' : 's'}';
    final countSize = _measureText(
      context,
      countText,
      AppType.caption,
      contentWidth,
    );
    final actionSize = _measureText(
      context,
      'View Deck',
      AppType.label,
      contentWidth,
    );
    final actionWidth = actionSize.width + 24;
    final actionHeight = actionSize.height.clamp(36.0, double.infinity);
    final footerHeight = countSize.width + 8 + actionWidth <= contentWidth
        ? countSize.height.clamp(actionHeight, double.infinity)
        : countSize.height + 8 + actionHeight;
    requiredHeight = requiredHeight.clamp(
      headingHeight + titleHeight + 16 + footerHeight + cardPadding + 12,
      double.infinity,
    );
  }
  return requiredHeight;
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
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    final middleIndex = (widget.decks.length - 1) ~/ 2;
    _controller = PageController(
      viewportFraction: 0.82,
      initialPage: middleIndex,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.decks.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: _deckStackHeight(context, constraints.maxWidth, widget.decks),
        child: PageView.builder(
          controller: _controller,
          clipBehavior: Clip.none,
          itemCount: widget.decks.length,
          itemBuilder: (context, index) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final page = _controller.hasClients && _controller.page != null
                    ? _controller.page!
                    : index.toDouble();
                final distance = (page - index).abs().clamp(0.0, 1.0);

                final scale = 1 - (distance * 0.12);
                final opacity = (1 - (distance * 0.35)).clamp(0.0, 1.0);
                final blurSigma = distance * 6.0;

                Widget card = _DeckCard(
                  deck: widget.decks[index],
                  isFront: distance < 0.5,
                );

                if (blurSigma > 0.01) {
                  card = ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                    ),
                    child: card,
                  );
                }

                return Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: card,
                    ),
                  ),
                );
              },
            );
          },
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (deck.courseName != null) ...[
                Text(
                  deck.courseName!.toUpperCase(),
                  style: AppType.overline.copyWith(color: accent.text),
                ),
                const SizedBox(height: 3),
                Container(width: 28, height: 2, color: accent.fill),
                const SizedBox(height: 10),
              ],
              Text(
                deck.deckName,
                style: AppType.title.copyWith(color: tokens.textPrimary),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final count = Text(
                '${deck.cardCount} card${deck.cardCount == 1 ? '' : 's'}',
                style: AppType.caption.copyWith(color: tokens.textSecondary),
              );
              final action = TextButton(
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
                child: Text(
                  'View Deck',
                  style: AppType.label.copyWith(color: accent.text),
                ),
              );
              if (!isFront) return count;

              final countWidth = _measureText(
                context,
                '${deck.cardCount} card${deck.cardCount == 1 ? '' : 's'}',
                AppType.caption,
                constraints.maxWidth,
              ).width;
              final actionWidth =
                  _measureText(
                    context,
                    'View Deck',
                    AppType.label,
                    constraints.maxWidth,
                  ).width +
                  24;
              if (countWidth + 8 + actionWidth <= constraints.maxWidth) {
                return Row(
                  children: [
                    count,
                    const Spacer(),
                    const SizedBox(width: 8),
                    action,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  count,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: action),
                ],
              );
            },
          ),
        ],
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
