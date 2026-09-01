import '../../decks/domain/study_mode.dart';
import 'queue_seed.dart';
import 'session_card.dart';
import 'session_length.dart';
import 'study_session.dart';

/// The app's window onto the `study_sessions` and `session_cards` tables.
///
/// Session-scoped writes (`position`, `consecutive_fails`, `is_parked`) have no
/// `updated_at` and a single writer, so they need no compare-and-set — the
/// controller fires them in the background and only logs failures. The guarded
/// `cards` writes live on `DeckRepository`, next to the rest of the `cards`
/// access.
abstract interface class StudyRepository {
  /// Marks every still-`active` session on [deckId] as `abandoned` — the
  /// session-conflict rule, run before a new session starts. Idempotent.
  Future<void> abandonActiveSessions(String deckId);

  /// Inserts a new `study_sessions` row and returns it. [cardScope] records
  /// whether the queue was built from due cards only or the whole deck
  /// (engine-v2-spec §3.3); it defaults to [CardScope.due], the V1 behaviour.
  Future<StudySession> createSession({
    required String deckId,
    required StudyMode studyMode,
    required SessionLengthMode lengthMode,
    int? cappedLength,
    CardScope cardScope = CardScope.due,
  });

  /// Inserts the queue as `session_cards` rows (sparse positions) and returns
  /// them.
  Future<List<SessionCard>> createSessionCards(
    String sessionId,
    List<QueueSeed> seeds,
  );

  /// Updates one `session_cards` row — only the fields passed are written.
  Future<void> updateSessionCard({
    required String sessionCardId,
    int? position,
    int? consecutiveFails,
    bool? isParked,
  });

  /// Marks a session `completed` with `completed_at = now()`. [cardsReviewed] is
  /// the distinct cards the session covered, stored for the profile metrics
  /// (milestone D).
  Future<void> completeSession(
    String sessionId, {
    int? masteryDelta,
    int? cardsReviewed,
  });
}
