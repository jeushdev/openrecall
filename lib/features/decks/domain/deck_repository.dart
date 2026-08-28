import 'bulk_paste_parser.dart';
import 'card.dart';
import 'deck.dart';

/// The app's window onto the `decks` and `cards` tables.
///
/// Everything outside [SupabaseDeckRepository] talks to deck/card storage
/// through this interface — never `Supabase.instance` directly — so widget and
/// provider tests run against an in-memory fake.
///
/// Card authoring is online-only (spec §3), so these methods may await the
/// network. The "never block on the network" rule is about *study*
/// interactions, which this milestone does not touch.
abstract interface class DeckRepository {
  /// Every deck the signed-in user owns, newest first, each with the aggregate
  /// counts the Deck Library shows.
  Future<List<DeckSummary>> fetchDecks();

  /// Creates an empty deck and returns it.
  Future<Deck> createDeck(String name);

  /// Every card in [deckId], in creation order.
  Future<List<FlashCard>> fetchCards(String deckId);

  /// Adds one card and returns it.
  Future<FlashCard> addCard({
    required String deckId,
    required String front,
    required String back,
    String? keyword,
  });

  /// Adds every [cards] entry in a single batched insert and returns them.
  Future<List<FlashCard>> addCards(String deckId, List<ParsedCard> cards);

  /// Updates a card's content and returns the new row. `updated_at` is left to
  /// the database trigger.
  Future<FlashCard> updateCard({
    required String id,
    required String front,
    required String back,
    String? keyword,
  });

  /// Permanently deletes a card.
  Future<void> deleteCard(String id);
}
