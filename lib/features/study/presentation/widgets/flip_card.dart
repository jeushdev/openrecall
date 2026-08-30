import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_tokens.dart';
import '../../../decks/domain/card.dart';
import '../../../settings/application/settings_providers.dart';
import '../../../settings/data/study_appearance_preferences.dart';
import 'stacked_deck.dart';

/// The Flip-mode card surface (ui-spec-v1 §6.2).
///
/// Shows the card front; a tap anywhere flips it to the back. Resets to the
/// front whenever [card] changes (the screen also re-keys this widget per
/// queue position, so a requeued card always starts face-down).
///
/// The transition honours the §6.5 "Card transition" Settings toggle
/// ([studyAppearanceProvider]): [CardTransition.flip3d] runs a real Y-axis
/// rotation and swaps the front/back face at the half-turn;
/// [CardTransition.fade] keeps the short fade + slide. The loading frame and
/// any storage failure fall back to [CardTransition.flip3d], the spec default.
class FlipCard extends ConsumerStatefulWidget {
  const FlipCard({
    super.key,
    required this.card,
    required this.onFlippedChanged,
  });

  final FlashCard card;

  /// Fired whenever the revealed side changes — the screen gates the rating row
  /// and swipe gestures on "has been flipped at least once".
  final ValueChanged<bool> onFlippedChanged;

  @override
  ConsumerState<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends ConsumerState<FlipCard>
    with SingleTickerProviderStateMixin {
  bool _flipped = false;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id && _flipped) {
      _flipped = false;
      _controller.value = 0;
      widget.onFlippedChanged(false);
    }
  }

  void _toggle() {
    setState(() => _flipped = !_flipped);
    // Fire synchronously — the screen enables the rating row off this, and that
    // must never wait on the animation.
    widget.onFlippedChanged(_flipped);
    if (_flipped) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(studyAppearanceProvider).asData?.value;
    final transition = appearance?.cardTransition ?? CardTransition.flip3d;

    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: StackedDeck(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 260),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: switch (transition) {
                CardTransition.flip3d => _Flip3d(
                    controller: _controller,
                    front: _face(context, back: false),
                    back: _face(context, back: true),
                  ),
                CardTransition.fade => _FadeSlide(
                    flipped: _flipped,
                    child: _face(context, back: _flipped),
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _face(BuildContext context, {required bool back}) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          back ? 'ANSWER' : 'PROMPT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: tokens.textTertiary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          back ? widget.card.back : widget.card.front,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            height: 1.4,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          back ? 'Rate your recall below' : 'Tap to reveal',
          style: TextStyle(
            fontSize: 12,
            color: tokens.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// A true Y-axis rotation. The front face shows for the first quarter-turn; past
/// `pi / 2` the back face takes over (counter-rotated so its text isn't
/// mirrored). Only the visible face is built, so a card change or a
/// `pumpAndSettle` lands cleanly on one side.
class _Flip3d extends StatelessWidget {
  const _Flip3d({
    required this.controller,
    required this.front,
    required this.back,
  });

  final AnimationController controller;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final angle = controller.value * math.pi;
        final showBack = angle > math.pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: showBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: back,
                )
              : front,
        );
      },
    );
  }
}

/// The pre-UX3 transition: a 180ms fade + 4%-slide cross-fade between faces,
/// keyed on the revealed side.
class _FadeSlide extends StatelessWidget {
  const _FadeSlide({required this.flipped, required this.child});

  final bool flipped;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(flipped), child: child),
    );
  }
}
