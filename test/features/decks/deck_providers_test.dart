import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/bulk_paste_parser.dart';

import '../../support/fake_deck_repository.dart';

void main() {
  late FakeDeckRepository fake;
  late ProviderContainer container;

  setUp(() {
    fake = FakeDeckRepository();
    container = ProviderContainer(
      overrides: [deckRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
  });

  test('decksProvider reads the repository', () async {
    await container.read(decksProvider.future);
    expect(fake.calls, contains('fetchDecks()'));
  });

  test('the controller starts idle with a data state', () {
    expect(container.read(decksControllerProvider), const AsyncData<void>(null));
  });

  test('createDeck forwards the name and returns the new deck', () async {
    final deck =
        await container.read(decksControllerProvider.notifier).createDeck('Bio');

    expect(deck?.name, 'Bio');
    expect(fake.calls, contains('createDeck(Bio)'));
  });

  test('createDeck refreshes the deck list', () async {
    await container.read(decksProvider.future);
    await container.read(decksControllerProvider.notifier).createDeck('Bio');

    final decks = await container.read(decksProvider.future);
    expect(decks.map((d) => d.name), contains('Bio'));
  });

  test('addCard forwards its fields and refreshes that deck\'s cards', () async {
    await container.read(deckCardsProvider('deck-1').future);

    await container.read(decksControllerProvider.notifier).addCard(
          deckId: 'deck-1',
          front: 'Q',
          back: 'A',
          keyword: 'A',
        );

    expect(
      fake.calls,
      contains('addCard(deck=deck-1, front=Q, back=A, keyword=A)'),
    );
    final cards = await container.read(deckCardsProvider('deck-1').future);
    expect(cards.single.front, 'Q');
  });

  test('addCards inserts every parsed card in one call', () async {
    await container
        .read(decksControllerProvider.notifier)
        .addCards('deck-1', const [
      ParsedCard(lineNumber: 1, raw: 'Q1 | A1', front: 'Q1', back: 'A1'),
      ParsedCard(lineNumber: 2, raw: 'Q2 | A2', front: 'Q2', back: 'A2'),
    ]);

    expect(fake.calls, contains('addCards(deck-1, 2)'));
  });

  test('deleteCard forwards the id and refreshes the list', () async {
    final card = await container.read(decksControllerProvider.notifier).addCard(
          deckId: 'deck-1',
          front: 'Q',
          back: 'A',
        );

    await container
        .read(decksControllerProvider.notifier)
        .deleteCard(deckId: 'deck-1', id: card!.id);

    expect(fake.calls, contains('deleteCard(${card.id})'));
    final cards = await container.read(deckCardsProvider('deck-1').future);
    expect(cards, isEmpty);
  });

  test('updateDeck forwards the non-null fields and refreshes that deck',
      () async {
    final deck =
        await container.read(decksControllerProvider.notifier).createDeck('Bio');
    await container.read(deckCardsProvider(deck!.id).future);

    final updated =
        await container.read(decksControllerProvider.notifier).updateDeck(
              id: deck.id,
              name: 'Bio 101',
              courseId: 'course-9',
            );

    expect(updated?.name, 'Bio 101');
    expect(
      fake.calls,
      contains('updateDeck(id=${deck.id}, name=Bio 101, course=course-9)'),
    );
  });

  test('deleteDeck forwards the id and drops it from the list', () async {
    final deck =
        await container.read(decksControllerProvider.notifier).createDeck('Bio');
    await container.read(decksProvider.future);

    await container
        .read(decksControllerProvider.notifier)
        .deleteDeck(deck!.id);

    expect(fake.calls, contains('deleteDeck(${deck.id})'));
    final decks = await container.read(decksProvider.future);
    expect(decks.map((d) => d.id), isNot(contains(deck.id)));
  });

  test('a failed call lands as AsyncError, returns null, and clears loading',
      () async {
    fake.throwOnNextCall = Exception('boom');

    final deck =
        await container.read(decksControllerProvider.notifier).createDeck('Bio');

    expect(deck, isNull);
    final state = container.read(decksControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.isLoading, isFalse);
  });
}
