import 'dart:async';

import 'package:flutter/material.dart';

import '../../../decks/domain/card.dart';
import '../../domain/feynman_outcome.dart';
import '../../domain/list_content.dart';

/// The Feynman study widget (spec §5D). Shows the single-line side as the topic
/// prompt with a countdown timer, takes a free-written explanation, then shows
/// the multi-line side's points as a self-checkoff list. Any point left
/// unchecked is walked through one at a time as a focused "review the gaps"
/// step before the result is emitted. The checkoff ratio is mapped to a
/// `cards.mastery_level` by [feynmanMasteryFromCheckoff]. Emits that level once.
///
/// Resets on card change; the study screen also re-keys it per card, so a
/// requeue of the same card always starts fresh.
class FeynmanCardView extends StatefulWidget {
  const FeynmanCardView({
    super.key,
    required this.card,
    required this.onResult,
  });

  final FlashCard card;

  /// Called once with the resolved `cards.mastery_level` (0–4).
  final ValueChanged<int> onResult;

  @override
  State<FeynmanCardView> createState() => _FeynmanCardViewState();
}

enum _Stage { synthesis, checkoff, gaps }

/// The starting value of the stage-1 countdown, in seconds (spec §5D). Soft: at
/// zero the timer just stops and turns red — the input stays editable.
const int _timerSeconds = 90;

class _FeynmanCardViewState extends State<FeynmanCardView> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  late ListContent _content = listContentOf(widget.card);
  _Stage _stage = _Stage.synthesis;

  Timer? _timer;
  int _remaining = _timerSeconds;

  late List<bool> _covered = List.filled(_content.lines.length, false);
  List<String> _missed = const [];
  int _gapIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(FeynmanCardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) {
      _controller.clear();
      _timer?.cancel();
      setState(() {
        _content = listContentOf(widget.card);
        _stage = _Stage.synthesis;
        _remaining = _timerSeconds;
        _covered = List.filled(_content.lines.length, false);
        _missed = const [];
        _gapIndex = 0;
      });
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining <= 1) {
        timer.cancel();
        setState(() => _remaining = 0);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  bool get _expired => _remaining <= 0;

  void _toCheckoff() {
    _focusNode.unfocus();
    _timer?.cancel();
    setState(() {
      _remaining = 0;
      _stage = _Stage.checkoff;
    });
  }

  int get _checkedCount => _covered.where((c) => c).length;

  void _finishCheckoff() {
    final total = _content.lines.length;
    final missed = [
      for (var i = 0; i < total; i++)
        if (!_covered[i]) _content.lines[i],
    ];
    if (missed.isEmpty) {
      widget.onResult(feynmanMasteryFromCheckoff(checked: total, total: total));
      return;
    }
    setState(() {
      _missed = missed;
      _gapIndex = 0;
      _stage = _Stage.gaps;
    });
  }

  void _advanceGap() {
    if (_gapIndex < _missed.length - 1) {
      setState(() => _gapIndex++);
      return;
    }
    final total = _content.lines.length;
    widget.onResult(
      feynmanMasteryFromCheckoff(checked: total - _missed.length, total: total),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      _Stage.synthesis => _buildSynthesis(context),
      _Stage.checkoff => _buildCheckoff(context),
      _Stage.gaps => _buildGaps(context),
    };
  }

  Widget _buildSynthesis(BuildContext context) {
    final theme = Theme.of(context);
    final minutes = _remaining ~/ 60;
    final seconds = _remaining % 60;
    final clock = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Explain this in your own words',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                    Text(
                      clock,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _expired
                            ? theme.colorScheme.error
                            : theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(_content.prompt, style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          minLines: 4,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            labelText: 'Your explanation',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (_expired) ...[
          const SizedBox(height: 8),
          Text(
            "Time's up — finish your thought and tap Done.",
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed:
              _controller.text.trim().isEmpty ? null : _toCheckoff,
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _buildCheckoff(BuildContext context) {
    final theme = Theme.of(context);
    final total = _content.lines.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your explanation',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 8),
                Text(
                  _controller.text.trim(),
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Check the points you actually covered',
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < total; i++)
          CheckboxListTile(
            value: _covered[i],
            onChanged: (v) => setState(() => _covered[i] = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(_content.lines[i]),
          ),
        const SizedBox(height: 4),
        Text(
          '$_checkedCount of $total covered',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _finishCheckoff,
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildGaps(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLast = _gapIndex >= _missed.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Review the gaps · ${_gapIndex + 1} of ${_missed.length}',
          style: theme.textTheme.labelMedium?.copyWith(color: scheme.outline),
        ),
        const SizedBox(height: 8),
        Card(
          color: scheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You didn't cover this",
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: scheme.onSecondaryContainer),
                ),
                const SizedBox(height: 12),
                Text(
                  _missed[_gapIndex],
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: scheme.onSecondaryContainer),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _advanceGap,
          child: Text(isLast ? 'Continue' : 'Got it'),
        ),
      ],
    );
  }
}
