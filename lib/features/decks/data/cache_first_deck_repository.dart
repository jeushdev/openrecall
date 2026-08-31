import '../../../core/ids.dart';
import '../../courses/data/local_course_store.dart';
import '../domain/bulk_paste_parser.dart';
import '../domain/card.dart';
import '../domain/deck.dart';
import '../domain/deck_repository.dart';
import 'local_deck_store.dart';

/// Thrown by [CacheFirstDeckRepository.fetchCards] when a deck is neither
/// reachable online nor downloaded — "a deck that isn't downloaded and has no
/// connection simply isn't available" (spec §10).
class DeckUnavailableOfflineException implements Exception {
  const DeckUnavailableOfflineException(this.deckId);
  final String deckId;
  @override
  String toString() => 'DeckUnavailableOfflineException($deckId)';
}

/// Wraps the Supabase-backed deck repository with the local SQLite mirror
/// (spec §10, spec-v4 §4).
///
/// Reads are read-through: hit Supabase, refresh the mirror, return the remote
/// data; if the Supabase call throws, fall back to the mirror (for downloaded
/// decks) and otherwise rethrow. The study-loop writes
/// (`updateCardMasteryGuarded`, `readCardMasteryState`, `markDeckStudied`)
/// behave the same way — Supabase first, local mirror as the offline fallback,
/// with the offline mastery write marked unsynced for the reconnect pass.
///
/// Deck and card authoring (`createDeck` / `updateDeck` / `deleteDeck` /
/// `addCard` / `addCards` / `updateCard` / `deleteCard`) is cache-first with a
/// local-queue fallback: each tries [_remote] first and, when that throws
/// (typically: offline), writes [_local] with a client-generated UUID and
/// `is_synced = 0` so [SyncService] pushes it on reconnect. When there is no
/// local database (`_local.isNoop`) the remote error is rethrown, so the
/// repository behaves exactly like the plain Supabase one.
class CacheFirstDeckRepository implements DeckRepository {
  CacheFirstDeckRepository(this._remote, this._local, this._courseLocal);

  /// The Supabase-backed repository in production; a fake in tests. Typed as the
  /// interface so the cache-first logic can be unit-tested without a client.
  final DeckRepository _remote;
  final LocalDeckStore _local;
  final LocalCourseStore _courseLocal;

  @override
  Future<List<DeckSummary>> fetchDecks() async {
    try {
      final remote = await _remote.fetchDecks();
      await _local.refreshDeckMeta(remote);
      return remote;
    } catch (_) {
      final cached = await _local.cachedDeckSummaries();
      if (cached.isEmpty) rethrow;
      return cached;
    }
  }

  @override
  Future<List<FlashCard>> fetchCards(String deckId) async {
    try {
      final cards = await _remote.fetchCards(deckId);
      if (await _local.isDownloaded(deckId)) {
        await _local.mirrorCards(deckId, cards);
      }
      return cards;
    } catch (_) {
      if (await _local.isDownloaded(deckId)) return _local.cards(deckId);
      if (_local.isNoop) rethrow;
      throw DeckUnavailableOfflineException(deckId);
    }
  }

  @override
  Future<CardMasteryState> readCardMasteryState(String cardId) async {
    try {
      return await _remote.readCardMasteryState(cardId);
    } catch (_) {
      final local = await _local.cardById(cardId);
      if (local == null) rethrow;
      return CardMasteryState(
        masteryLevel: local.masteryLevel,
        failCount: local.failCount,
        updatedAt: local.updatedAt,
      );
    }
  }

  @override
  Future<FlashCard?> updateCardMasteryGuarded({
    required String cardId,
    required int masteryLevel,
    required int failCount,
    required DateTime expectedUpdatedAt,
  }) async {
    try {
      final row = await _remote.updateCardMasteryGuarded(
        cardId: cardId,
        masteryLevel: masteryLevel,
        failCount: failCount,
        expectedUpdatedAt: expectedUpdatedAt,
      );
      if (row != null && await _local.cardById(cardId) != null) {
        await _local.mirrorCardMastery(row);
      }
      return row;
    } catch (_) {
      final local = await _local.cardById(cardId);
      if (local == null) rethrow;
      return _local.writeCardMasteryUnsynced(
        cardId: cardId,
        masteryLevel: masteryLevel,
        failCount: failCount,
        expectedUpdatedAt: expectedUpdatedAt,
      );
    }
  }

  @override
  Future<void> markDeckStudied(String deckId) async {
    try {
      await _remote.markDeckStudied(deckId);
    } catch (_) {
      // Best-effort: the local stamp below still lands, and the column is not
      // part of the sync surface.
    }
    await _local.touchLastStudied(deckId);
  }

  // ---- cache-first authoring (spec-v4 §4: Supabase first, local queue on
  //      failure) ---------------------------------------------------------------

  @override
  Future<Deck> createDeck(String name, {String? courseId}) async {
    try {
      return await _remote.createDeck(name, courseId: courseId);
    } catch (_) {
      if (_local.isNoop) rethrow;
      final id = newUuid();
      // An offline create with no course resolves to the mirrored default
      // course, matching the server `decks_fill_default_course` trigger.
      final resolvedCourseId =
          courseId ?? await _courseLocal.defaultCourseId();
      await _local.createDeck(id: id, name: name, courseId: resolvedCourseId);
      final now = DateTime.now().toUtc();
      return Deck(
        id: id,
        name: name,
        courseId: resolvedCourseId,
        lastStudiedAt: null,
        createdAt: now,
        updatedAt: now,
      );
    }
  }

  @override
  Future<Deck> updateDeck({
    required String id,
    String? name,
    String? courseId,
  }) async {
    try {
      return await _remote.updateDeck(id: id, name: name, courseId: courseId);
    } catch (_) {
      if (_local.isNoop) rethrow;
      await _local.updateDeck(id: id, name: name, courseId: courseId);
      // `updateDeck` is a void no-op on an unknown id, so a read-back is how we
      // tell the edit actually landed.
      final matches = (await _local.cachedDeckSummaries())
          .where((d) => d.id == id)
          .toList();
      if (matches.isEmpty) rethrow;
      final row = matches.first;
      final now = DateTime.now().toUtc();
      return Deck(
        id: id,
        name: row.name,
        courseId: row.courseId,
        lastStudiedAt: row.lastStudiedAt,
        createdAt: now,
        updatedAt: now,
      );
    }
  }

  @override
  Future<void> deleteDeck(String id) async {
    try {
      await _remote.deleteDeck(id);
    } catch (_) {
      if (_local.isNoop) rethrow;
      await _local.deleteDeck(id);
    }
  }

  @override
  Future<FlashCard> addCard({
    required String deckId,
    required String front,
    required String back,
    required List<String> keywords,
    required bool isConcept,
  }) async {
    try {
      return await _remote.addCard(
        deckId: deckId,
        front: front,
        back: back,
        keywords: keywords,
        isConcept: isConcept,
      );
    } catch (_) {
      if (_local.isNoop) rethrow;
      final card = _offlineCard(
        deckId,
        front: front,
        back: back,
        keywords: keywords,
        isConcept: isConcept,
      );
      await _local.insertCards([card]);
      return card;
    }
  }

  @override
  Future<List<FlashCard>> addCards(String deckId, List<ParsedCard> cards) async {
    try {
      return await _remote.addCards(deckId, cards);
    } catch (_) {
      if (_local.isNoop) rethrow;
      final built = [
        for (final c in cards)
          _offlineCard(
            deckId,
            front: c.front,
            back: c.back,
            keywords: c.keywords,
            isConcept: c.isConcept,
          ),
      ];
      await _local.insertCards(built);
      return built;
    }
  }

  @override
  Future<FlashCard> updateCard({
    required String id,
    required String front,
    required String back,
    required List<String> keywords,
    required bool isConcept,
  }) async {
    try {
      return await _remote.updateCard(
        id: id,
        front: front,
        back: back,
        keywords: keywords,
        isConcept: isConcept,
      );
    } catch (_) {
      if (_local.isNoop) rethrow;
      final existing = await _local.cardById(id);
      if (existing == null) rethrow;
      await _local.updateCardContent(
        id: id,
        front: front,
        back: back,
        keywords: keywords,
        isConcept: isConcept,
      );
      return FlashCard(
        id: existing.id,
        deckId: existing.deckId,
        front: front,
        back: back,
        keywords: keywords,
        isConcept: isConcept,
        masteryLevel: existing.masteryLevel,
        failCount: existing.failCount,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
    }
  }

  @override
  Future<void> deleteCard(String id) async {
    try {
      await _remote.deleteCard(id);
    } catch (_) {
      if (_local.isNoop) rethrow;
      await _local.deleteCard(id);
    }
  }

  /// Online-only: rewriting every card's `mastery_level` is a bulk, rare action
  /// (the user taps "study this deck again" after mastering it). It is not worth
  /// a local-queue path — if it fails offline the user simply retries once
  /// connected.
  @override
  Future<void> resetDeckMastery(String deckId) =>
      _remote.resetDeckMastery(deckId);

  /// Straight passthrough to Supabase — reorder has no local-queue fallback yet
  /// (milestone B). A failure (offline) propagates so the caller reverts its
  /// optimistic order; milestone E routes this through the write queue instead.
  @override
  Future<void> reorderDecks(List<String> orderedIds) =>
      _remote.reorderDecks(orderedIds);

  /// A card authored offline: client-generated id, zeroed mastery, now-stamped.
  FlashCard _offlineCard(
    String deckId, {
    required String front,
    required String back,
    required List<String> keywords,
    required bool isConcept,
  }) {
    final now = DateTime.now().toUtc();
    return FlashCard(
      id: newUuid(),
      deckId: deckId,
      front: front,
      back: back,
      keywords: keywords,
      isConcept: isConcept,
      masteryLevel: 0,
      failCount: 0,
      createdAt: now,
      updatedAt: now,
    );
  }
}
