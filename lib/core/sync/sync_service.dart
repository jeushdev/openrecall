import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/courses/data/local_course_store.dart';
import '../../features/decks/data/local_deck_store.dart';
import '../../features/decks/data/supabase_deck_repository.dart';
import '../../features/study/data/local_study_store.dart';
import '../connectivity/connectivity_service.dart';
import '../local_db/local_deletion.dart';

/// Pushes everything the local mirror has marked `is_synced = 0` (or left as a
/// tombstone) up to Supabase when connectivity returns (spec §10,
/// docs/spec-v4-offline-authoring.md §5).
///
/// The push runs in strict foreign-key order so a fully-offline authoring
/// session never references a parent Supabase hasn't seen yet:
///
///   1. courses            5. study_sessions
///   2. decks              6. session_cards
///   3. card content       7. deletions — reverse FK order (card → deck → course)
///   4. card mastery
///
/// Courses / decks / card content are upserted one row at a time under a per-row
/// `try/catch` so a single failing row doesn't stall the rest of the queue; the
/// server-owned `updated_at` is read back from each response and mirrored
/// locally. Card mastery goes through the same `updated_at` compare-and-set as a
/// live background write (never a blind update); a guard miss means a newer
/// server value exists, resolved by re-reading and retrying once. Sessions and
/// session-cards are batched upserts, not one network call per row. Deletions
/// with `created_locally = 1` never reached Supabase, so their remote DELETE is
/// skipped and only the local tombstone is cleared.
///
/// Best-effort throughout: any failure leaves the still-unsynced rows for the
/// next trigger (reconnect, app resume, or session end) to retry.
class SyncService {
  SyncService(
    this._client,
    this._deckLocal,
    this._courseLocal,
    this._studyLocal,
    this._connectivity,
  );

  final SupabaseClient _client;
  final LocalDeckStore _deckLocal;
  final LocalCourseStore _courseLocal;
  final LocalStudyStore _studyLocal;
  final ConnectivityService _connectivity;

  /// The guarded-write path for `cards`, reused verbatim from the live repo so
  /// an offline mastery edit syncs under the same `updated_at` compare-and-set.
  late final SupabaseDeckRepository _cards = SupabaseDeckRepository(_client);

  bool _running = false;

  /// Best-effort. Any failure leaves the still-unsynced rows for the next
  /// trigger (reconnect, app resume, or session end) to retry.
  Future<void> syncPending() async {
    if (_running) return;
    if (_deckLocal.isNoop && _courseLocal.isNoop && _studyLocal.isNoop) return;
    if (!await _connectivity.isOnline()) return;
    if (_client.auth.currentUser == null) return;

    _running = true;
    try {
      final userId = _client.auth.currentUser!.id;
      await _pushCourses(userId);
      await _pushDecks(userId);
      await _pushCardContent();
      await _pushCards();
      await _pushSessions();
      await _pushSessionCards();
      await _processDeletions();
    } catch (_) {
      // Swallowed on purpose — see the class doc.
    } finally {
      _running = false;
    }
  }

  Future<void> _pushCourses(String userId) async {
    for (final course in await _courseLocal.unsyncedCourses()) {
      try {
        final row = await _client.from('courses').upsert({
          'id': course.id,
          'user_id': userId,
          'name': course.name,
          'accent_color': course.accentColor,
          'is_default': course.isDefault,
        }).select().single();
        await _courseLocal.markCourseSynced(
          course.id,
          DateTime.parse(row['updated_at'] as String),
        );
      } catch (_) {
        // Best-effort — the row stays unsynced for the next trigger.
      }
    }
  }

  Future<void> _pushDecks(String userId) async {
    for (final deck in await _deckLocal.unsyncedDecks()) {
      try {
        // A null course_id is left to the decks before-insert trigger, which
        // fills the user's default course; fall back to the locally-known
        // default so an upsert-as-update still lands a valid FK.
        final courseId = deck.courseId ?? await _courseLocal.defaultCourseId();
        final row = await _client.from('decks').upsert({
          'id': deck.id,
          'user_id': userId,
          'name': deck.name,
          'course_id': ?courseId,
        }).select().single();
        await _deckLocal.markDeckSynced(
          deck.id,
          DateTime.parse(row['updated_at'] as String),
        );
      } catch (_) {
        // Best-effort — the row stays unsynced for the next trigger.
      }
    }
  }

  Future<void> _pushCardContent() async {
    for (final card in await _deckLocal.contentDirtyCards()) {
      try {
        // Plain last-write-wins upsert of the full row. The guarded
        // compare-and-set is the mastery-only path's job (_pushCards), not this.
        final row = await _client.from('cards').upsert({
          'id': card.id,
          'deck_id': card.deckId,
          'front': card.front,
          'back': card.back,
          'keywords': card.keywords,
          'is_concept': card.isConcept,
          'mastery_level': card.masteryLevel,
          'fail_count': card.failCount,
          'created_at': card.createdAt.toUtc().toIso8601String(),
        }).select().single();
        await _deckLocal.markCardContentSynced(
          card.id,
          DateTime.parse(row['updated_at'] as String),
        );
      } catch (_) {
        // Best-effort — the row stays content-dirty for the next trigger.
      }
    }
  }

  Future<void> _pushCards() async {
    for (final card in await _deckLocal.unsyncedCards()) {
      var row = await _cards.updateCardMasteryGuarded(
        cardId: card.id,
        masteryLevel: card.masteryLevel,
        failCount: card.failCount,
        expectedUpdatedAt: card.baseUpdatedAt,
      );
      if (row == null) {
        // The server row moved since we last mirrored it. Re-read and retry
        // once with the fresh timestamp — our offline edit is the later write.
        final fresh = await _cards.readCardMasteryState(card.id);
        row = await _cards.updateCardMasteryGuarded(
          cardId: card.id,
          masteryLevel: card.masteryLevel,
          failCount: card.failCount,
          expectedUpdatedAt: fresh.updatedAt,
        );
      }
      if (row != null) {
        await _deckLocal.markCardSynced(card.id, row.updatedAt);
      }
    }
  }

  Future<void> _pushSessions() async {
    final dirty = await _studyLocal.unsyncedSessions();
    if (dirty.isEmpty) return;
    await _client
        .from('study_sessions')
        .upsert([for (final s in dirty) s.values]);
    await _studyLocal.markSessionsSynced([for (final s in dirty) s.id]);
  }

  Future<void> _pushSessionCards() async {
    final dirty = await _studyLocal.unsyncedSessionCards();
    if (dirty.isEmpty) return;
    await _client
        .from('session_cards')
        .upsert([for (final sc in dirty) sc.values]);
    await _studyLocal.markSessionCardsSynced([for (final sc in dirty) sc.id]);
  }

  /// Replays tombstones in reverse foreign-key order so a parent is never
  /// deleted before its children. A `created_locally` tombstone marks a row that
  /// never reached Supabase, so its remote DELETE is skipped.
  Future<void> _processDeletions() async {
    await _replay(
      await _deckLocal.cardDeletions(),
      'cards',
      _deckLocal.clearCardDeletion,
    );
    await _replay(
      await _deckLocal.deckDeletions(),
      'decks',
      _deckLocal.clearDeckDeletion,
    );
    await _replay(
      await _courseLocal.courseDeletions(),
      'courses',
      _courseLocal.clearCourseDeletion,
    );
  }

  Future<void> _replay(
    List<LocalDeletion> tombstones,
    String table,
    Future<void> Function(String id) clear,
  ) async {
    for (final tombstone in tombstones) {
      try {
        if (!tombstone.createdLocally) {
          await _client.from(table).delete().eq('id', tombstone.entityId);
        }
        await clear(tombstone.entityId);
      } catch (_) {
        // Best-effort — the tombstone stays for the next trigger.
      }
    }
  }
}
