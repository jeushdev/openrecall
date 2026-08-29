import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_tokens.dart';
import '../../decks/application/deck_providers.dart';
import '../../decks/domain/study_mode.dart';
import '../application/session_controller.dart';
import '../domain/flip_rating.dart';
import '../domain/session_length.dart';
import '../domain/study_session.dart';
import '../domain/study_session_state.dart';
import 'widgets/cloze_reveal_card.dart';
import 'widgets/flip_card.dart';
import 'widgets/list_reveal_card.dart';
import 'widgets/mode_picker.dart';
import 'widgets/park_prompt_dialog.dart';
import 'widgets/rating_row.dart';
import 'widgets/session_summary_view.dart';
import 'widgets/study_progress_bar.dart';

/// The study session screen (ui-spec-v1 §6.2), reached at
/// `/study/:deckId?scope=due|all` outside the shell — no bottom nav bar, no
/// app bar.
///
/// Flow: pick a mode (skipped when the deck supports only one non-Feynman
/// mode) → the shared [SessionController] builds the queue for [scope] → the
/// per-mode card surface with a gated rating row → the Session Summary. Feynman
/// mode is deferred to U6, so it is never offered here.
///
/// Every study interaction is optimistic and synchronous — ratings advance the
/// queue and the progress bar immediately, never awaiting a write (§2).
class StudySessionScreen extends ConsumerStatefulWidget {
  const StudySessionScreen({
    super.key,
    required this.deckId,
    required this.scope,
  });

  final String deckId;
  final CardScope scope;

  @override
  ConsumerState<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends ConsumerState<StudySessionScreen> {
  bool _leaving = false;
  bool _parkPromptOpen = false;
  bool _startRequested = false;

  bool _isOurSession(StudySessionState? state) =>
      state != null && state.deckId == widget.deckId;

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
    ref.read(sessionControllerProvider.notifier).start(
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
    setState(() => _startRequested = false);
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
    ref.listen<AsyncValue<StudySessionState?>>(sessionControllerProvider,
        (prev, next) {
      if (next.value?.phase == SessionPhase.parkPrompt &&
          _isOurSession(next.value)) {
        _handleParkPrompt();
      }
    });

    final session = ref.watch(sessionControllerProvider);

    // A live or finished session for this deck takes over the screen.
    if (_isOurSession(session.value)) {
      final state = session.value!;
      if (state.isComplete && state.outcome != null) {
        return SessionSummaryView(
          mode: state.session.studyMode,
          deckName: state.deckName,
          outcome: state.outcome!,
          hasParked: state.parkedCardIds.isNotEmpty,
          onDrillParked: () =>
              ref.read(sessionControllerProvider.notifier).startParkedDrill(
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
          onExit: _exitAndLeave,
          onRate: (rating) =>
              ref.read(sessionControllerProvider.notifier).rate(rating),
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
            actionLabel: empty ? null : 'Retry',
            onAction: empty ? null : _retry,
            onBack: _leave,
          ),
        );
      }
    }

    // Pre-session: choose a study mode.
    final cards = ref.watch(deckCardsProvider(widget.deckId));
    return _Shell(
      child: cards.when(
        loading: () => const _Spinner(),
        error: (_, _) => _Message(
          text: "Couldn't load this deck.",
          onBack: _leave,
        ),
        data: (list) {
          if (list.isEmpty) {
            return _Message(
              text: 'This deck has no cards yet.',
              onBack: _leave,
            );
          }
          final available = availableModes(list)..remove(StudyMode.feynman);
          final modes =
              StudyMode.values.where(available.contains).toList();
          if (modes.length == 1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_startRequested) _start(modes.first);
            });
            return const _Spinner();
          }
          return ModePicker(modes: modes, onSelected: _start);
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
              style: TextStyle(fontSize: 15, color: tokens.textPrimary),
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
    required this.onExit,
    required this.onRate,
  });

  final StudySessionState state;
  final VoidCallback onExit;
  final ValueChanged<FlipRating> onRate;

  @override
  State<_ActiveBody> createState() => _ActiveBodyState();
}

class _ActiveBodyState extends State<_ActiveBody> {
  bool _flipped = false;
  bool _revealed = false;

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

  bool get _ratingEnabled => _isFlip ? _flipped : _revealed;

  void _onSwipe(DragEndDetails details) {
    if (!_isFlip || !_flipped) return;
    final v = details.primaryVelocity ?? 0;
    if (v <= -300) {
      widget.onRate(FlipRating.unfamiliar); // swipe-left → 0
    } else if (v >= 300) {
      widget.onRate(FlipRating.mastered); // swipe-right → 4
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final state = widget.state;
    final item = state.current!;
    final key = ValueKey('${item.sessionCardId}:${item.position}');

    final Widget cardArea = switch (state.session.studyMode) {
      StudyMode.cloze => ClozeRevealCard(
          key: key,
          card: item.card,
          onAllRevealed: () => setState(() => _revealed = true),
        ),
      StudyMode.list => ListRevealCard(
          key: key,
          card: item.card,
          onAllRevealed: () => setState(() => _revealed = true),
        ),
      // Feynman is never routed here in U5; fall through to Flip.
      StudyMode.flip || StudyMode.feynman => GestureDetector(
          onHorizontalDragEnd: _onSwipe,
          child: FlipCard(
            key: key,
            card: item.card,
            onFlippedChanged: (f) => setState(() => _flipped = f),
          ),
        ),
    };

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
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  color: tokens.textSecondary,
                  onPressed: widget.onExit,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: cardArea,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: RatingRow(
                  enabled: _ratingEnabled,
                  onRate: widget.onRate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
