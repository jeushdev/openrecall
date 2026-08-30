import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_tokens.dart';
import '../../../decks/domain/card.dart';
import 'feynman_reference_dialog.dart';
import 'stacked_deck.dart';

/// The Feynman-mode card surface (ui-spec-v1 §6.2 / §6.2.1).
///
/// No text input anywhere. The card prompt is visible immediately, but the
/// countdown is strictly gated on a "Ready" tap — a forward-only
/// Pre-Ready → Running → Finished machine:
///
/// - **Pre-Ready**: prompt + a static `m:ss` readout + a "Ready" button. No
///   "Finished" button yet.
/// - **Running**: prompt + a live countdown + a "Finished" button. Tapping
///   Finished *or* the timer reaching `0:00` both go to Finished, paired with
///   [HapticFeedback.mediumImpact].
/// - **Finished**: prompt + a "Reveal reference" chip ([FeynmanReferenceDialog]).
///   The 0–4 rating row is owned by the study screen and it gates on
///   [onFinished] having fired.
///
/// Resets to Pre-Ready whenever [card] changes; the screen also re-keys this
/// widget per queue position, so a requeued card always starts fresh.
class FeynmanCardView extends StatefulWidget {
  const FeynmanCardView({
    super.key,
    required this.card,
    required this.durationSeconds,
    required this.onFinished,
  });

  final FlashCard card;

  /// The per-card countdown length, chosen once for the session (§6.2.1).
  final int durationSeconds;

  /// Fired exactly once, when the card enters the Finished state (Finished tap
  /// or `0:00`). The screen reveals and enables the rating row on this.
  final VoidCallback onFinished;

  @override
  State<FeynmanCardView> createState() => _FeynmanCardViewState();
}

enum _Phase { preReady, running, finished }

class _FeynmanCardViewState extends State<FeynmanCardView> {
  _Phase _phase = _Phase.preReady;
  late int _remaining = widget.durationSeconds;
  Timer? _timer;

  @override
  void didUpdateWidget(FeynmanCardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) {
      _timer?.cancel();
      setState(() {
        _phase = _Phase.preReady;
        _remaining = widget.durationSeconds;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() => _phase = _Phase.running);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        _finish();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _finish() {
    if (_phase == _Phase.finished) return;
    _timer?.cancel();
    HapticFeedback.mediumImpact();
    setState(() {
      _phase = _Phase.finished;
      _remaining = 0;
    });
    widget.onFinished();
  }

  String get _clock {
    final m = _remaining ~/ 60;
    final s = _remaining % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    // A concept card's Feynman prompt is its front; the back is the reference
    // (docs/spec-v3-card-model.md).
    final prompt = widget.card.front.trim();

    return StackedDeck(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 260),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'EXPLAIN THIS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: tokens.textTertiary,
                    ),
                  ),
                  Text(
                    _clock,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _phase == _Phase.running
                          ? tokens.textPrimary
                          : tokens.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                prompt,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.4,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 22),
              _action(tokens),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(AppTokens tokens) {
    switch (_phase) {
      case _Phase.preReady:
        return Column(
          children: [
            Text(
              'Take a moment, then start the clock.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _start,
              child: const Text('Ready'),
            ),
          ],
        );
      case _Phase.running:
        return Column(
          children: [
            Text(
              'Explain the prompt out loud in your own words.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _finish,
              child: const Text('Finished'),
            ),
          ],
        );
      case _Phase.finished:
        return Align(
          child: ActionChip(
            avatar: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Reveal reference'),
            onPressed: () =>
                FeynmanReferenceDialog.show(context, widget.card),
          ),
        );
    }
  }
}
