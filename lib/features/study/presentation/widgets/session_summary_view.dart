import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../ui/common/app_card.dart';

import '../../../../core/format/mastery_delta_label.dart';
import '../../../../theme/app_geometry.dart';
import '../../../../theme/app_haptics.dart';
import '../../../../theme/app_motion.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../theme/app_type.dart';
import '../../../decks/domain/study_mode.dart';
import '../../domain/session_outcome.dart';

/// The Session Summary (spec §7 / ui-spec-v3 §5.4), shown when a session reaches
/// [SessionPhase.completed].
///
/// Rebuilt for v3 as a designed moment rather than the earlier stock-Material
/// screen: a token background (no `AppBar`, no `primaryContainer`), a centred
/// **mastery arc** whose fill sweeps and whose percentage counts up from the
/// deck's before-value to its after-value on first build, and a "This session"
/// block whose metric values count up from zero. One two-beat haptic on entry.
///
/// This is celebration of craft, not a reward economy — there are no points,
/// badges, levels or streak mechanics here, by standing product decision
/// (`docs/spec.md`).
class SessionSummaryView extends StatefulWidget {
  const SessionSummaryView({
    super.key,
    required this.mode,
    required this.deckName,
    required this.outcome,
    required this.hasParked,
    required this.onDrillParked,
    required this.onStudyAgain,
    required this.onDone,
  });

  final StudyMode mode;
  final String? deckName;
  final SessionOutcome outcome;

  /// Whether the finished session left any card parked — gates the drill button.
  final bool hasParked;

  final VoidCallback onDrillParked;
  final VoidCallback onStudyAgain;
  final VoidCallback onDone;

  @override
  State<SessionSummaryView> createState() => _SessionSummaryViewState();
}

class _SessionSummaryViewState extends State<SessionSummaryView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppHaptics.sessionComplete();
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The mode-specific phrasing for the "recalled on the first try" metric.
  String get _firstTryLabel => switch (widget.mode) {
    StudyMode.flip => 'Recalled on the first flip',
    StudyMode.cloze => 'Typed right on the first try',
    StudyMode.feynman => 'Recalled on the first pass',
  };

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final outcome = widget.outcome;
    final before = outcome.masteryPercentBefore;
    final after = outcome.masteryPercentAfter;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onDone();
      },
      child: Scaffold(
        backgroundColor: tokens.background,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = Curves.easeOut.transform(_controller.value);
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                children: [
                  if (widget.deckName != null) ...[
                    Text(
                      widget.deckName!.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: AppType.overline.copyWith(
                        color: tokens.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Center(
                    child: _MasteryArc(
                      fraction: (before + (after - before) * t) / 100,
                      percent: (before + (after - before) * t).round(),
                      trackColor: tokens.borderHairline,
                      fillColor: tokens.tint,
                      labelColor: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    masteryDeltaLabel(outcome.masteryDelta),
                    textAlign: TextAlign.center,
                    style: AppType.title.copyWith(color: tokens.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$before% → $after%',
                    textAlign: TextAlign.center,
                    style: AppType.caption.copyWith(color: tokens.textTertiary),
                  ),
                  const SizedBox(height: 24),
                  _SessionBlock(
                    tokens: tokens,
                    rows: [
                      _Metric('Cards studied', outcome.cardsStudied),
                      _Metric('Mastered', outcome.mastered),
                      _Metric('Parked', outcome.parked),
                      _Metric(_firstTryLabel, outcome.firstTryMastered),
                      _Metric(
                        outcome.requeues == 1 ? 'Miss' : 'Misses',
                        outcome.requeues,
                      ),
                    ],
                    t: t,
                  ),
                  const SizedBox(height: 24),
                  if (widget.hasParked) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: widget.onDrillParked,
                        icon: const Icon(Icons.bolt, size: 20),
                        label: const Text('Drill parked cards now'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: widget.onStudyAgain,
                      child: const Text('Study again'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: widget.onDone,
                      child: const Text('Done'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A 270° arc gauge. Hairline track, accent fill, rounded cap, with the
/// percentage in the centre. No shadow (app-wide ban) — the depth is the stroke
/// contrast alone.
class _MasteryArc extends StatelessWidget {
  const _MasteryArc({
    required this.fraction,
    required this.percent,
    required this.trackColor,
    required this.fillColor,
    required this.labelColor,
  });

  final double fraction;
  final int percent;
  final Color trackColor;
  final Color fillColor;
  final Color labelColor;

  static const double _size = 148;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: CustomPaint(
        painter: _ArcPainter(
          fraction: fraction.clamp(0.0, 1.0),
          trackColor: trackColor,
          fillColor: fillColor,
        ),
        child: Center(
          child: Text(
            '$percent%',
            style: AppType.display.copyWith(color: labelColor),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.fraction,
    required this.trackColor,
    required this.fillColor,
  });

  final double fraction;
  final Color trackColor;
  final Color fillColor;

  // 270° sweep, opening centred at the bottom.
  static const double _start = math.pi * 0.75;
  static const double _sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(arcRect, _start, _sweep, false, track);

    if (fraction > 0) {
      final fill = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = fillColor;
      canvas.drawArc(arcRect, _start, _sweep * fraction, false, fill);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.fraction != fraction ||
      old.trackColor != trackColor ||
      old.fillColor != fillColor;
}

class _Metric {
  const _Metric(this.label, this.value);
  final String label;
  final int value;
}

class _SessionBlock extends StatelessWidget {
  const _SessionBlock({
    required this.tokens,
    required this.rows,
    required this.t,
  });

  final AppTokens tokens;
  final List<_Metric> rows;
  final double t;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: AppRadii.gridTile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This session',
            style: AppType.overline.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: 14),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: _MetricRow(
                label: row.label,
                value: '${(row.value * t).round()}',
                tokens: tokens,
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.tokens,
  });

  final String label;
  final String value;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppType.bodyLarge.copyWith(color: tokens.textPrimary);
    final valueStyle = AppType.numericLarge.copyWith(color: tokens.textPrimary);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final valuePainter = TextPainter(
          text: TextSpan(text: value, style: valueStyle),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        const minimumReadableLabelWidth = 80.0;
        final stacks =
            valuePainter.width + 16 + minimumReadableLabelWidth >
            constraints.maxWidth;

        if (stacks) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: labelStyle),
              const SizedBox(height: 2),
              Text(value, textAlign: TextAlign.end, style: valueStyle),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: Text(label, style: labelStyle)),
            const SizedBox(width: 16),
            Text(value, style: valueStyle),
          ],
        );
      },
    );
  }
}
