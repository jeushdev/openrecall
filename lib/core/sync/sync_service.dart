import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/courses/data/local_course_store.dart';
import '../../features/decks/data/local_deck_store.dart';
import '../../features/decks/data/supabase_deck_repository.dart';
import '../../features/decks/domain/offline_download.dart';
import '../../features/study/data/local_study_store.dart';
import '../connectivity/connectivity_service.dart';
import '../local_db/local_deletion.dart';

/// What the last reconnect-sync pass did (milestone E3). Drives the retry
/// affordance on `SyncStatusChip`.
enum SyncOutcomeKind { idle, running, ok, failed }

/// A single reconnect-sync result. [error] and [at] are set only for
/// [SyncOutcomeKind.failed] / [SyncOutcomeKind.ok].
@immutable
class SyncOutcome {
  const SyncOutcome._(this.kind, {this.error, this.at});

  const SyncOutcome.idle() : this._(SyncOutcomeKind.idle);
  const SyncOutcome.running() : this._(SyncOutcomeKind.running);
  const SyncOutcome.ok(this.at) : kind = SyncOutcomeKind.ok, error = null;
  const SyncOutcome.failed(this.error, this.at) : kind = SyncOutcomeKind.failed;

  final SyncOutcomeKind kind;
  final Object? error;
  final DateTime? at;

  bool get isFailure => kind == SyncOutcomeKind.failed;
}

/// The `items` payload for the `set_deck_positions` RPC — one `{id, position}`
/// per dirty deck. `position` is client-authoritative after an offline drag
/// (milestone E3).
List<Map<String, Object?>> deckPositionItems(List<DirtyDeck> dirty) => [
  for (final d in dirty) {'id': d.id, 'position': d.position},
];

/// The `items` payload for the `set_course_positions` RPC. See
/// [deckPositionItems].
List<Map<String, Object?>> coursePositionItems(List<DirtyCourse> dirty) => [
  for (final c in dirty) {'id': c.id, 'position': c.position},
];

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
    this._connectivity, {
    this.isCurrent,
    this.commitBus,
  });

  final SupabaseClient _client;
  final LocalDeckStore _deckLocal;
  final LocalCourseStore _courseLocal;
  final LocalStudyStore _studyLocal;
  final ConnectivityService _connectivity;
  final OfflineDeckCommitBus? commitBus;

  /// The guarded-write path for `cards`, reused verbatim from the live repo so
  /// an offline mastery edit syncs under the same `updated_at` compare-and-set.
  late final SupabaseDeckRepository _cards = SupabaseDeckRepository(_client);

  bool _running = false;
  bool _disposed = false;
  String? _runningOwner;
  Set<String>? _quarantinedDeckIds;
  final bool Function()? isCurrent;

  void _checkScope() {
    if (_disposed ||
        isCurrent?.call() == false ||
        (_runningOwner != null && currentUserId() != _runningOwner)) {
      throw StateError('Account changed during sync');
    }
  }

  final _outcomes = StreamController<SyncOutcome>.broadcast();

  /// The reconnect-sync outcome stream — the retry affordance on
  /// `SyncStatusChip` listens to it (milestone E3).
  Stream<SyncOutcome> get outcomes => _outcomes.stream;

  SyncOutcome _lastOutcome = const SyncOutcome.idle();

  /// The most recent [SyncOutcome], for a listener that subscribes late.
  SyncOutcome get lastOutcome => _lastOutcome;

  int _consecutiveFailures = 0;
  DateTime? _nextAllowedAt;
  static const _maxBackoff = Duration(minutes: 5);

  /// When the next non-forced [syncPending] is allowed to run, or `null` when
  /// there is no active backoff. Exposed for tests / diagnostics.
  @visibleForTesting
  DateTime? get nextAllowedAt => _nextAllowedAt;

  void _emit(SyncOutcome outcome) {
    _lastOutcome = outcome;
    if (!_outcomes.isClosed) _outcomes.add(outcome);
  }

  /// The signed-in user id, or `null` when there is no session. A seam so a
  /// `SyncService` test can drive a full pass without a live Supabase auth
  /// session.
  @visibleForTesting
  String? currentUserId() => _client.auth.currentUser?.id;

  /// Frees the outcome stream. Call when the owning provider is disposed.
  void dispose() {
    _disposed = true;
    _outcomes.close();
  }

  /// Pushes every queued local write to Supabase in foreign-key order.
  ///
  /// Best-effort per row: a failing row stays unsynced for the next trigger.
  /// After the pass, if the pending queue did not shrink even though rows remain,
  /// that is reported as [SyncOutcomeKind.failed] and an exponential backoff
  /// (capped at five minutes) throttles the next non-forced call — [force]
  /// bypasses it, which is what the tappable chip does.
  Future<void> syncPending({bool force = false}) async {
    if (_running || _disposed || isCurrent?.call() == false) return;
    if (_deckLocal.isNoop && _courseLocal.isNoop && _studyLocal.isNoop) return;
    if (!force &&
        _nextAllowedAt != null &&
        DateTime.now().isBefore(_nextAllowedAt!)) {
      return;
    }
    if (!await _connectivity.isOnline()) return;
    final userId = currentUserId();
    if (userId == null) return;

    _running = true;
    _runningOwner = userId;
    _emit(const SyncOutcome.running());
    try {
      _quarantinedDeckIds = await _deckLocal.confirmedMissingDeckIds();
      final before = await _eligiblePendingCount(_quarantinedDeckIds!);
      await pushCourses(userId);
      await pushDecks(userId);
      await pushCardContent();
      await pushCards();
      await pushSessions();
      await pushSessionCards();
      await processDeletions();
      final after = await _eligiblePendingCount(_quarantinedDeckIds!);
      if (after > 0 && after >= before) {
        // Nothing drained though work remains — a stalled push, not success.
        _registerFailure(
          StateError('sync ran but $after change(s) did not reach Supabase'),
        );
      } else {
        _consecutiveFailures = 0;
        _nextAllowedAt = null;
        _emit(SyncOutcome.ok(DateTime.now()));
      }
    } catch (e) {
      _registerFailure(e);
    } finally {
      _running = false;
      _runningOwner = null;
      _quarantinedDeckIds = null;
    }
  }

  void _registerFailure(Object error) {
    _consecutiveFailures++;
    final seconds = (1 << (_consecutiveFailures - 1)).clamp(
      1,
      _maxBackoff.inSeconds,
    );
    _nextAllowedAt = DateTime.now().add(Duration(seconds: seconds));
    _emit(SyncOutcome.failed(error, DateTime.now()));
  }

  Future<int> _eligiblePendingCount(Set<String> quarantined) async {
    final counts = await Future.wait<int>([
      _courseLocal.unsyncedCourses().then((r) => r.length),
      _deckLocal.unsyncedDecks().then(
        (r) => r.where((row) => !quarantined.contains(row.id)).length,
      ),
      _deckLocal.contentDirtyCards().then(
        (r) => r.where((row) => !quarantined.contains(row.deckId)).length,
      ),
      _deckLocal.unsyncedCards().then(
        (r) => r.where((row) => !quarantined.contains(row.deckId)).length,
      ),
      _studyLocal.unsyncedSessions().then(
        (r) => r.where((row) => !quarantined.contains(row.deckId)).length,
      ),
      _studyLocal.unsyncedSessionCards().then(
        (r) => r.where((row) => !quarantined.contains(row.deckId)).length,
      ),
      _courseLocal.courseDeletions().then((r) => r.length),
      _deckLocal.deckDeletions().then((r) => r.length),
      _deckLocal.cardDeletions().then((r) => r.length),
    ]);
    return counts.fold<int>(0, (sum, n) => sum + n);
  }

  Future<Set<String>> _missingDeckIdsForPass() async =>
      _quarantinedDeckIds ?? await _deckLocal.confirmedMissingDeckIds();

  Future<void> _cleanupAcknowledged(Set<String> deckIds) async {
    if (deckIds.isEmpty) return;
    final changed = await _deckLocal.cleanupRetainedCards(deckIds: deckIds);
    for (final deckId in changed) {
      commitBus?.publish(deckId, OfflineDeckCommitKind.cleanup);
    }
  }

  @visibleForTesting
  Future<void> pushCourses(String userId) async {
    final dirty = await _courseLocal.unsyncedCourses();
    for (final course in dirty) {
      try {
        _checkScope();
        final row = await _client
            .from('courses')
            .upsert({
              'id': course.id,
              'user_id': userId,
              'name': course.name,
              'accent_color': course.accentColor,
              'is_default': course.isDefault,
            })
            .select()
            .single();
        _checkScope();
        await _courseLocal.markCourseSynced(
          course.id,
          DateTime.parse(row['updated_at'] as String),
          sentRevision: course,
        );
      } catch (_) {
        // Best-effort — the row stays unsynced for the next trigger.
      }
    }
    await pushCoursePositions(dirty);
  }

  @visibleForTesting
  Future<void> pushDecks(String userId) async {
    final missing = await _missingDeckIdsForPass();
    final dirty = (await _deckLocal.unsyncedDecks())
        .where((deck) => !missing.contains(deck.id))
        .toList();
    for (final deck in dirty) {
      try {
        // A null course_id is left to the decks before-insert trigger, which
        // fills the user's default course; fall back to the locally-known
        // default so an upsert-as-update still lands a valid FK.
        final courseId = deck.courseId ?? await _courseLocal.defaultCourseId();
        _checkScope();
        final row = await _client
            .from('decks')
            .upsert({
              'id': deck.id,
              'user_id': userId,
              'name': deck.name,
              'course_id': ?courseId,
              'last_studied_at': ?deck.lastStudiedAt?.toUtc().toIso8601String(),
            })
            .select()
            .single();
        _checkScope();
        await _deckLocal.markDeckSynced(
          deck.id,
          DateTime.parse(row['updated_at'] as String),
          sentRevision: deck,
        );
      } catch (_) {
        // Best-effort — the row stays unsynced for the next trigger.
      }
    }
    await pushDeckPositions(dirty);
  }

  /// Pushes the queued manual order for every dirty deck via `set_deck_positions`
  /// — the only sanctioned client write to `decks.position` (supabase/schema.sql)
  /// — after the deck rows themselves are upserted, so the target rows exist.
  /// Harmless when a row was dirtied by a rename rather than a reorder: it writes
  /// the same position back. Best-effort; positions retry on the next trigger.
  @visibleForTesting
  Future<void> pushDeckPositions(List<DirtyDeck> dirty) async {
    if (dirty.isEmpty) return;
    try {
      _checkScope();
      await _client.rpc(
        'set_deck_positions',
        params: {'items': deckPositionItems(dirty)},
      );
    } catch (_) {
      // Best-effort — retried on the next trigger.
    }
  }

  /// The course counterpart of [pushDeckPositions], via `set_course_positions`.
  @visibleForTesting
  Future<void> pushCoursePositions(List<DirtyCourse> dirty) async {
    if (dirty.isEmpty) return;
    try {
      _checkScope();
      await _client.rpc(
        'set_course_positions',
        params: {'items': coursePositionItems(dirty)},
      );
    } catch (_) {
      // Best-effort — retried on the next trigger.
    }
  }

  @visibleForTesting
  Future<void> pushCardContent() async {
    final missing = await _missingDeckIdsForPass();
    final acknowledgedDecks = <String>{};
    for (final card in (await _deckLocal.contentDirtyCards()).where(
      (card) => !missing.contains(card.deckId),
    )) {
      try {
        // Plain last-write-wins upsert of the full row. The guarded
        // compare-and-set is the mastery-only path's job (pushCards), not this.
        _checkScope();
        final row = await _client
            .from('cards')
            .upsert({
              'id': card.id,
              'deck_id': card.deckId,
              'front': card.front,
              'back': card.back,
              'keywords': card.keywords,
              'is_concept': card.isConcept,
              'mastery_level': card.masteryLevel,
              'fail_count': card.failCount,
              'created_at': card.createdAt.toUtc().toIso8601String(),
            })
            .select()
            .single();
        _checkScope();
        await _deckLocal.markCardContentSynced(
          card.id,
          DateTime.parse(row['updated_at'] as String),
          sentRevision: card,
        );
        acknowledgedDecks.add(card.deckId);
      } catch (_) {
        // Best-effort — the row stays content-dirty for the next trigger.
      }
    }
    await _cleanupAcknowledged(acknowledgedDecks);
  }

  @visibleForTesting
  Future<void> pushCards() async {
    final missing = await _missingDeckIdsForPass();
    final acknowledgedDecks = <String>{};
    for (final card in (await _deckLocal.unsyncedCards()).where(
      (card) => !missing.contains(card.deckId),
    )) {
      _checkScope();
      var row = await _cards.updateCardMasteryGuarded(
        cardId: card.id,
        masteryLevel: card.masteryLevel,
        failCount: card.failCount,
        expectedUpdatedAt: card.baseUpdatedAt,
      );
      if (row == null) {
        // The server row moved since we last mirrored it. Re-read and retry
        // once with the fresh timestamp — our offline edit is the later write.
        _checkScope();
        final fresh = await _cards.readCardMasteryState(card.id);
        _checkScope();
        row = await _cards.updateCardMasteryGuarded(
          cardId: card.id,
          masteryLevel: card.masteryLevel,
          failCount: card.failCount,
          expectedUpdatedAt: fresh.updatedAt,
        );
      }
      if (row != null) {
        _checkScope();
        await _deckLocal.markCardSynced(
          card.id,
          row.updatedAt,
          sentRevision: card,
        );
        acknowledgedDecks.add(card.deckId);
      }
    }
    await _cleanupAcknowledged(acknowledgedDecks);
  }

  @visibleForTesting
  Future<void> pushSessions() async {
    final missing = await _missingDeckIdsForPass();
    final dirty = (await _studyLocal.unsyncedSessions())
        .where((session) => !missing.contains(session.deckId))
        .toList();
    if (dirty.isEmpty) return;
    // Preserve the one-active-session-per-deck conflict rule without putting a
    // remote wait back into local session start. Abandon existing remote rows
    // first, then the upsert below applies the client-authored state (active or
    // already completed). Replays are harmless.
    final affectedDecks = {
      for (final session in dirty) session.values['deck_id'] as String,
    };
    for (final deckId in affectedDecks) {
      _checkScope();
      await _client
          .from('study_sessions')
          .update({'status': 'abandoned'})
          .eq('deck_id', deckId)
          .eq('status', 'active');
    }
    _checkScope();
    await _client.from('study_sessions').upsert([
      for (final s in dirty) s.values,
    ]);
    _checkScope();
    await _studyLocal.markSessionsSynced(dirty);
    await _cleanupAcknowledged({for (final session in dirty) session.deckId});
  }

  @visibleForTesting
  Future<void> pushSessionCards() async {
    final missing = await _missingDeckIdsForPass();
    final dirty = (await _studyLocal.unsyncedSessionCards())
        .where((row) => !missing.contains(row.deckId))
        .toList();
    if (dirty.isEmpty) return;
    _checkScope();
    await _client.from('session_cards').upsert([
      for (final sc in dirty) sc.values,
    ]);
    _checkScope();
    await _studyLocal.markSessionCardsSynced(dirty);
    await _cleanupAcknowledged({for (final row in dirty) row.deckId});
  }

  /// Replays tombstones in reverse foreign-key order so a parent is never
  /// deleted before its children. A `created_locally` tombstone marks a row that
  /// never reached Supabase, so its remote DELETE is skipped.
  @visibleForTesting
  Future<void> processDeletions() async {
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
          _checkScope();
          await _client.from(table).delete().eq('id', tombstone.entityId);
        }
        _checkScope();
        await clear(tombstone.entityId);
      } catch (_) {
        // Best-effort — the tombstone stays for the next trigger.
      }
    }
  }
}
