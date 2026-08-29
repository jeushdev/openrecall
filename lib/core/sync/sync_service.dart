import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/decks/data/local_deck_store.dart';
import '../../features/decks/data/supabase_deck_repository.dart';
import '../../features/study/data/local_study_store.dart';
import '../connectivity/connectivity_service.dart';

/// Pushes everything the local mirror has marked `is_synced = 0` up to Supabase
/// when connectivity returns (spec §10).
///
/// Order is `cards → study_sessions → session_cards` — dependency order, so a
/// fully-offline session's `session_cards` never reference a `study_sessions`
/// row Supabase hasn't seen yet. `cards` go through the same `updated_at`
/// compare-and-set as a live background write (never a blind update); a guard
/// miss means a newer server value exists, and last-write-wins is resolved by
/// re-reading and retrying once. Sessions and session-cards are batched upserts,
/// not one network call per row.
class SyncService {
  SyncService(
    this._client,
    this._deckLocal,
    this._studyLocal,
    this._connectivity,
  );

  final SupabaseClient _client;
  final LocalDeckStore _deckLocal;
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
    if (_deckLocal.isNoop && _studyLocal.isNoop) return;
    if (!await _connectivity.isOnline()) return;
    if (_client.auth.currentUser == null) return;

    _running = true;
    try {
      await _pushCards();
      await _pushSessions();
      await _pushSessionCards();
    } catch (_) {
      // Swallowed on purpose — see the class doc.
    } finally {
      _running = false;
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
}
