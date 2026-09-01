import 'dart:async';

import 'package:open_recall/features/decks/domain/bulk_paste_parser.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/decks/domain/deck_repository.dart';

/// In-memory [DeckRepository] for provider and widget tests.
///
/// Records every mutating call, holds decks and cards in plain lists, and can
/// be armed to throw on the next call. Also backs the session engine's guarded
/// `cards` writes ([updateCardMasteryGuarded] / [readCardMasteryState]) and
/// [markDeckStudied]; [guardGate] and [failNextGuard] drive the write-race and
/// guard-miss tests.
class FakeDeckRepository implements DeckRepository {
  FakeDeckRepository({List<DeckSummary>? decks, List<FlashCard>? cards})
      : _decks = [...?decks],
        _cards = [...?cards];

  final List<DeckSummary> _decks;
  final List<FlashCard> _cards;

  /// Method-name + key arguments for each call, in order.
  final List<String> calls = <String>[];

  /// When set, the next repository call throws this and then clears it.
  Object? throwOnNextCall;

  /// When set, every repository call throws this (models a sustained outage —
  /// the offline case the cache-first layer must absorb).
  Object? alwaysThrow;

  /// When true, [fetchDecks] and [fetchCards] return a future that never
  /// completes — an unreachable host rather than a refused connection, the
  /// case the Decks-tab timeout used to mishandle.
  bool hangForever = false;

  /// When set, [updateCardMasteryGuarded] awaits this before applying — lets a
  /// test hold a background write open while another rating happens.
  Completer<void>? guardGate;

  /// When true, the next [updateCardMasteryGuarded] call reports a guard miss
  /// (returns `null`) after nudging the row's `updated_at`, then clears.
  bool failNextGuard = false;

  int _idSeq = 0;
  String _nextId(String prefix) => '$prefix-${++_idSeq}';

  void _maybeThrow() {
    if (alwaysThrow != null) throw alwaysThrow!;
    final error = throwOnNextCall;
    if (error != null) {
      throwOnNextCall = null;
      throw error;
    }
  }

  // A monotonic clock so every write moves `updated_at` — the compare-and-set
  // guard is only observable if timestamps actually change.
  int _tick = 0;
  DateTime get _now =>
      DateTime.utc(2026, 1, 1).add(Duration(seconds: _tick++));

  FlashCard? cardById(String id) {
    for (final c in _cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  FlashCard _card({
    required String deckId,
    required String front,
    required String back,
    List<String> keywords = const [],
    bool isConcept = false,
    int masteryLevel = 0,
    int failCount = 0,
  }) =>
      FlashCard(
        id: _nextId('card'),
        deckId: deckId,
        front: front,
        back: back,
        keywords: keywords,
        isConcept: isConcept,
        masteryLevel: masteryLevel,
        failCount: failCount,
        createdAt: _now,
        updatedAt: _now,
      );

  @override
  Future<List<DeckSummary>> fetchDecks() async {
    calls.add('fetchDecks()');
    _maybeThrow();
    if (hangForever) return Completer<List<DeckSummary>>().future;
    return List.unmodifiable(_decks);
  }

  @override
  Future<Deck> createDeck(String name, {String? courseId}) async {
    calls.add(courseId == null
        ? 'createDeck($name)'
        : 'createDeck($name, course=$courseId)');
    _maybeThrow();
    final deck = Deck(
      id: _nextId('deck'),
      name: name,
      courseId: courseId,
      lastStudiedAt: null,
      createdAt: _now,
      updatedAt: _now,
    );
    _decks.insert(
      0,
      DeckSummary(
        id: deck.id,
        name: deck.name,
        courseId: courseId,
        lastStudiedAt: null,
        totalCards: 0,
        dueCards: 0,
        masteryPercent: 0,
      ),
    );
    return deck;
  }

  @override
  Future<Deck> updateDeck({
    required String id,
    String? name,
    String? courseId,
  }) async {
    calls.add('updateDeck(id=$id, name=$name, course=$courseId)');
    _maybeThrow();
    final i = _decks.indexWhere((d) => d.id == id);
    final existing = _decks[i];
    final updated = DeckSummary(
      id: existing.id,
      name: name ?? existing.name,
      courseId: courseId ?? existing.courseId,
      lastStudiedAt: existing.lastStudiedAt,
      totalCards: existing.totalCards,
      dueCards: existing.dueCards,
      masteryPercent: existing.masteryPercent,
      masteryLevelSum: existing.masteryLevelSum,
    );
    _decks[i] = updated;
    return Deck(
      id: updated.id,
      name: updated.name,
      courseId: updated.courseId,
      lastStudiedAt: updated.lastStudiedAt,
      createdAt: _now,
      updatedAt: _now,
    );
  }

  @override
  Future<void> deleteDeck(String id) async {
    calls.add('deleteDeck($id)');
    _maybeThrow();
    _decks.removeWhere((d) => d.id == id);
    _cards.removeWhere((c) => c.deckId == id);
  }

  @override
  Future<List<FlashCard>> fetchCards(String deckId) async {
    calls.add('fetchCards($deckId)');
    _maybeThrow();
    if (hangForever) return Completer<List<FlashCard>>().future;
    return _cards.where((c) => c.deckId == deckId).toList();
  }

  @override
  Future<FlashCard> addCard({
    required String deckId,
    required String front,
    required String back,
    required List<String> keywords,
    required bool isConcept,
  }) async {
    calls.add('addCard(deck=$deckId, front=$front, back=$back, '
        'keywords=$keywords, concept=$isConcept)');
    _maybeThrow();
    final card = _card(
      deckId: deckId,
      front: front,
      back: back,
      keywords: keywords,
      isConcept: isConcept,
    );
    _cards.add(card);
    return card;
  }

  @override
  Future<List<FlashCard>> addCards(String deckId, List<ParsedCard> cards) async {
    calls.add('addCards($deckId, ${cards.length})');
    _maybeThrow();
    final added = [
      for (final c in cards)
        _card(
          deckId: deckId,
          front: c.front,
          back: c.back,
          keywords: c.keywords,
          isConcept: c.isConcept,
        ),
    ];
    _cards.addAll(added);
    return added;
  }

  @override
  Future<FlashCard> updateCard({
    required String id,
    required String front,
    required String back,
    required List<String> keywords,
    required bool isConcept,
  }) async {
    calls.add('updateCard(id=$id, front=$front, back=$back, '
        'keywords=$keywords, concept=$isConcept)');
    _maybeThrow();
    final i = _cards.indexWhere((c) => c.id == id);
    final existing = _cards[i];
    final updated = FlashCard(
      id: existing.id,
      deckId: existing.deckId,
      front: front,
      back: back,
      keywords: keywords,
      isConcept: isConcept,
      masteryLevel: existing.masteryLevel,
      failCount: existing.failCount,
      createdAt: existing.createdAt,
      updatedAt: _now,
    );
    _cards[i] = updated;
    return updated;
  }

  @override
  Future<void> deleteCard(String id) async {
    calls.add('deleteCard($id)');
    _maybeThrow();
    _cards.removeWhere((c) => c.id == id);
  }

  @override
  Future<void> resetDeckMastery(String deckId) async {
    calls.add('resetDeckMastery($deckId)');
    _maybeThrow();
    for (var i = 0; i < _cards.length; i++) {
      if (_cards[i].deckId == deckId) {
        _cards[i] = _rebuild(_cards[i], masteryLevel: 0, updatedAt: _now);
      }
    }
  }

  @override
  Future<CardMasteryState> readCardMasteryState(String cardId) async {
    calls.add('readCardMasteryState($cardId)');
    _maybeThrow();
    final card = _cards.firstWhere((c) => c.id == cardId);
    return CardMasteryState(
      masteryLevel: card.masteryLevel,
      failCount: card.failCount,
      updatedAt: card.updatedAt,
    );
  }

  @override
  Future<FlashCard?> updateCardMasteryGuarded({
    required String cardId,
    required int masteryLevel,
    required int failCount,
    required DateTime expectedUpdatedAt,
  }) async {
    calls.add('updateCardMasteryGuarded(id=$cardId, mastery=$masteryLevel, '
        'fail=$failCount)');
    _maybeThrow();
    await guardGate?.future;
    final i = _cards.indexWhere((c) => c.id == cardId);
    final existing = _cards[i];

    if (failNextGuard) {
      failNextGuard = false;
      // Simulate a concurrent write: move updated_at so this and any later
      // guard with the old timestamp miss.
      _cards[i] = _rebuild(existing, updatedAt: _now);
      return null;
    }
    if (existing.updatedAt != expectedUpdatedAt) return null;

    final updated = _rebuild(
      existing,
      masteryLevel: masteryLevel,
      failCount: failCount,
      updatedAt: _now,
    );
    _cards[i] = updated;
    return updated;
  }

  @override
  Future<void> reorderDecks(List<String> orderedIds) async {
    calls.add('reorderDecks([${orderedIds.join(', ')}])');
    _maybeThrow();
    // Stamp each named deck's position to its new index and re-sort so a
    // follow-up fetchDecks reflects the manual order.
    final index = {for (final (i, id) in orderedIds.indexed) id: i};
    for (var i = 0; i < _decks.length; i++) {
      final pos = index[_decks[i].id];
      if (pos != null) _decks[i] = _withPosition(_decks[i], pos);
    }
    _decks.sort((a, b) => a.position.compareTo(b.position));
  }

  DeckSummary _withPosition(DeckSummary d, int position) => DeckSummary(
        id: d.id,
        name: d.name,
        courseId: d.courseId,
        lastStudiedAt: d.lastStudiedAt,
        totalCards: d.totalCards,
        dueCards: d.dueCards,
        masteryPercent: d.masteryPercent,
        masteryLevelSum: d.masteryLevelSum,
        position: position,
      );

  @override
  Future<void> markDeckStudied(String deckId) async {
    calls.add('markDeckStudied($deckId)');
    _maybeThrow();
    final i = _decks.indexWhere((d) => d.id == deckId);
    if (i != -1) {
      final d = _decks[i];
      _decks[i] = DeckSummary(
        id: d.id,
        name: d.name,
        lastStudiedAt: _now,
        totalCards: d.totalCards,
        dueCards: d.dueCards,
        masteryPercent: d.masteryPercent,
      );
    }
  }

  FlashCard _rebuild(
    FlashCard c, {
    int? masteryLevel,
    int? failCount,
    DateTime? updatedAt,
  }) =>
      FlashCard(
        id: c.id,
        deckId: c.deckId,
        front: c.front,
        back: c.back,
        keywords: c.keywords,
        isConcept: c.isConcept,
        masteryLevel: masteryLevel ?? c.masteryLevel,
        failCount: failCount ?? c.failCount,
        createdAt: c.createdAt,
        updatedAt: updatedAt ?? c.updatedAt,
      );
}
