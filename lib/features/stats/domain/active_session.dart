import 'package:flutter/foundation.dart';

import '../../decks/domain/study_mode.dart';
import '../../study/domain/session_length.dart';
import '../../study/domain/study_session.dart';

/// One still-`active` study session with the mastered/total figures the Home
/// tab's "Unfinished Sessions" row shows as a percentage (ui-spec-v4 §3).
///
/// [masteredCards] / [totalCards] mirror `SessionController`'s mid-session
/// `resolvedCount / totalCards` math, but recomputed read-only from the
/// persisted `session_cards` joined to each card's live `mastery_level` — the
/// in-memory session state is gone once the app is backgrounded, and a
/// `session_cards` row is never rewritten when its card is mastered, so the
/// count is derived from `cards.mastery_level >= masteredLevel` (or a parked
/// row) instead. This never touches the study path.
@immutable
class ActiveSessionProgress {
  const ActiveSessionProgress({
    required this.sessionId,
    required this.deckId,
    required this.studyMode,
    required this.lengthMode,
    required this.cardScope,
    required this.cappedLength,
    required this.startedAt,
    required this.masteredCards,
    required this.totalCards,
  });

  final String sessionId;
  final String deckId;
  final StudyMode studyMode;
  final SessionLengthMode lengthMode;
  final CardScope cardScope;
  final int? cappedLength;
  final DateTime startedAt;

  /// Cards in the session's queue that are now at or above [masteredLevel], or
  /// were parked — the ones that would not come back if the session resumed.
  final int masteredCards;

  /// Distinct cards the session's queue was seeded with.
  final int totalCards;

  /// 0–100, rounded. A session with no queue rows reads as 0%.
  int get percentComplete =>
      totalCards == 0 ? 0 : (masteredCards / totalCards * 100).round();
}
