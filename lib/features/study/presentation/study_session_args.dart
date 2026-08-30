import 'package:flutter/foundation.dart';

import '../../decks/domain/study_mode.dart';
import '../domain/session_length.dart';
import '../domain/study_session.dart';

/// What the Deck Overview hands the study route (as go_router `extra`) to start
/// a session: which deck, which mode, and the session-length choice.
@immutable
class StudySessionArgs {
  const StudySessionArgs({
    required this.deckId,
    required this.mode,
    this.deckName,
    this.lengthMode = SessionLengthMode.untilMastered,
    this.cap,
    this.cardScope = CardScope.due,
  });

  final String deckId;
  final String? deckName;
  final StudyMode mode;
  final SessionLengthMode lengthMode;

  /// Whether the queue includes already-Mastered cards (engine-v2-spec §3.3).
  /// No current screen sets this to [CardScope.all]; the toggle is part of the
  /// later UI revamp.
  final CardScope cardScope;

  /// The chosen cap when [lengthMode] is capped; `null` is "All" (no numeric
  /// cap).
  final int? cap;
}
