import '../domain/bulk_paste_parser.dart';
import '../domain/card.dart';
import '../domain/deck.dart';
import '../domain/deck_repository.dart';
import 'local_deck_store.dart';
import 'supabase_deck_repository.dart';

/// Thrown by [CacheFirstDeckRepository.fetchCards] when a deck is neither
/// reachable online nor downloaded — "a deck that isn't downloaded and has no
/// connection simply isn't available" (spec §10).
class DeckUnavailableOfflineException implements Exception {
  const DeckUnavailableOfflineException(this.deckId);
  final String deckId;
  @override
  String toString() => 'DeckUnavailableOfflineException($deckId)';
}

/// Wraps [SupabaseDeckRepository] with the local SQLite mirror (spec §10).
///
/// Reads are read-through: hit Supabase, refresh the mirror for downloaded
/// decks, return the remote data; if the Supabase call throws, fall back to the
/// mirror for downloaded decks and otherwise rethrow. The study-loop writes
/// (`updateCardMasteryGuarded`, `readCardMasteryState`, `markDeckStudied`)
/// behave the same way — Supabase first, local mirror as the offline fallback,
/// with the offline mastery write marked unsynced for the reconnect pass.
///
/// Card authoring (`createDeck` / `addCard` / … ) is online-only by spec, so it
/// is a straight pass-through — it simply fails when offline, and the UI hides
/// those affordances.
class CacheFirstDeckRepository implements DeckRepository {
  CacheFirstDeckRepository(this._remote, this._local);

  final SupabaseDeckRepository _remote;
  final LocalDeckStore _local;

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

  // ---- online-only pass-throughs (spec §3: authoring requires connectivity) --

  @override
  Future<Deck> createDeck(String name, {String? courseId}) =>
      _remote.createDeck(name, courseId: courseId);

  @override
  Future<FlashCard> addCard({
    required String deckId,
    required String front,
    required String back,
    required List<String> keywords,
    required bool isConcept,
  }) =>
      _remote.addCard(
        deckId: deckId,
        front: front,
        back: back,
        keywords: keywords,
        isConcept: isConcept,
      );

  @override
  Future<List<FlashCard>> addCards(String deckId, List<ParsedCard> cards) =>
      _remote.addCards(deckId, cards);

  @override
  Future<Deck> updateDeck({
    required String id,
    String? name,
    String? courseId,
  }) =>
      _remote.updateDeck(id: id, name: name, courseId: courseId);

  @override
  Future<void> deleteDeck(String id) => _remote.deleteDeck(id);

  @override
  Future<FlashCard> updateCard({
    required String id,
    required String front,
    required String back,
    required List<String> keywords,
    required bool isConcept,
  }) =>
      _remote.updateCard(
        id: id,
        front: front,
        back: back,
        keywords: keywords,
        isConcept: isConcept,
      );

  @override
  Future<void> deleteCard(String id) => _remote.deleteCard(id);

  @override
  Future<void> resetDeckMastery(String deckId) =>
      _remote.resetDeckMastery(deckId);
}
