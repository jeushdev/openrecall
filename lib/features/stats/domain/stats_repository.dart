import 'troublemaker_card.dart';

/// How many cards the app-wide Troublemakers list holds (engine-v2-spec §6).
/// The Deck Overview's per-deck list caps at 5; this one spans every deck, so it
/// carries more.
const int appWideTroublemakerLimit = 20;

/// The app's window onto the read-only, cross-deck aggregations that feed the
/// future Mastery / Stats screen (engine-v2-spec §6).
///
/// Only the two aggregations that need their own query live here. Overall
/// mastery % and per-course rollups are pure functions over the deck / course
/// lists the app already holds — see `overall_mastery.dart` /
/// `course_summary.dart` — and never reach a repository.
///
/// Both methods are read-only and never block a study interaction. Offline they
/// fall back to the local SQLite mirror and may return partial results (only
/// downloaded decks / locally recorded sessions).
abstract interface class StatsRepository {
  /// The user's cards with the highest lifetime `fail_count`, most-failed first,
  /// capped at [limit].
  Future<List<TroublemakerCard>> fetchTroublemakers({
    int limit = appWideTroublemakerLimit,
  });

  /// "Times fully cleared" per deck (engine-v2-spec §4.3): for each deck, the
  /// count of `completed` sessions whose `card_scope` was `all`. Decks that have
  /// never been cleared this way are absent from the map.
  Future<Map<String, int>> fetchDeckRunThroughs();

  /// The `started_at` timestamp of every `completed` study session, most-recent
  /// first — the raw input the Profile tab's streak is derived from
  /// (ui-spec-v1 §6.4). Offline this returns only sessions recorded on this
  /// device.
  Future<List<DateTime>> fetchCompletedSessionStarts();
}
