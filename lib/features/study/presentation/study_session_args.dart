import 'package:flutter/foundation.dart';

import '../../decks/domain/study_mode.dart';
import '../domain/session_length.dart';

/// What the Deck Overview hands the study route (as go_router `extra`) to start
/// a session: which deck, which mode, and the session-length choice.
@immutable
class StudySessionArgs {
  const StudySessionArgs({
    required this.deckId,
    required this.deckName,
    required this.mode,
    required this.lengthMode,
    required this.cap,
  });

  final String deckId;
  final String? deckName;
  final StudyMode mode;
  final SessionLengthMode lengthMode;

  /// The chosen cap when [lengthMode] is capped; `null` is "All" (no numeric
  /// cap).
  final int? cap;
}
