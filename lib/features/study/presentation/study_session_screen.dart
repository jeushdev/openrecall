import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_routes.dart';
import '../../../theme/app_haptics.dart';
import '../../../theme/app_tokens.dart';
import '../../../theme/app_type.dart';
import '../../decks/application/deck_providers.dart';
import '../../decks/application/offline_runtime_providers.dart';
import '../../decks/data/cache_first_deck_repository.dart';
import '../../decks/domain/study_mode.dart';
import '../../settings/application/settings_providers.dart';
import '../../settings/data/study_appearance_preferences.dart';
import '../application/feynman_timer_providers.dart';
import '../application/pre_session_cards_provider.dart';
import '../application/session_controller.dart';
import '../domain/cloze_outcome.dart';
import '../domain/flip_rating.dart';
import '../domain/session_length.dart';
import '../domain/study_session.dart';
import '../domain/study_session_state.dart';
import 'widgets/cloze_type_card.dart';
import 'widgets/feynman_card_view.dart';
import 'widgets/feynman_timer_picker.dart';
import 'widgets/flip_card.dart';
import 'widgets/mode_picker.dart';
import 'widgets/park_prompt_dialog.dart';
import 'widgets/rating_row.dart';
import 'widgets/session_summary_view.dart';
import 'widgets/study_progress_bar.dart';

/// The study session screen (ui-spec-v1 §6.2), reached at
/// `/study/:deckId?scope=due|all` outside the shell — no bottom nav bar, no
/// app bar.
///
/// Flow: pick a mode (skipped when the deck supports only one mode) → for
/// Feynman only, pick the per-card timer preset (§6.2.1) → the shared
/// [SessionController] builds the queue for [scope] → the per-mode card surface
/// with a gated rating row → the Session Summary.
///
/// Every study interaction is optimistic and synchronous — ratings advance the
/// queue and the progress bar immediately, never awaiting a write (§2).
class StudySessionScreen extends ConsumerStatefulWidget {
  const StudySessionScreen({
    super.key,
    required this.deckId,
    required this.scope,
    this.requestedMode,
  });

  final String deckId;
  final CardScope scope;

  /// The mode the deck-detail picker chose, forwarded as go_router `extra`
  /// ([StudySessionArgs.mode]). When set, the screen starts (or resumes) that
  /// mode directly instead of showing its own in-screen [ModePicker]. Null for
  /// a direct `/study/:deckId` navigation with no `extra` — that path keeps the
  /// in-screen picker as its fallback.
  final StudyMode? requestedMode;

  @override
  ConsumerState<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends ConsumerState<StudySessionScreen> {
  bool _leaving = false;
  bool _parkPromptOpen = false;
  bool _startRequested = false;

  /// Set when the user picks Feynman: the timer-preset picker (§6.2.1) shows
  /// before the session starts. Session-local — never a global setting.
  bool _awaitingFeynmanDuration = false;
  int? _feynmanSeconds;

  bool _isOurSession(StudySessionState? state) =>
      state != null && state.deckId == widget.deckId;

  /// Whether [build] should hand the screen over to a leftover
  /// [sessionControllerProvider] session rather than start a new one.
  ///
  /// With no [StudySessionScreen.requestedMode] (direct entry) any session for
  /// this deck is "ours" — the historical behaviour. With a requested mode
  /// (deck-detail picker) we only re-attach to a *live* session already in that
  /// mode; a leftover session in a different mode, or a finished one, means the
  /// user asked for something new and we start fresh.
  bool _shouldReattach(StudySessionState? state) {
    if (!_isOurSession(state)) return false;
    final requested = widget.requestedMode;
    if (requested == null) return true;
    // A session this screen drove to completion: keep it so the Summary
    // renders. (A completed session left over from before we mounted —
    // _startRequested still false — instead means the user asked for a new run.)
    if (_startRequested && state!.isComplete) return true;
    return state!.session.studyMode == requested && !state.isComplete;
  }

  void _leave() {
    if (_leaving) return;
    _leaving = true;
    if (mounted && context.canPop()) context.pop();
  }

  void _exitAndLeave() {
    ref.read(sessionControllerProvider.notifier).exit();
    _leave();
  }

  void _doneFromSummary() {
    ref.read(sessionControllerProvider.notifier).reset();
    _leave();
  }

  String? _deckName() {
    final decks = ref.read(decksProvider).value;
    if (decks == null) return null;
    for (final deck in decks) {
      if (deck.id == widget.deckId) return deck.name;
    }
    return null;
  }

  void _start(StudyMode mode) {
    if (_startRequested) return;
    setState(() => _startRequested = true);
    ref
        .read(sessionControllerProvider.notifier)
        .start(
          deckId: widget.deckId,
          deckName: _deckName(),
          mode: mode,
          lengthMode: SessionLengthMode.untilMastered,
          cap: null,
          cardScope: widget.scope,
        );
  }

  void _retry() {
    ref.read(sessionControllerProvider.notifier).reset();
    setState(() {
      _startRequested = false;
      _awaitingFeynmanDuration = false;
      _feynmanSeconds = null;
    });
  }

  /// Re-runs the pre-session card load after a load error / connection timeout.
  void _retryLoad() {
    ref.invalidate(preSessionCardsProvider(widget.deckId));
  }

  /// Opens the Import screen for this deck from a "can't study" dead-end. On
  /// return the pre-session load is invalidated so a now-populated deck can be
  /// studied without leaving the screen.
  Future<void> _importCards() async {
    await context.pushNamed(
      AppRoutes.importCardsName,
      pathParameters: {'deckId': widget.deckId},
    );
    if (!mounted) return;
    ref.invalidate(preSessionCardsProvider(widget.deckId));
  }

  /// Routes a picked mode: Feynman detours through the timer-preset picker
  /// first (§6.2.1); every other mode starts the session straight away.
  void _onModeSelected(StudyMode mode) {
    if (mode == StudyMode.feynman) {
      setState(() => _awaitingFeynmanDuration = true);
    } else {
      _start(mode);
    }
  }

  Future<void> _handleParkPrompt() async {
    if (_parkPromptOpen) return;
    _parkPromptOpen = true;
    final park = await ParkPromptDialog.show(context);
    _parkPromptOpen = false;
    if (!mounted) return;
    final notifier = ref.read(sessionControllerProvider.notifier);
    if (park ?? false) {
      notifier.confirmPark();
    } else {
      notifier.declinePark();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<StudySessionState?>>(sessionControllerProvider, (
      prev,
      next,
    ) {
      if (next.value?.phase == SessionPhase.parkPrompt &&
          _isOurSession(next.value)) {
        _handleParkPrompt();
      }
    });

    final session = ref.watch(sessionControllerProvider);

    // The §6.5 "Card text size" preset, applied only to the card surface below
    // (and the Feynman reference overlay). A storage failure degrades to the
    // medium (1.0) default, like the other study-appearance toggles.
    final appearance = ref.watch(studyAppearanceProvider).asData?.value;
    final cardFontSize = appearance?.cardFontSize ?? CardFontSize.medium;

    // Deck-detail picker forwarded a mode: start it (or, if a live session in
    // that same mode is still around, fall through and resume it below).
    if (widget.requestedMode != null &&
        !_startRequested &&
        !_awaitingFeynmanDuration &&
        !_shouldReattach(session.value)) {
      final mode = widget.requestedMode!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_startRequested && !_awaitingFeynmanDuration) {
          _onModeSelected(mode);
        }
      });
      return const _Shell(child: _Spinner());
    }

    // A live or finished session for this deck takes over the screen.
    if (_shouldReattach(session.value)) {
      final state = session.value!;
      if (state.isComplete && state.outcome != null) {
        return SessionSummaryView(
          mode: state.session.studyMode,
          deckName: state.deckName,
          outcome: state.outcome!,
          hasParked: state.parkedCardIds.isNotEmpty,
          onDrillParked: () => ref
              .read(sessionControllerProvider.notifier)
              .startParkedDrill(
                deckId: state.deckId,
                deckName: state.deckName,
                mode: state.session.studyMode,
                parkedCardIds: state.parkedCardIds.toList(),
              ),
          onDone: _doneFromSummary,
        );
      }
      if (state.current != null) {
        return _ActiveBody(
          state: state,
          cardTextScale: cardFontSize.scale,
          feynmanSeconds: _feynmanSeconds ?? FeynmanTimerPicker.defaultSeconds,
          onExit: _exitAndLeave,
          onRate: (rating) =>
              ref.read(sessionControllerProvider.notifier).rate(rating),
          onCloze: (outcome) =>
              ref.read(sessionControllerProvider.notifier).submitCloze(outcome),
        );
      }
      return const _Shell(child: _Spinner());
    }

    // The session is loading or errored — only after we asked it to start.
    if (_startRequested) {
      if (session.isLoading) return const _Shell(child: _Spinner());
      if (session.hasError) {
        final empty = session.error is EmptyQueueException;
        return _Shell(
          child: _Message(
            text: empty
                ? 'Nothing to study — every card here is already mastered.'
                : "Couldn't start this session.",
            actionLabel: empty ? 'Add cards' : 'Retry',
            onAction: empty ? _importCards : _retry,
            onBack: _leave,
          ),
        );
      }
    }

    // start() has been asked for, but its state transition hasn't landed yet
    // (e.g. flushing pending writes before switching a live session's mode).
    // Hold on a spinner rather than briefly flashing the in-screen picker.
    if (_startRequested) return const _Shell(child: _Spinner());

    // Feynman: pick the per-card timer preset before the session starts.
    if (_awaitingFeynmanDuration && !_startRequested) {
      return _Shell(
        child: FeynmanTimerPicker(
          onSelected: (seconds) {
            setState(() => _feynmanSeconds = seconds);
            // Record the choice for the Settings "last used" row (§6.5).
            // Fire-and-forget — it never gates starting the session.
            ref.read(feynmanTimerPreferenceProvider).setLastUsed(seconds);
            _start(StudyMode.feynman);
          },
        ),
      );
    }

    // Pre-session: choose a study mode. Reads local-first and is bounded by a
    // timeout (see [preSessionCardsProvider]) so this can never sit spinning on
    // an unanswered network call — ui-spec-v1 §2.
    ref.watch(offlineDeckObservationProvider(widget.deckId));
    final cards = ref.watch(preSessionCardsProvider(widget.deckId));
    return _Shell(
      child: cards.when(
        loading: () => const _Spinner(),
        error: (error, _) => _Message(
          text: error is DeckUnavailableOfflineException
              ? "This deck isn't available offline. Connect to the internet to download it."
              : error is DeckLoadTimeoutException
              ? "Couldn't reach your decks — check your connection."
              : "Couldn't load this deck.",
          actionLabel: 'Retry',
          onAction: _retryLoad,
          onBack: _leave,
        ),
        data: (list) {
          if (list.isEmpty) {
            return _Message(
              text: 'Nothing to study in this deck yet.',
              actionLabel: 'Add cards',
              onAction: _importCards,
              onBack: _leave,
            );
          }
          final available = availableModes(list);
          final modes = StudyMode.values.where(available.contains).toList();
          if (modes.length == 1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_startRequested) _onModeSelected(modes.first);
            });
            return const _Spinner();
          }
          return ModePicker(modes: modes, onSelected: _onModeSelected);
        },
      ),
    );
  }
}

/// A plain full-screen frame for the pre-session / loading / error states —
/// token background, no app bar, safe-area aware.
class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(child: child),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    required this.onBack,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final VoidCallback onBack;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppType.bodyLarge.copyWith(color: tokens.textPrimary),
            ),
            const SizedBox(height: 16),
            if (actionLabel != null && onAction != null) ...[
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              const SizedBox(height: 8),
            ],
            TextButton(onPressed: onBack, child: const Text('Back')),
          ],
        ),
      ),
    );
  }
}

/// The running-session body: progress bar, a minimal close affordance, the
/// per-mode card surface, and the gated rating row.
class _ActiveBody extends StatefulWidget {
  const _ActiveBody({
    required this.state,
    required this.cardTextScale,
    required this.feynmanSeconds,
    required this.onExit,
    required this.onRate,
    required this.onCloze,
  });

  final StudySessionState state;

  /// The linear `textScaler` multiplier for the card surface, from the §6.5
  /// "Card text size" setting. Applied via a scoped [MediaQuery] so only the
  /// card scales — the progress bar, counter, and rating row stay put.
  final double cardTextScale;

  /// The per-card countdown length for Feynman mode (§6.2.1); ignored by every
  /// other mode.
  final int feynmanSeconds;
  final VoidCallback onExit;
  final ValueChanged<FlipRating> onRate;

  /// Cloze auto-derives its result per card (§6) and reports it here instead of
  /// going through the rating row.
  final ValueChanged<ClozeOutcome> onCloze;

  @override
  State<_ActiveBody> createState() => _ActiveBodyState();
}

class _ActiveBodyState extends State<_ActiveBody> {
  bool _flipped = false;
  bool _revealed = false;

  /// Which way the outgoing card slides on the next advance. A gentle upward
  /// drift is the default for non-rating advances (e.g. a confirmed park); each
  /// rating overrides it with a direction that matches the verdict.
  Offset _exitOffset = const Offset(0, -0.06);

  /// The directional exit "nudge" for a rating's `mastery_level`: Unfamiliar
  /// throws the card left, Mastered right, the middle verdicts nudge it down.
  Offset _exitFor(int level) => switch (level) {
    0 => const Offset(-0.55, 0),
    4 => const Offset(0.55, 0),
    _ => const Offset(0, 0.22),
  };

  /// The rating path for every mode that uses the rating row (Flip, Feynman)
  /// plus the Flip swipe gestures. Fires the haptic and records the exit
  /// direction, then advances the queue synchronously — the animation never
  /// gates it.
  void _rate(FlipRating rating) {
    _hapticFor(rating.level);
    setState(() => _exitOffset = _exitFor(rating.level));
    widget.onRate(rating);
  }

  /// Mastered (4) commits the card out of the queue for good — a firmer buzz;
  /// every other verdict is a lighter rating tap (ui-spec-v3 §3, §5.2).
  void _hapticFor(int level) {
    if (level == 4) {
      AppHaptics.commit();
    } else {
      AppHaptics.rating();
    }
  }

  /// Cloze's auto-derived outcome, under the same non-blocking contract as
  /// [_rate].
  void _cloze(ClozeOutcome outcome) {
    _hapticFor(outcome.masteryLevel);
    setState(() => _exitOffset = _exitFor(outcome.masteryLevel));
    widget.onCloze(outcome);
  }

  @override
  void didUpdateWidget(_ActiveBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldItem = oldWidget.state.current;
    final newItem = widget.state.current;
    if (oldItem?.sessionCardId != newItem?.sessionCardId ||
        oldItem?.position != newItem?.position) {
      _flipped = false;
      _revealed = false;
    }
  }

  bool get _isFlip => widget.state.session.studyMode == StudyMode.flip;

  bool get _isCloze => widget.state.session.studyMode == StudyMode.cloze;

  bool get _isFeynman => widget.state.session.studyMode == StudyMode.feynman;

  bool get _ratingEnabled => _isFlip ? _flipped : _revealed;

  void _onSwipe(DragEndDetails details) {
    if (!_isFlip || !_flipped) return;
    final v = details.primaryVelocity ?? 0;
    if (v <= -300) {
      _rate(FlipRating.unfamiliar); // swipe-left → 0
    } else if (v >= 300) {
      _rate(FlipRating.mastered); // swipe-right → 4
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final state = widget.state;
    final item = state.current!;
    final key = ValueKey('${item.sessionCardId}:${item.position}');

    // Only the card surface scales its text to the §6.5 preset — the header and
    // rating row below stay at the app's normal size.
    final Widget cardArea = MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(widget.cardTextScale)),
      child: switch (state.session.studyMode) {
        StudyMode.cloze => ClozeTypeCard(
          key: key,
          card: item.card,
          onOutcome: _cloze,
        ),
        StudyMode.feynman => FeynmanCardView(
          key: key,
          card: item.card,
          durationSeconds: widget.feynmanSeconds,
          onFinished: () => setState(() => _revealed = true),
        ),
        StudyMode.flip => GestureDetector(
          onHorizontalDragEnd: _onSwipe,
          child: FlipCard(
            key: key,
            card: item.card,
            onFlippedChanged: (f) => setState(() => _flipped = f),
          ),
        ),
      },
    );

    // Card-to-card motion: the outgoing card slides + fades toward [_exitOffset]
    // as the next sweeps in from the same side. Keyed strictly on the
    // session-card id + queue position so any change of current card animates.
    final Widget animatedCardArea = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: _exitOffset,
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: key, child: cardArea),
    );

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onExit();
      },
      child: Scaffold(
        backgroundColor: tokens.background,
        body: SafeArea(
          child: Column(
            children: [
              StudyProgressBar(
                completedCount: state.resolvedCount,
                totalCount: state.totalCards,
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: tokens.textSecondary,
                    onPressed: widget.onExit,
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(
                      '${state.resolvedCount} / ${state.totalCards}',
                      style: AppType.numeric.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              // Center the card in whatever height is left between the header
              // and the rating row, but let it scroll if it can't fit (UX2).
              Expanded(
                child: LayoutBuilder(
                  builder: (context, viewportConstraints) =>
                      SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: viewportConstraints.maxHeight,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Center(child: animatedCardArea),
                          ),
                        ),
                      ),
                ),
              ),
              // Cloze auto-derives its result per card and has no rating row
              // (§6). Feynman only reveals the row once the timer stops (§6.2);
              // Flip shows it greyed until the card is flipped.
              if (!_isCloze && (!_isFeynman || _revealed))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  child: RatingRow(enabled: _ratingEnabled, onRate: _rate),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
