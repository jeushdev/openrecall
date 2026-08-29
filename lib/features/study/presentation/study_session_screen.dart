import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/session_controller.dart';
import '../domain/flip_rating.dart';
import '../domain/study_session_state.dart';
import 'study_session_args.dart';
import 'widgets/flip_card_view.dart';
import 'widgets/park_prompt_dialog.dart';
import 'widgets/rating_bar.dart';
import 'widgets/session_progress_indicator.dart';

/// The study execution screen. Milestone 6 handles Flip & Rate only (spec §5A);
/// the other modes route here later. Exiting — the close button, system back, or
/// completion — returns to the Deck Overview.
class StudySessionScreen extends ConsumerStatefulWidget {
  const StudySessionScreen({super.key, required this.args});

  final StudySessionArgs? args;

  @override
  ConsumerState<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends ConsumerState<StudySessionScreen> {
  bool _leaving = false;
  bool _parkPromptOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startIfNeeded());
  }

  void _startIfNeeded() {
    final args = widget.args;
    if (args == null) {
      _leave();
      return;
    }
    ref.read(sessionControllerProvider.notifier).start(
          deckId: args.deckId,
          deckName: args.deckName,
          mode: args.mode,
          lengthMode: args.lengthMode,
          cap: args.cap,
        );
  }

  void _leave() {
    if (_leaving) return;
    _leaving = true;
    if (context.canPop()) context.pop();
  }

  void _exitAndLeave() {
    ref.read(sessionControllerProvider.notifier).exit();
    _leave();
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
      switch (next.value?.phase) {
        case SessionPhase.completed:
          _leave();
        case SessionPhase.parkPrompt:
          _handleParkPrompt();
        case SessionPhase.studying:
        case null:
          break;
      }
    });

    final session = ref.watch(sessionControllerProvider);
    return session.when(
      loading: () => _Frame(
        title: widget.args?.deckName,
        child: const _Centered(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Building your session…'),
          ],
        ),
      ),
      error: (error, _) => _Frame(
        title: widget.args?.deckName,
        child: _ErrorBody(
          isEmptyQueue: error is EmptyQueueException,
          onRetry: _startIfNeeded,
          onBack: _leave,
        ),
      ),
      data: (state) {
        if (state == null || state.current == null) {
          return _Frame(title: widget.args?.deckName, child: const SizedBox());
        }
        return _ActiveBody(
          state: state,
          onExit: _exitAndLeave,
          onRate: ref.read(sessionControllerProvider.notifier).rate,
        );
      },
    );
  }
}

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

  String get _presentationKey {
    final item = widget.state.current!;
    return '${item.sessionCardId}:${item.position}';
  }

  @override
  void didUpdateWidget(_ActiveBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldItem = oldWidget.state.current;
    final newItem = widget.state.current;
    if (oldItem?.sessionCardId != newItem?.sessionCardId ||
        oldItem?.position != newItem?.position) {
      _flipped = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final item = state.current!;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        widget.onExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(state.deckName ?? 'Studying'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onExit,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SessionProgressIndicator(
              resolved: state.resolvedCount,
              total: state.totalCards,
            ),
            const SizedBox(height: 16),
            FlipCardView(
              key: ValueKey(_presentationKey),
              card: item.card,
              onFlippedChanged: (f) => setState(() => _flipped = f),
            ),
            const SizedBox(height: 24),
            RatingBar(enabled: _flipped, onRate: widget.onRate),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.isEmptyQueue,
    required this.onRetry,
    required this.onBack,
  });

  final bool isEmptyQueue;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return _Centered(
      children: [
        Text(
          isEmptyQueue
              ? 'Nothing to study — every card here is already mastered.'
              : "Couldn't start this session.",
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (!isEmptyQueue) ...[
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
          const SizedBox(height: 8),
        ],
        TextButton(onPressed: onBack, child: const Text('Back')),
      ],
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'Studying')),
      body: child,
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
