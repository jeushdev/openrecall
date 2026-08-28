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
        .select('id, name, last_studied_at, created_at, updated_at, '
            'cards(mastery_level)')
        .order('created_at', ascending: false);
    return rows.map(DeckSummary.fromJson).toList();
  }

  @override
  Future<Deck> createDeck(String name) async {
    final row = await _client
        .from('decks')
        .insert({'user_id': _userId, 'name': name})
        .select()
        .single();
    return Deck.fromJson(row);
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
