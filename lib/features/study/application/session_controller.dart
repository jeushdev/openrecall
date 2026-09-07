import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local_db/local_db_providers.dart';
import '../../../core/sync/sync_providers.dart';
import '../../decks/application/deck_providers.dart';
import '../../decks/domain/card.dart';
import '../../decks/domain/deck_repository.dart';
import '../../decks/domain/study_mode.dart';
import '../../notifications/application/notification_providers.dart';
import '../../notifications/data/notification_service.dart';
import '../../home/application/home_providers.dart';
import '../../stats/application/stats_providers.dart';
import '../data/cache_first_study_repository.dart';
import '../data/supabase_study_repository.dart';
import '../domain/cloze_outcome.dart';
import '../domain/flip_rating.dart';
import '../domain/session_length.dart';
import '../domain/session_outcome.dart';
import '../domain/session_queue_selection.dart';
import '../domain/study_queue_item.dart';
import '../domain/study_repository.dart';
import '../domain/study_session.dart';
import '../domain/study_session_state.dart';
import 'pre_session_cards_provider.dart';

/// Thrown by [SessionController.start] when nothing in the deck qualifies for
/// the picked mode — the study screen shows a "nothing to study" message
/// instead of an error.
class EmptyQueueException implements Exception {
  const EmptyQueueException();
  @override
  String toString() => 'EmptyQueueException';
}

/// The live study repository: the Supabase-backed one wrapped in the cache-first
/// layer (spec §10), so a downloaded deck's session runs from the local SQLite
/// mirror when offline and its results sync on reconnect. Tests override it with
/// a fake.
final studyRepositoryProvider = Provider<StudyRepository>((ref) {
  return CacheFirstStudyRepository(
    SupabaseStudyRepository(Supabase.instance.client),
    ref.watch(localStudyStoreProvider),
    ref.watch(localDeckStoreProvider),
    () => Supabase.instance.client.auth.currentUser?.id,
  );
});

/// The one live study session, app-wide (the session-conflict rule assumes a
/// single session at a time).
///
/// - `AsyncData(null)` — no session.
/// - `AsyncLoading` — building one.
/// - `AsyncData(state)` — a session; `state.phase` says studying / parkPrompt /
///   completed.
/// - `AsyncError` — creation failed (an [EmptyQueueException] means "nothing to
///   study").
///
/// Deliberately not `autoDispose`: leaving the study screen must not kill
/// in-flight background writes or drop the resumable state.
final sessionControllerProvider =
    NotifierProvider<SessionController, AsyncValue<StudySessionState?>>(
      SessionController.new,
    );

/// The last DB-confirmed mastery/fail baseline for one card, plus the intent
/// not yet written. Drives the guarded background write.
class _CardSync {
  _CardSync({
    required this.baseMastery,
    required this.baseFailCount,
    required this.baseUpdatedAt,
  }) : desiredMastery = baseMastery;

  int baseMastery;
  int baseFailCount;
  DateTime baseUpdatedAt;

  /// Session fails not yet folded into the DB `fail_count`.
  int unpersistedFailIncrements = 0;

  /// The latest rating's absolute `mastery_level` intent.
  int desiredMastery;
}

class SessionController extends Notifier<AsyncValue<StudySessionState?>> {
  @override
  AsyncValue<StudySessionState?> build() => const AsyncData(null);

  DeckRepository get _decks => ref.read(deckRepositoryProvider);
  StudyRepository get _study => ref.read(studyRepositoryProvider);
  NotificationService get _notifications =>
      ref.read(notificationServiceProvider);

  /// Kick a best-effort sync of anything the local mirror queued while offline
  /// (spec §10). Never awaited, never throws into a study interaction.
  void _triggerSync() {
    final sync = ref.read(syncServiceProvider);
    if (sync != null) {
      unawaited(
        sync.syncPending().then((_) {
          _refreshPendingSync();
          _refreshSessionReads();
        }),
      );
    }
  }

  void _refreshPendingSync() {
    ref.invalidate(pendingSyncProvider);
    ref.invalidate(pendingSyncCountProvider);
  }

  void _refreshSessionReads() {
    ref.invalidate(recentCompletedSessionsProvider);
    ref.invalidate(completedSessionsProvider);
    ref.invalidate(activeSessionProgressProvider);
    ref.invalidate(sessionCountsByDeckProvider);
  }

  /// Fire-and-forget a notification call. Study interactions must never block on
  /// or fail because of a reminder write (see CLAUDE.md "Performance").
  void _notify(Future<void> Function() action) {
    unawaited(
      Future(() async {
        try {
          await action();
        } catch (_) {
          // A missing permission or platform hiccup must not surface here.
        }
      }),
    );
  }

  final Map<String, _CardSync> _sync = {};
  final Map<String, Future<void>> _writeChains = {};
  Future<void> _sessionWriteChain = Future<void>.value();

  /// Every deck card's `mastery_level` snapshotted at session start — the
  /// baseline for the Session Summary's whole-deck mastery delta (spec §7).
  Map<String, int> _deckMasteryAtStart = const {};

  /// Session-scoped recall counters (spec §7). A "miss" is any result short of
  /// Mastered, i.e. every requeue.
  int _requeues = 0;
  final Set<String> _missedCardIds = {};

  StudySessionState? get _state => state.value;

  /// Starts (or, if one is already live for [deckId], quietly re-attaches to) a
  /// session. Runs the conflict rule first, builds the queue, inserts the rows,
  /// and stamps `last_studied_at`.
  Future<void> start({
    required String deckId,
    required String? deckName,
    required StudyMode mode,
    required SessionLengthMode lengthMode,
    required int? cap,
    CardScope cardScope = CardScope.due,
  }) async {
    final existing = _state;
    if (existing != null &&
        existing.deckId == deckId &&
        existing.session.studyMode == mode &&
        !existing.isComplete) {
      return; // resume: the live session in the same mode is already in memory
    }

    // Switching modes on a still-live session: let its background writes land
    // before the queue is rebuilt.
    if (existing != null && !existing.isComplete) {
      await _flushAllPendingWrites();
    }

    _resetInternals();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _study.abandonActiveSessions(deckId);

      // Local-first and timeout-bounded (spec §2 / §10) — a started session can
      // never hang between the mode pick and the first card.
      final cards = await loadStudyDeckCards(ref, deckId);
      _deckMasteryAtStart = {for (final c in cards) c.id: c.masteryLevel};
      final capNum = lengthMode == SessionLengthMode.capped ? cap : null;
      final ordered = selectSessionCards(
        cards: cards,
        mode: mode,
        cap: capNum,
        cardScope: cardScope,
      );
      if (ordered.isEmpty) throw const EmptyQueueException();

      return _seedSession(
        deckId: deckId,
        deckName: deckName,
        mode: mode,
        lengthMode: lengthMode,
        cap: capNum,
        cardScope: cardScope,
        ordered: ordered,
      );
    });

    if (state.hasValue) {
      ref.invalidate(decksProvider);
      _refreshPendingSync();
      _refreshSessionReads();
      // The user is back studying — drop any pending "come back" reminder.
      _notify(_notifications.cancelReturnReminder);
    }
  }

  /// Starts the "drill parked cards now" session from the Session Summary
  /// (spec §7): a scoped run over exactly [parkedCardIds] — the cards parked in
  /// the session just finished — in the same [mode]. Uncapped and
  /// until-mastered; this is the deliberate exception to §4's queue-selection
  /// rule, so it does not go through [selectSessionCards].
  Future<void> startParkedDrill({
    required String deckId,
    required String? deckName,
    required StudyMode mode,
    required List<String> parkedCardIds,
  }) async {
    await _flushAllPendingWrites();
    _resetInternals();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _study.abandonActiveSessions(deckId);

      final cards = await loadStudyDeckCards(ref, deckId);
      _deckMasteryAtStart = {for (final c in cards) c.id: c.masteryLevel};
      final wanted = parkedCardIds.toSet();
      final ordered = cards.where((c) => wanted.contains(c.id)).toList();
      if (ordered.isEmpty) throw const EmptyQueueException();

      return _seedSession(
        deckId: deckId,
        deckName: deckName,
        mode: mode,
        lengthMode: SessionLengthMode.untilMastered,
        cap: null,
        cardScope: CardScope.due,
        ordered: ordered,
      );
    });

    if (state.hasValue) {
      ref.invalidate(decksProvider);
      _refreshPendingSync();
      _refreshSessionReads();
      _notify(_notifications.cancelReturnReminder);
    }
  }

  /// Inserts the `study_sessions` + `session_cards` rows for [ordered], stamps
  /// `last_studied_at`, seeds the `_sync` map, and returns the initial
  /// in-memory state. Shared by [start] and [startParkedDrill].
  Future<StudySessionState> _seedSession({
    required String deckId,
    required String? deckName,
    required StudyMode mode,
    required SessionLengthMode lengthMode,
    required int? cap,
    required CardScope cardScope,
    required List<FlashCard> ordered,
  }) async {
    final session = await _study.createSession(
      deckId: deckId,
      studyMode: mode,
      lengthMode: lengthMode,
      cappedLength: cap,
      cardScope: cardScope,
    );
    final rows = await _study.createSessionCards(
      session.id,
      seedsFrom(ordered),
    );

    try {
      await _decks.markDeckStudied(deckId);
    } catch (_) {
      // Non-fatal: the session rows already exist.
    }

    final byCardId = {for (final c in ordered) c.id: c};
    final items = [
      for (final row in rows)
        if (byCardId[row.cardId] case final card?)
          StudyQueueItem(
            sessionCardId: row.id,
            card: card,
            position: row.position,
            consecutiveFails: row.consecutiveFails,
            isParked: row.isParked,
            masteryLevel: card.masteryLevel,
          ),
    ];
    for (final card in ordered) {
      _sync[card.id] = _CardSync(
        baseMastery: card.masteryLevel,
        baseFailCount: card.failCount,
        baseUpdatedAt: card.updatedAt,
      );
    }

    return StudySessionState.initial(
      session: session,
      deckId: deckId,
      deckName: deckName,
      items: items,
    );
  }

  /// Applies a rating to the current card — synchronous and optimistic.
  ///
  /// Every mode routes through here: Flip picks the rating directly, and since
  /// the UI revamp (ui-spec-v1 §6.2) Cloze, List and Feynman all reveal their
  /// content (or run their timer) and then use the same 0–4 rating row rather
  /// than an auto-derived outcome.
  void rate(FlipRating rating) => _applyResult(rating.level);

  /// Applies a Cloze card's auto-derived outcome to the current card
  /// (`docs/spec.md` §6) — synchronous and optimistic, exactly like [rate].
  /// The widget has already aggregated the per-blank results into a single
  /// [ClozeOutcome]; the mode has no manual rating row.
  void submitCloze(ClozeOutcome outcome) => _applyResult(outcome.masteryLevel);

  /// The shared optimistic-progression path for every mode: advance the
  /// in-memory queue now, then fire the guarded `cards` write and the
  /// session-scoped `session_cards` write in the background.
  void _applyResult(int masteryLevel) {
    final current = _state;
    if (current == null || current.phase != SessionPhase.studying) return;

    final result = current.applyResult(masteryLevel: masteryLevel);
    final effects = result.effects;

    if (effects.isFail) {
      _requeues++;
      _missedCardIds.add(effects.cardId);
    }

    state = AsyncData(_attachOutcomeIfDone(result.state));

    final sync = _sync[effects.cardId];
    if (sync != null) {
      sync.desiredMastery = effects.newMasteryLevel;
      if (effects.isFail) sync.unpersistedFailIncrements++;
      _scheduleCardWrite(effects.cardId);
    }

    if (effects.isFail && effects.newPosition != null) {
      _scheduleSessionWrite(
        () => _study.updateSessionCard(
          sessionCardId: effects.sessionCardId,
          position: effects.newPosition,
          consecutiveFails: effects.newConsecutiveFails,
        ),
      );
    }

    if (result.state.phase == SessionPhase.completed) {
      unawaited(_finishSession());
    }
  }

  /// If [next] is the completed transition, builds the Session Summary figures
  /// (spec §7) and attaches them; otherwise returns [next] unchanged.
  StudySessionState _attachOutcomeIfDone(StudySessionState next) {
    if (next.phase != SessionPhase.completed) return next;
    final afterLevels = _deckMasteryAtStart.entries.map(
      (e) => _sync[e.key]?.desiredMastery ?? e.value,
    );
    return next.withOutcome(
      SessionOutcome(
        masteryPercentBefore: masteryPercentFromLevels(
          _deckMasteryAtStart.values,
        ),
        masteryPercentAfter: masteryPercentFromLevels(afterLevels),
        cardsStudied: next.totalCards,
        mastered: next.masteredCardIds.length,
        parked: next.parkedCardIds.length,
        firstTryMastered: next.masteredCardIds
            .difference(_missedCardIds)
            .length,
        requeues: _requeues,
      ),
    );
  }

  /// Parks the prompted card.
  void confirmPark() {
    final current = _state;
    if (current == null || current.phase != SessionPhase.parkPrompt) return;
    final sessionCardId = current.pendingParkSessionCardId;

    final next = current.confirmPark();
    state = AsyncData(_attachOutcomeIfDone(next));

    if (sessionCardId != null) {
      _scheduleSessionWrite(
        () => _study.updateSessionCard(
          sessionCardId: sessionCardId,
          isParked: true,
        ),
      );
    }
    if (next.phase == SessionPhase.completed) {
      unawaited(_finishSession());
    }
  }

  /// Declines the park: the card stays with a fresh three-fail budget.
  void declinePark() {
    final current = _state;
    if (current == null || current.phase != SessionPhase.parkPrompt) return;
    final sessionCardId = current.pendingParkSessionCardId;

    state = AsyncData(current.declinePark());

    if (sessionCardId != null) {
      _scheduleSessionWrite(
        () => _study.updateSessionCard(
          sessionCardId: sessionCardId,
          consecutiveFails: 0,
        ),
      );
    }
  }

  /// Leaves the session mid-flight. It stays `active` (the next session on this
  /// deck abandons it via the conflict rule); the in-memory state is kept so
  /// the Deck Overview can offer "Resume session".
  void exit() {
    final current = _state;
    if (current == null) return;
    ref.invalidate(deckCardsProvider(current.deckId));
    ref.invalidate(decksProvider);
    _refreshPendingSync();
    _refreshSessionReads();
    _triggerSync();

    if (!current.isComplete) {
      // Cards still below Mastered: the ones left in the queue plus any parked
      // this session (spec §8 — the "most recent session" reminder).
      final outstanding = current.queue.length + current.parkedCardIds.length;
      if (outstanding > 0) {
        _notify(
          () => _notifications.scheduleReturnReminder(
            deckName: current.deckName,
            unfinishedCount: outstanding,
          ),
        );
      }
    }
  }

  /// Clears the finished/errored session so the next `start` builds fresh.
  void reset() {
    _resetInternals();
    state = const AsyncData(null);
  }

  Future<void> _finishSession() async {
    final current = _state;
    if (current == null) return;
    await _flushAllPendingWrites();
    try {
      await _study.completeSession(
        current.session.id,
        masteryDelta: current.outcome?.masteryDelta,
        cardsReviewed: current.outcome?.cardsStudied,
      );
    } catch (_) {
      // Non-fatal: the Session Summary is driven by in-memory state, not this
      // write.
    }
    _refreshPendingSync();

    // Spec §8: a completed session still leaves parked cards for next time.
    final parked = current.parkedCardIds.length;
    if (parked > 0) {
      _notify(
        () => _notifications.scheduleReturnReminder(
          deckName: current.deckName,
          unfinishedCount: parked,
        ),
      );
    } else {
      _notify(_notifications.cancelReturnReminder);
    }

    ref.invalidate(deckCardsProvider(current.deckId));
    ref.invalidate(decksProvider);
    _refreshSessionReads();
    _triggerSync();
  }

  void _scheduleCardWrite(String cardId) {
    final prev = _writeChains[cardId] ?? Future<void>.value();
    _writeChains[cardId] = prev
        .then((_) => _flushCardWrite(cardId))
        .catchError((_) {})
        .whenComplete(_refreshPendingSync);
  }

  void _scheduleSessionWrite(Future<void> Function() write) {
    _sessionWriteChain = _sessionWriteChain
        .then((_) => write())
        .catchError((_) {})
        .whenComplete(_refreshPendingSync);
  }

  Future<void> _flushCardWrite(String cardId) async {
    final sync = _sync[cardId];
    if (sync == null) return;

    final desiredMastery = sync.desiredMastery;
    final desiredFail = sync.baseFailCount + sync.unpersistedFailIncrements;
    if (desiredMastery == sync.baseMastery &&
        sync.unpersistedFailIncrements == 0) {
      return;
    }

    final row = await _decks.updateCardMasteryGuarded(
      cardId: cardId,
      masteryLevel: desiredMastery,
      failCount: desiredFail,
      expectedUpdatedAt: sync.baseUpdatedAt,
    );
    if (row != null) {
      _rebase(sync, row.masteryLevel, row.failCount, row.updatedAt);
      return;
    }

    // Guard missed — the row moved under us. Re-read, rebase, retry once.
    final fresh = await _decks.readCardMasteryState(cardId);
    sync
      ..baseMastery = fresh.masteryLevel
      ..baseFailCount = fresh.failCount
      ..baseUpdatedAt = fresh.updatedAt;
    final retry = await _decks.updateCardMasteryGuarded(
      cardId: cardId,
      masteryLevel: sync.desiredMastery,
      failCount: sync.baseFailCount + sync.unpersistedFailIncrements,
      expectedUpdatedAt: sync.baseUpdatedAt,
    );
    if (retry != null) {
      _rebase(sync, retry.masteryLevel, retry.failCount, retry.updatedAt);
    }
  }

  void _rebase(_CardSync sync, int mastery, int failCount, DateTime updatedAt) {
    sync
      ..baseMastery = mastery
      ..baseFailCount = failCount
      ..baseUpdatedAt = updatedAt
      ..unpersistedFailIncrements = 0;
  }

  Future<void> _flushAllPendingWrites() async {
    // Drain the chains, then sweep once more for anything still dirty.
    await Future.wait([..._writeChains.values, _sessionWriteChain]);
    final sweep = [for (final cardId in _sync.keys) _flushCardWrite(cardId)];
    await Future.wait(sweep);
  }

  void _resetInternals() {
    _sync.clear();
    _writeChains.clear();
    _sessionWriteChain = Future<void>.value();
    _deckMasteryAtStart = const {};
    _requeues = 0;
    _missedCardIds.clear();
  }
}
