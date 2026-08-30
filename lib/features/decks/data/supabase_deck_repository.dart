import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/bulk_paste_parser.dart';
import '../domain/card.dart';
import '../domain/deck.dart';
import '../domain/deck_repository.dart';

/// The only class in the decks feature that talks to Supabase Postgres
/// directly. RLS scopes every query to the signed-in user, so no `user_id`
/// filter is needed on reads.
class SupabaseDeckRepository implements DeckRepository {
  SupabaseDeckRepository(this._client);

  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<DeckSummary>> fetchDecks() async {
    final rows = await _client
        .from('decks')
        .select('id, name, course_id, last_studied_at, created_at, updated_at, '
            'cards(mastery_level)')
        .order('created_at', ascending: false);
    return rows.map(DeckSummary.fromJson).toList();
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
  Future<FlashCard> addCard({
    required String deckId,
    required String front,
    required String back,
    String? keyword,
  }) async {
    final row = await _client
        .from('cards')
        .insert(_cardValues(deckId, front, back, keyword))
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
            _cardValues(deckId, c.front, c.back, c.keyword),
        ])
        .select();
    return rows.map(FlashCard.fromJson).toList();
  }

  @override
  Future<FlashCard> updateCard({
    required String id,
    required String front,
    required String back,
    String? keyword,
  }) async {
    // updated_at is left to the database trigger (CLAUDE.md).
    final row = await _client
        .from('cards')
        .update({'front': front, 'back': back, 'keyword': keyword})
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
    String? keyword,
  ) =>
      {
        'deck_id': deckId,
        'front': front,
        'back': back,
        'keyword': keyword,
      };
}
