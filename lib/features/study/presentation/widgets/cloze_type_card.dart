import 'package:flutter/material.dart';

import '../../../../theme/app_geometry.dart';
import '../../../../theme/app_tokens.dart';
import '../../../decks/domain/card.dart';
import '../../domain/cloze_blank.dart';
import '../../domain/cloze_outcome.dart';
import '../../domain/letter_diff.dart';
import '../../domain/levenshtein.dart';
import 'stacked_deck.dart';

/// The Cloze-mode card surface (docs/spec.md §5B, restored in milestone R4).
///
/// Shows the whole card (front then back) with every keyword occurrence turned
/// into a blank. The user fills the blanks in reading order — one active at a
/// time — typing each answer, which is fuzzy-matched on-device
/// ([isClozeMatch], a length-tiered Levenshtein tolerance). A correct answer
/// auto-advances; a miss freezes on that blank, showing a letter-by-letter
/// diff, the real keyword, and an "I was right" override.
///
/// Once the last blank resolves the widget derives a single [ClozeOutcome]
/// (all blanks right first try → correct; any override → overridden; any real
/// miss → missed) and calls [onOutcome] exactly once. There is no manual
/// rating row in this mode (§6).
///
/// All state is widget-local and resets when [card] changes; the study screen
/// also re-keys it per queue position, so a requeue always starts fresh.
class ClozeTypeCard extends StatefulWidget {
  const ClozeTypeCard({
    super.key,
    required this.card,
    required this.onOutcome,
  });

  final FlashCard card;
  final ValueChanged<ClozeOutcome> onOutcome;

  @override
  State<ClozeTypeCard> createState() => _ClozeTypeCardState();
}

class _ClozeTypeCardState extends State<ClozeTypeCard> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  late List<ClozeSegment> _front;
  late List<ClozeSegment> _back;
  late List<String> _answers;

  /// The blank currently being filled; equals `_answers.length` once every
  /// blank is resolved.
  int _active = 0;
  final Set<int> _overridden = {};
  final Set<int> _missed = {};
  final Map<int, String> _attempts = {};

  /// Whether the active blank is frozen on its miss review (diff + override).
  bool _reviewing = false;
  bool _emitted = false;

  @override
  void initState() {
    super.initState();
    _split();
  }

  @override
  void didUpdateWidget(ClozeTypeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) {
      _controller.clear();
      _active = 0;
      _overridden.clear();
      _missed.clear();
      _attempts.clear();
      _reviewing = false;
      _emitted = false;
      _split();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _split() {
    final (front, next) =
        clozeSegments(widget.card.front, widget.card.keywords);
    final (back, _) = clozeSegments(
      widget.card.back,
      widget.card.keywords,
      startIndex: next,
    );
    _front = front;
    _back = back;
    _answers = [
      for (final s in front)
        if (s.isBlank) s.text,
      for (final s in back)
        if (s.isBlank) s.text,
    ];
    // A Cloze-eligible card whose keywords never literally appear has nothing
    // to answer — treat it as fully correct, mirroring how the interim
    // tap-to-reveal card auto-completed a zero-blank card.
    if (_answers.isEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _emit(ClozeOutcome.correct));
    }
  }

  void _submit() {
    if (_reviewing || _active >= _answers.length) return;
    final typed = _controller.text;
    if (typed.trim().isEmpty) return;
    _attempts[_active] = typed;
    if (isClozeMatch(_answers[_active], typed)) {
      _advance();
    } else {
      _focus.unfocus();
      setState(() {
        _missed.add(_active);
        _reviewing = true;
      });
    }
  }

  void _markRight() {
    _missed.remove(_active);
    _overridden.add(_active);
    _advance();
  }

  void _advance() {
    _controller.clear();
    setState(() {
      _reviewing = false;
      _active++;
    });
    if (_active >= _answers.length) {
      _emit(_derive());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  ClozeOutcome _derive() {
    if (_missed.isNotEmpty) return ClozeOutcome.missed;
    if (_overridden.isNotEmpty) return ClozeOutcome.overridden;
    return ClozeOutcome.correct;
  }

  void _emit(ClozeOutcome outcome) {
    if (_emitted) return;
    _emitted = true;
    widget.onOutcome(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StackedDeck(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _label('PROMPT', tokens),
                const SizedBox(height: 10),
                _side(_front, tokens),
                const SizedBox(height: 20),
                Divider(color: tokens.borderHairline, height: 1),
                const SizedBox(height: 20),
                _label('ANSWER', tokens),
                const SizedBox(height: 10),
                _side(_back, tokens),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_active < _answers.length) _input(tokens),
      ],
    );
  }

  Widget _label(String text, AppTokens tokens) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: tokens.textTertiary,
        ),
      );

  Widget _side(List<ClozeSegment> segments, AppTokens tokens) {
    final baseStyle = TextStyle(
      fontSize: 16,
      height: 1.6,
      color: tokens.textPrimary,
    );

    return Text.rich(
      TextSpan(
        children: [
          for (final segment in segments)
            if (!segment.isBlank)
              TextSpan(text: segment.text, style: baseStyle)
            else
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: _Blank(
                  index: segment.blankIndex!,
                  answer: _answers[segment.blankIndex!],
                  active: segment.blankIndex == _active,
                  resolved: segment.blankIndex! < _active,
                  missed: _missed.contains(segment.blankIndex),
                  overridden: _overridden.contains(segment.blankIndex),
                  tokens: tokens,
                  baseStyle: baseStyle,
                ),
              ),
        ],
      ),
    );
  }

  Widget _input(AppTokens tokens) {
    if (_reviewing) {
      return _MissReview(
        answer: _answers[_active],
        attempt: _attempts[_active] ?? '',
        tokens: tokens,
        onRight: _markRight,
        onNext: _advance,
      );
    }

    final canCheck = _controller.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Blank ${_active + 1} of ${_answers.length}',
          style: TextStyle(fontSize: 12, color: tokens.textSecondary),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          focusNode: _focus,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'Type the missing word',
            border: OutlineInputBorder(
              borderRadius: AppRadii.inputRadius,
              borderSide: BorderSide(color: tokens.borderHairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadii.inputRadius,
              borderSide: BorderSide(color: tokens.borderHairline),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: canCheck ? _submit : null,
          child: const Text('Check'),
        ),
      ],
    );
  }
}

/// One blank chip inside the card text — a placeholder before its turn, the
/// active target when it's being filled, and the real keyword once resolved
/// (tinted on a miss so the user sees what it was).
class _Blank extends StatelessWidget {
  const _Blank({
    required this.index,
    required this.answer,
    required this.active,
    required this.resolved,
    required this.missed,
    required this.overridden,
    required this.tokens,
    required this.baseStyle,
  });

  final int index;
  final String answer;
  final bool active;
  final bool resolved;
  final bool missed;
  final bool overridden;
  final AppTokens tokens;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    if (resolved) {
      final color = missed
          ? tokens.accent('red').text
          : (overridden ? tokens.accent('amber').text : tokens.textPrimary);
      return Text(
        answer,
        style: baseStyle.copyWith(fontWeight: FontWeight.w600, color: color),
      );
    }

    final width = answer.length.clamp(3, 12) * 8.0 + 12;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      height: (baseStyle.fontSize ?? 16) + 10,
      width: width,
      decoration: BoxDecoration(
        color: active ? tokens.mutedFill : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border(
          bottom: BorderSide(
            color: active ? tokens.textPrimary : tokens.textTertiary,
            width: active ? 2 : 1,
          ),
        ),
      ),
    );
  }
}

/// The frozen miss state for the active blank: the real answer, a
/// letter-by-letter diff of the attempt, and the "I was right" / "Next" pair.
class _MissReview extends StatelessWidget {
  const _MissReview({
    required this.answer,
    required this.attempt,
    required this.tokens,
    required this.onRight,
    required this.onNext,
  });

  final String answer;
  final String attempt;
  final AppTokens tokens;
  final VoidCallback onRight;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: 16, color: tokens.textPrimary);
    final red = tokens.accent('red').text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Not quite',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: red,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'ANSWER',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: tokens.textTertiary,
          ),
        ),
        const SizedBox(height: 4),
        Text(answer, style: base.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Text(
          'YOUR ANSWER',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: tokens.textTertiary,
          ),
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            children: [
              for (final seg in letterDiff(answer, attempt))
                TextSpan(
                  text: seg.op == DiffOp.missing
                      ? seg.text.toUpperCase()
                      : seg.text,
                  style: switch (seg.op) {
                    DiffOp.match => base,
                    DiffOp.wrong => base.copyWith(color: red),
                    DiffOp.extra => base.copyWith(
                        color: red,
                        decoration: TextDecoration.lineThrough,
                      ),
                    DiffOp.missing => base.copyWith(
                        color: tokens.textTertiary,
                        decoration: TextDecoration.underline,
                      ),
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Underlined = missing · struck-through / red = wrong or extra',
          style: TextStyle(fontSize: 12, color: tokens.textTertiary),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onRight,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('I was right'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: onNext,
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
