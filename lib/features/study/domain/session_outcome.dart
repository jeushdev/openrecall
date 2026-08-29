import 'package:flutter/foundation.dart';

/// The finished-session figures the Session Summary shows (spec §7): the
/// deck-level mastery % delta for the run plus the lightweight recall metrics.
///
/// Built once by [SessionController] when the session reaches
/// [SessionPhase.completed] and attached to [StudySessionState.outcome]. Pure
/// data — no per-card raw outcomes are kept.
@immutable
class SessionOutcome {
  const SessionOutcome({
    required this.masteryPercentBefore,
    required this.masteryPercentAfter,
    required this.cardsStudied,
    required this.mastered,
    required this.parked,
    required this.firstTryMastered,
    required this.requeues,
  });

  /// Whole-deck mastery % (spec §6 scale) at session start.
  final int masteryPercentBefore;

  /// Whole-deck mastery % once the session's per-card results are applied.
  final int masteryPercentAfter;

  /// Distinct cards the session covered (frozen at seed time).
  final int cardsStudied;

  /// Cards taken to Mastered this session.
  final int mastered;

  /// Cards left parked when the session ended.
  final int parked;

  /// Cards mastered without ever being missed — the "recalled on the first
  /// try" metric, framed per mode in the UI.
  final int firstTryMastered;

  /// Total misses this session: every result short of Mastered, i.e. every
  /// requeue.
  final int requeues;

  /// The "+X%" headline (can be zero or negative).
  int get masteryDelta => masteryPercentAfter - masteryPercentBefore;
}
