import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../../decks/domain/card.dart';
import '../../domain/cloze_blank.dart';
import 'stacked_deck.dart';

/// The Cloze-mode card surface (ui-spec-v1 §6.2).
///
/// Shows the whole card (front then back) with every occurrence of the keyword
/// rendered as an inline tappable "blank" chip. Each blank is revealed
/// individually; [onAllRevealed] fires once every blank has been tapped. Reveal
/// state lives here in widget-local state — never in session state (§6.2) — and
/// resets when [card] changes (the screen also re-keys per queue position).
///
/// No swipe gestures in this mode: it is tactile-only per the architecture
/// invariant (§6.2).
class ClozeRevealCard extends StatefulWidget {
  const ClozeRevealCard({
    super.key,
    required this.card,
    required this.onAllRevealed,
  });

  final FlashCard card;
  final VoidCallback onAllRevealed;

  @override
  State<ClozeRevealCard> createState() => _ClozeRevealCardState();
}

class _ClozeRevealCardState extends State<ClozeRevealCard> {
  late List<ClozeSegment> _front;
  late List<ClozeSegment> _back;
  late int _blankCount;
  final Set<int> _revealed = {};

  @override
  void initState() {
    super.initState();
    _split();
  }

  @override
  void didUpdateWidget(ClozeRevealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) {
      _revealed.clear();
      _split();
      _maybeNotify();
    }
  }

  void _split() {
    final (front, next) = clozeSegments(widget.card.front, widget.card.keywords);
    final (back, end) =
        clozeSegments(widget.card.back, widget.card.keywords, startIndex: next);
    _front = front;
    _back = back;
    _blankCount = end;
    // A cloze-eligible card whose keyword never actually appears in the text
    // has nothing to gate on — treat it as already fully revealed.
    if (_blankCount == 0) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => widget.onAllRevealed());
    }
  }

  void _reveal(int index) {
    if (_revealed.contains(index)) return;
    setState(() => _revealed.add(index));
    _maybeNotify();
  }

  void _maybeNotify() {
    if (_blankCount > 0 && _revealed.length >= _blankCount) {
      widget.onAllRevealed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return StackedDeck(
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
      height: 1.5,
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
                  word: segment.text,
                  revealed: _revealed.contains(segment.blankIndex),
                  onTap: () => _reveal(segment.blankIndex!),
                  tokens: tokens,
                  baseStyle: baseStyle,
                ),
              ),
        ],
      ),
    );
  }
}

class _Blank extends StatelessWidget {
  const _Blank({
    required this.word,
    required this.revealed,
    required this.onTap,
    required this.tokens,
    required this.baseStyle,
  });

  final String word;
  final bool revealed;
  final VoidCallback onTap;
  final AppTokens tokens;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    if (revealed) {
      return Text(
        word,
        style: baseStyle.copyWith(fontWeight: FontWeight.w600),
      );
    }

    // Chip width loosely tracks the hidden word's length, within sane bounds,
    // so the blank reads as standing in for something specific.
    final width = word.length.clamp(3, 12) * 7.0 + 16;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        height: (baseStyle.fontSize ?? 16) + 8,
        width: width,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.mutedFill,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: tokens.borderHairline),
        ),
        child: Icon(
          Icons.touch_app_outlined,
          size: 12,
          color: tokens.textTertiary,
        ),
      ),
    );
  }
}
