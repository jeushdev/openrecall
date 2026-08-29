import 'package:flutter/material.dart';

import '../../../decks/domain/card.dart';
import '../../domain/cloze_blank.dart';
import '../../domain/cloze_outcome.dart';
import '../../domain/letter_diff.dart';
import '../../domain/levenshtein.dart';

/// The Cloze study widget (spec §5B). Shows the whole card with every
/// occurrence of the keyword blanked, takes a typed answer, fuzzy-matches it
/// on-device, then shows a letter-by-letter diff, the real keyword, and — on a
/// miss — an "I was right" override. Emits a [ClozeOutcome] once, on Continue.
///
/// Resets on card change; the study screen also re-keys it per card, so a
/// requeue of the same card always starts fresh.
class ClozeCardView extends StatefulWidget {
  const ClozeCardView({
    super.key,
    required this.card,
    required this.onResult,
  });

  final FlashCard card;
  final ValueChanged<ClozeOutcome> onResult;

  @override
  State<ClozeCardView> createState() => _ClozeCardViewState();
}

class _ClozeCardViewState extends State<ClozeCardView> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _checked = false;
  bool _match = false;
  bool _overridden = false;

  @override
  void didUpdateWidget(ClozeCardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) {
      _controller.clear();
      setState(() {
        _checked = false;
        _match = false;
        _overridden = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _keyword => widget.card.keyword ?? '';

  void _check() {
    _focusNode.unfocus();
    setState(() {
      _checked = true;
      _match = isClozeMatch(_keyword, _controller.text);
    });
  }

  void _continue() {
    final ClozeOutcome outcome;
    if (_match) {
      outcome = ClozeOutcome.correct;
    } else if (_overridden) {
      outcome = ClozeOutcome.overridden;
    } else {
      outcome = ClozeOutcome.missed;
    }
    widget.onResult(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  'Fill the blank',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 12),
                Text(
                  blankKeyword(widget.card.front, widget.card.keyword),
                  style: theme.textTheme.titleMedium,
                ),
                const Divider(height: 32),
                Text(
                  blankKeyword(widget.card.back, widget.card.keyword),
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: !_checked,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Your answer',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (!_checked && _controller.text.trim().isNotEmpty) _check();
          },
        ),
        const SizedBox(height: 12),
        if (!_checked)
          FilledButton(
            onPressed:
                _controller.text.trim().isEmpty ? null : _check,
            child: const Text('Check'),
          )
        else ...[
          _ResultBanner(match: _match),
          const SizedBox(height: 12),
          _AnswerReveal(keyword: _keyword, attempt: _controller.text),
          if (!_match) ...[
            const SizedBox(height: 12),
            if (_overridden)
              Text(
                "Counted as “I was right” — this card is marked Familiar.",
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              )
            else
              OutlinedButton.icon(
                onPressed: () => setState(() => _overridden = true),
                icon: const Icon(Icons.check),
                label: const Text('I was right'),
              ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _continue,
            child: const Text('Continue'),
          ),
        ],
      ],
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.match});

  final bool match;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = match ? scheme.primaryContainer : scheme.errorContainer;
    final fg = match ? scheme.onPrimaryContainer : scheme.onErrorContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(match ? Icons.check_circle : Icons.cancel, color: fg),
          const SizedBox(width: 12),
          Text(
            match ? 'Correct' : 'Not quite',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

class _AnswerReveal extends StatelessWidget {
  const _AnswerReveal({required this.keyword, required this.attempt});

  final String keyword;
  final String attempt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = theme.textTheme.titleMedium ?? const TextStyle();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Answer',
          style: theme.textTheme.labelMedium
              ?.copyWith(color: scheme.outline),
        ),
        const SizedBox(height: 4),
        Text(keyword, style: base),
        const SizedBox(height: 12),
        Text(
          'Your answer',
          style: theme.textTheme.labelMedium
              ?.copyWith(color: scheme.outline),
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            children: [
              for (final segment in letterDiff(keyword, attempt))
                TextSpan(
                  text: segment.op == DiffOp.missing
                      ? segment.text.toUpperCase()
                      : segment.text,
                  style: switch (segment.op) {
                    DiffOp.match => base,
                    DiffOp.wrong =>
                      base.copyWith(color: scheme.error),
                    DiffOp.extra => base.copyWith(
                        color: scheme.error,
                        decoration: TextDecoration.lineThrough,
                      ),
                    DiffOp.missing => base.copyWith(
                        color: scheme.outline,
                        decoration: TextDecoration.underline,
                      ),
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Underlined = missing · struck-through / red = wrong or extra',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
        ),
      ],
    );
  }
}
