import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/reorder.dart';
import '../domain/bulk_paste_parser.dart';
import '../domain/card.dart';
import '../domain/deck.dart';
import '../domain/deck_repository.dart';

/// The only class in the decks feature that talks to Supabase Postgres
/// directly. RLS scopes every query to the signed-in user, so no `user_id`
/// filter is needed on reads.
class SupabaseDeckRepository
    implements DeckRepository, OfflineDownloadSource {
  SupabaseDeckRepository(this._client);

  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<DeckSummary>> fetchDecks() async {
    final rows = await _client
        .from('decks')
        .select('id, name, course_id, position, last_studied_at, created_at, '
            'updated_at, cards(mastery_level)')
        .order('position')
        .order('created_at');
    return rows.map(DeckSummary.fromJson).toList();
  }

  @override
  Future<void> reorderDecks(List<String> orderedIds) async {
    // One batched round-trip via a SECURITY INVOKER function — RLS
    // (`decks_owner`) still scopes the UPDATE, so ids the user does not own
    // simply match no row. `updated_at` is left to the database trigger.
    await _client.rpc('set_deck_positions', params: {
      'items': [
        for (final e in positionsForOrder(orderedIds).entries)
          {'id': e.key, 'position': e.value},
      ],
    });
  }

  @override
  Future<Deck> createDeck(String name, {String? courseId}) async {
    // A null course_id is left to the decks before-insert trigger, which fills
    // in the user's default course. RLS (decks_owner) validates that courseId,
    // when given, belongs to the signed-in user.
    final row = await _client
        .from('decks')
        .insert({
          'user_id': _userId,
          'name': name,
          'course_id': ?courseId,
        })
        .select()
        .single();
    return Deck.fromJson(row);
  }

  @override
  Future<Deck> updateDeck({
    required String id,
    String? name,
    String? courseId,
  }) async {
    // updated_at is left to the database trigger (CLAUDE.md). RLS (decks_owner)
    // validates a new course_id belongs to the signed-in user.
    final row = await _client
        .from('decks')
        .update({
          'name': ?name,
          'course_id': ?courseId,
        })
        .eq('id', id)
        .select()
        .single();
    return Deck.fromJson(row);
  }

  @override
  Future<void> deleteDeck(String id) async {
    // cards.deck_id is ON DELETE CASCADE, so the deck's cards go with it.
    await _client.from('decks').delete().eq('id', id);
  }

  @override
  Future<List<FlashCard>> fetchCards(String deckId) async {
    final rows = await _client
        .from('cards')
        .select()
        .eq('deck_id', deckId)
        .order('created_at');
    return rows.map(FlashCard.fromJson).toList();
  }

  @override
  Future<int> countCards(String deckId) async {
    // A count-only request (no rows returned). RLS (cards_owner_via_deck) scopes
    // it to the signed-in user's deck.
    final res = await _client
        .from('cards')
        .select('id')
        .eq('deck_id', deckId)
        .count(CountOption.exact);
    return res.count;
  }

  @override
  Future<List<FlashCard>> fetchCardsPage(
    String deckId, {
    required int offset,
    required int limit,
  }) async {
    final rows = await _client
        .from('cards')
        .select()
        .eq('deck_id', deckId)
        .order('created_at')
        .range(offset, offset + limit - 1);
    return rows.map(FlashCard.fromJson).toList();
  }

  @override
  Future<FlashCard> addCard({
    required String deckId,
    required String front,
    required String back,
    required List<String> keywords,
    required bool isConcept,
  }) async {
    final row = await _client
        .from('cards')
        .insert(_cardValues(deckId, front, back, keywords, isConcept))
        .select()
        .single();
    return FlashCard.fromJson(row);
  }

  @override
  Future<List<FlashCard>> addCards(String deckId, List<ParsedCard> cards) async {
    final rows = await _client
        .from('cards')
        .insert([
          for (final c in cards)
            _cardValues(deckId, c.front, c.back, c.keywords, c.isConcept),
        ])
        .select();
    return rows.map(FlashCard.fromJson).toList();
  }

  @override
  Future<FlashCard> updateCard({
    required String id,
    required String front,
    required String back,
    required List<String> keywords,
    required bool isConcept,
  }) async {
    // updated_at is left to the database trigger (CLAUDE.md).
    final row = await _client
        .from('cards')
        .update({
          'front': front,
          'back': back,
          'keywords': keywords,
          'is_concept': isConcept,
        })
        .eq('id', id)
        .select()
        .single();
    return FlashCard.fromJson(row);
  }

  @override
  Future<void> deleteCard(String id) async {
    await _client.from('cards').delete().eq('id', id);
  }

  @override
  Future<void> resetDeckMastery(String deckId) async {
    // RLS (cards_owner_via_deck) scopes this to the signed-in user's deck.
    // fail_count is lifetime; updated_at is left to the database trigger.
    await _client
        .from('cards')
        .update({'mastery_level': 0})
        .eq('deck_id', deckId);
  }

  @override
  Future<CardMasteryState> readCardMasteryState(String cardId) async {
    final row = await _client
        .from('cards')
        .select('mastery_level, fail_count, updated_at')
        .eq('id', cardId)
        .single();
    return CardMasteryState.fromJson(row);
  }

  @override
  Future<FlashCard?> updateCardMasteryGuarded({
    required String cardId,
    required int masteryLevel,
    required int failCount,
    required DateTime expectedUpdatedAt,
  }) async {
    // Compare-and-set: the write only lands if updated_at hasn't moved since we
    // last saw this row (Performance & Responsiveness: never a blind update).
    // updated_at itself is left to the trigger.
    final row = await _client
        .from('cards')
        .update({'mastery_level': masteryLevel, 'fail_count': failCount})
        .eq('id', cardId)
        .eq('updated_at', expectedUpdatedAt.toUtc().toIso8601String())
        .select()
        .maybeSingle();
    return row == null ? null : FlashCard.fromJson(row);
  }

  @override
  Future<void> markDeckStudied(String deckId) async {
    await _client
        .from('decks')
        .update({'last_studied_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', deckId);
  }

  Map<String, dynamic> _cardValues(
    String deckId,
    String front,
    String back,
    List<String> keywords,
    bool isConcept,
  ) =>
      {
        'deck_id': deckId,
        'front': front,
        'back': back,
        'keywords': keywords,
        'is_concept': isConcept,
      };
}
