import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../decks/application/deck_providers.dart';
import '../../decks/domain/deck_repository.dart';
import '../../decks/domain/study_mode.dart';
import '../data/supabase_study_repository.dart';
import '../domain/cloze_outcome.dart';
import '../domain/flip_rating.dart';
import '../domain/session_length.dart';
import '../domain/session_queue_selection.dart';
import '../domain/study_queue_item.dart';
import '../domain/study_repository.dart';
import '../domain/study_session_state.dart';

/// Thrown by [SessionController.start] when nothing in the deck qualifies for
/// the picked mode — the study screen shows a "nothing to study" message
/// instead of an error.
class EmptyQueueException implements Exception {
  const EmptyQueueException();
  @override
  String toString() => 'EmptyQueueException';
}

/// The live study repository, backed by the Supabase singleton. Tests override
/// it with a fake.
final studyRepositoryProvider = Provider<StudyRepository>((ref) {
  return SupabaseStudyRepository(Supabase.instance.client);
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

  final Map<String, _CardSync> _sync = {};
  final Map<String, Future<void>> _writeChains = {};

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

      final cards = await _decks.fetchCards(deckId);
      final capNum = lengthMode == SessionLengthMode.capped ? cap : null;
      final ordered =
          selectSessionCards(cards: cards, mode: mode, cap: capNum);
      if (ordered.isEmpty) throw const EmptyQueueException();

      final session = await _study.createSession(
        deckId: deckId,
        studyMode: mode,
        lengthMode: lengthMode,
        cappedLength: capNum,
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
    });

    if (state.hasValue) ref.invalidate(decksProvider);
  }

  /// Applies a Flip rating to the current card — synchronous and optimistic.
  void rate(FlipRating rating) => _applyResult(rating.level);

  /// Applies a Cloze attempt outcome to the current card (spec §5B/§6) —
  /// synchronous and optimistic, exactly like [rate]. The outcome has already
  /// been mapped to a `mastery_level`.
  void submitCloze(ClozeOutcome outcome) => _applyResult(outcome.masteryLevel);

  /// Applies a List card result to the current card (spec §5C/§6) — synchronous
  /// and optimistic, exactly like [rate]. The reveal ratio has already been
  /// mapped to a `mastery_level` by the List widget.
  void submitList(int masteryLevel) => _applyResult(masteryLevel);

  /// The shared optimistic-progression path for every mode: advance the
  /// in-memory queue now, then fire the guarded `cards` write and the
  /// session-scoped `session_cards` write in the background.
  void _applyResult(int masteryLevel) {
    final current = _state;
    if (current == null || current.phase != SessionPhase.studying) return;

    final result = current.applyResult(masteryLevel: masteryLevel);
    state = AsyncData(result.state);

    final effects = result.effects;
    final sync = _sync[effects.cardId];
    if (sync != null) {
      sync.desiredMastery = effects.newMasteryLevel;
      if (effects.isFail) sync.unpersistedFailIncrements++;
      _scheduleCardWrite(effects.cardId);
    }

    if (effects.isFail && effects.newPosition != null) {
      unawaited(_study.updateSessionCard(
        sessionCardId: effects.sessionCardId,
        position: effects.newPosition,
        consecutiveFails: effects.newConsecutiveFails,
      ));
    }

    if (result.state.phase == SessionPhase.completed) {
      unawaited(_finishSession());
    }
  }

  /// Parks the prompted card.
  void confirmPark() {
    final current = _state;
    if (current == null || current.phase != SessionPhase.parkPrompt) return;
    final sessionCardId = current.pendingParkSessionCardId;

    final next = current.confirmPark();
    state = AsyncData(next);

    if (sessionCardId != null) {
      unawaited(_study.updateSessionCard(
        sessionCardId: sessionCardId,
        isParked: true,
      ));
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
      unawaited(_study.updateSessionCard(
        sessionCardId: sessionCardId,
        consecutiveFails: 0,
      ));
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
      await _study.completeSession(current.session.id);
    } catch (_) {
      // Non-fatal for the beta — the summary screen is a later milestone.
    }
    ref.invalidate(deckCardsProvider(current.deckId));
    ref.invalidate(decksProvider);
  }

  void _scheduleCardWrite(String cardId) {
    final prev = _writeChains[cardId] ?? Future<void>.value();
    _writeChains[cardId] =
        prev.then((_) => _flushCardWrite(cardId)).catchError((_) {});
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
    await Future.wait(_writeChains.values);
    final sweep = [
      for (final cardId in _sync.keys) _flushCardWrite(cardId),
    ];
    await Future.wait(sweep);
  }

  void _resetInternals() {
    _sync.clear();
    _writeChains.clear();
  }
}
