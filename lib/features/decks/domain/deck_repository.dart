import 'bulk_paste_parser.dart';
import 'card.dart';
import 'deck.dart';

/// The app's window onto the `decks` and `cards` tables.
///
/// Everything outside [SupabaseDeckRepository] talks to deck/card storage
/// through this interface — never `Supabase.instance` directly — so widget and
/// provider tests run against an in-memory fake.
///
/// Card authoring is online-only (spec §3), so those methods may await the
/// network. The "never block on the network" rule is about *study*
/// interactions — the session engine calls [updateCardMasteryGuarded] /
/// [readCardMasteryState] / [markDeckStudied] here, but only ever in the
/// background, never awaited before the next card.
abstract interface class DeckRepository {
  /// Every deck the signed-in user owns, newest first, each with the aggregate
  /// counts the Deck Library shows.
  Future<List<DeckSummary>> fetchDecks();

  /// Creates an empty deck and returns it. A non-null [courseId] assigns the
  /// deck to that course; when null, the `decks` before-insert trigger fills in
  /// the user's default course.
  Future<Deck> createDeck(String name, {String? courseId});

  /// Updates only the non-null fields of deck [id] and returns the new row.
  /// Passing [courseId] re-assigns the deck to another of the user's courses
  /// (the `decks` RLS `with check` verifies that course's ownership).
  /// `updated_at` is left to the database trigger. Online-only (ui-spec-v2 §2).
  Future<Deck> updateDeck({required String id, String? name, String? courseId});

  /// Permanently deletes deck [id]. Its cards cascade
  /// (`cards.deck_id … on delete cascade`). Online-only (ui-spec-v2 §2).
  Future<void> deleteDeck(String id);

  /// Every card in [deckId], in creation order.
  Future<List<FlashCard>> fetchCards(String deckId);

  /// Adds one card and returns it.
  Future<FlashCard> addCard({
    required String deckId,
    required String front,
    required String back,
    required List<String> keywords,
    required bool isConcept,
  });

  /// Adds every [cards] entry in a single batched insert and returns them.
  Future<List<FlashCard>> addCards(String deckId, List<ParsedCard> cards);

  /// Updates a card's content and returns the new row. `updated_at` is left to
  /// the database trigger.
  Future<FlashCard> updateCard({
    required String id,
    required String front,
    required String back,
    required List<String> keywords,
    required bool isConcept,
  });

  /// Permanently deletes a card.
  Future<void> deleteCard(String id);

  /// Sets `mastery_level = 0` for every card in [deckId], so a fully-mastered
  /// deck can be studied again. `fail_count` and `updated_at` are left alone
  /// (fail_count is lifetime; updated_at is the trigger's).
  Future<void> resetDeckMastery(String deckId);

  /// The current `mastery_level` / `fail_count` / `updated_at` for one card —
  /// used by the session engine to rebase a guarded write whose compare-and-set
  /// missed.
  Future<CardMasteryState> readCardMasteryState(String cardId);

  /// Compare-and-set on `cards`: writes [masteryLevel] and [failCount] only if
  /// the row's `updated_at` still equals [expectedUpdatedAt], and returns the
  /// new row. Returns `null` if the guard missed (the row changed underneath).
  /// `updated_at` itself is left to the database trigger.
  Future<FlashCard?> updateCardMasteryGuarded({
    required String cardId,
    required int masteryLevel,
    required int failCount,
    required DateTime expectedUpdatedAt,
  });

  /// Stamps `decks.last_studied_at = now()`. Called when a session *starts*
  /// (spec §2/§4), not when it completes.
  Future<void> markDeckStudied(String deckId);
}
