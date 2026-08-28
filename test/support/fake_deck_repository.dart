import 'package:open_recall/features/decks/domain/bulk_paste_parser.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/decks/domain/deck_repository.dart';

/// In-memory [DeckRepository] for provider and widget tests.
///
/// Records every mutating call, holds decks and cards in plain lists, and can
/// be armed to throw on the next call.
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

  int _idSeq = 0;
  String _nextId(String prefix) => '$prefix-${++_idSeq}';

  void _maybeThrow() {
    final error = throwOnNextCall;
    if (error != null) {
      throwOnNextCall = null;
      throw error;
    }
  }

  DateTime get _now => DateTime.utc(2026, 1, 1);

  FlashCard _card({
    required String deckId,
    required String front,
    required String back,
    String? keyword,
  }) =>
      FlashCard(
        id: _nextId('card'),
        deckId: deckId,
        front: front,
        back: back,
        keyword: keyword,
        masteryLevel: 0,
        failCount: 0,
        createdAt: _now,
        updatedAt: _now,
      );

  @override
  Future<List<DeckSummary>> fetchDecks() async {
    calls.add('fetchDecks()');
    _maybeThrow();
    return List.unmodifiable(_decks);
  }

  @override
  Future<Deck> createDeck(String name) async {
    calls.add('createDeck($name)');
    _maybeThrow();
    final deck = Deck(
      id: _nextId('deck'),
      name: name,
      lastStudiedAt: null,
      createdAt: _now,
      updatedAt: _now,
    );
    _decks.insert(
      0,
      DeckSummary(
        id: deck.id,
        name: deck.name,
        lastStudiedAt: null,
        totalCards: 0,
        dueCards: 0,
        masteryPercent: 0,
      ),
    );
    return deck;
  }

  @override
  Future<List<FlashCard>> fetchCards(String deckId) async {
    calls.add('fetchCards($deckId)');
    _maybeThrow();
    return _cards.where((c) => c.deckId == deckId).toList();
  }

  @override
  Future<FlashCard> addCard({
    required String deckId,
    required String front,
    required String back,
    String? keyword,
  }) async {
    calls.add('addCard(deck=$deckId, front=$front, back=$back, keyword=$keyword)');
    _maybeThrow();
    final card = _card(deckId: deckId, front: front, back: back, keyword: keyword);
    _cards.add(card);
    return card;
  }

  @override
  Future<List<FlashCard>> addCards(String deckId, List<ParsedCard> cards) async {
    calls.add('addCards($deckId, ${cards.length})');
    _maybeThrow();
    final added = [
      for (final c in cards)
        _card(deckId: deckId, front: c.front, back: c.back, keyword: c.keyword),
    ];
    _cards.addAll(added);
    return added;
  }

  @override
  Future<FlashCard> updateCard({
    required String id,
    required String front,
    required String back,
    String? keyword,
  }) async {
    calls.add('updateCard(id=$id, front=$front, back=$back, keyword=$keyword)');
    _maybeThrow();
    final i = _cards.indexWhere((c) => c.id == id);
    final existing = _cards[i];
    final updated = FlashCard(
      id: existing.id,
      deckId: existing.deckId,
      front: front,
      back: back,
      keyword: keyword,
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
}
