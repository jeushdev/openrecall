import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/connectivity/connectivity_service.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/application/offline_providers.dart';
import 'package:open_recall/features/decks/data/cache_first_deck_repository.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/presentation/deck_overview_screen.dart';

import '../../support/fake_deck_repository.dart';
import '../../support/responsive_test_harness.dart';

FlashCard _card({
  String id = 'card-1',
  String front = 'Capital of France',
  String back = 'Paris',
  List<String> keywords = const [],
  bool isConcept = false,
  int mastery = 0,
  int fails = 0,
}) => FlashCard(
  id: id,
  deckId: 'deck-1',
  front: front,
  back: back,
  keywords: keywords,
  isConcept: isConcept,
  masteryLevel: mastery,
  failCount: fails,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Widget _host(FakeDeckRepository fake, {double textScale = 1}) => ProviderScope(
  overrides: [deckRepositoryProvider.overrideWithValue(fake)],
  child: MaterialApp(
    home: withTextScale(
      textScale: textScale,
      child: const DeckOverviewScreen(deckId: 'deck-1', deckName: 'Biology'),
    ),
  ),
);

Widget _offlineHost(
  FakeDeckRepository fake, {
  required Set<String> pinned,
  required bool online,
}) => ProviderScope(
  overrides: [
    deckRepositoryProvider.overrideWithValue(fake),
    offlineDeckIdsProvider.overrideWith((ref) async => pinned),
    onlineStatusProvider.overrideWith((ref) => Stream.value(online)),
  ],
  child: const MaterialApp(
    home: DeckOverviewScreen(deckId: 'deck-1', deckName: 'Biology'),
  ),
);

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

bool _enabled(WidgetTester tester, String label) {
  final button = tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, label),
  );
  return button.onPressed != null;
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('empty deck shows the no-cards prompt, not the stats', (
    tester,
  ) async {
    await tester.pumpWidget(_host(FakeDeckRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('no cards yet'), findsOneWidget);
    expect(find.text('Study modes'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Add cards'), findsOneWidget);
  });

  testWidgets('renders deck stats from real card data', (tester) async {
    await tester.pumpWidget(
      _host(
        FakeDeckRepository(
          cards: [
            _card(id: 'a', keywords: ['Paris'], mastery: 4),
            _card(id: 'b', back: 'one\ntwo'),
            _card(id: 'c'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('3 cards'), findsOneWidget);
    expect(find.textContaining('2 due'), findsOneWidget);
    expect(find.textContaining('1 with a keyword'), findsOneWidget);
    expect(find.textContaining('1 multi-line'), findsOneWidget);
  });

  testWidgets('Flip is always enabled; Cloze/Feynman gate on card content', (
    tester,
  ) async {
    await tester.pumpWidget(_host(FakeDeckRepository(cards: [_card()])));
    await tester.pumpAndSettle();

    expect(_enabled(tester, 'Flip & Rate'), isTrue);
    expect(_enabled(tester, 'Cloze Type-in'), isFalse);
    expect(_enabled(tester, 'Feynman Synthesis'), isFalse);
    expect(find.text('No cards support this yet'), findsNWidgets(2));
  });

  testWidgets('a keyword card enables Cloze', (tester) async {
    await tester.pumpWidget(
      _host(
        FakeDeckRepository(
          cards: [
            _card(keywords: ['Paris']),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_enabled(tester, 'Cloze Type-in'), isTrue);
    expect(_enabled(tester, 'Feynman Synthesis'), isFalse);
  });

  testWidgets('a concept card enables Feynman', (tester) async {
    await tester.pumpWidget(
      _host(
        FakeDeckRepository(
          cards: [_card(back: 'point one\npoint two', isConcept: true)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_enabled(tester, 'Feynman Synthesis'), isTrue);
    expect(_enabled(tester, 'Cloze Type-in'), isFalse);
  });

  testWidgets('the capped toggle reveals the fixed presets', (tester) async {
    await tester.pumpWidget(_host(FakeDeckRepository(cards: [_card()])));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, '10'), findsNothing);

    await tester.tap(find.text('Capped'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, '10'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '20'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '30'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
  });

  testWidgets('all-caught-up banner shows only when nothing is due', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FakeDeckRepository(
          cards: [
            _card(id: 'a', mastery: 4),
            _card(id: 'b', mastery: 4),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('all caught up'), findsOneWidget);
  });

  testWidgets('no caught-up banner while cards are still due', (tester) async {
    await tester.pumpWidget(_host(FakeDeckRepository(cards: [_card()])));
    await tester.pumpAndSettle();

    expect(find.textContaining('all caught up'), findsNothing);
  });

  testWidgets('the deck overview no longer renders a troublemaker section', (
    tester,
  ) async {
    _useTallSurface(tester);
    await tester.pumpWidget(
      _host(
        FakeDeckRepository(
          cards: [
            _card(id: 'a', front: 'Sticky one', fails: 4),
            _card(id: 'b', front: 'Easy one'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Troublemaker cards'), findsNothing);
  });

  testWidgets('pinned + online: the menu offers "Update offline copy"', (
    tester,
  ) async {
    await tester.pumpWidget(
      _offlineHost(
        FakeDeckRepository(cards: [_card()]),
        pinned: const {'deck-1'},
        online: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Update offline copy'), findsOneWidget);
  });

  testWidgets('not pinned: no "Update offline copy" item', (tester) async {
    await tester.pumpWidget(
      _offlineHost(
        FakeDeckRepository(cards: [_card()]),
        pinned: const {},
        online: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Update offline copy'), findsNothing);
  });

  testWidgets('pinned but offline: no "Update offline copy" item', (
    tester,
  ) async {
    await tester.pumpWidget(
      _offlineHost(
        FakeDeckRepository(cards: [_card()]),
        pinned: const {'deck-1'},
        online: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Update offline copy'), findsNothing);
  });

  testWidgets('a deck with no offline copy shows the unavailable state, not '
      'the generic error', (tester) async {
    await tester.pumpWidget(_host(_AlwaysUnavailableRepo()));
    await tester.pumpAndSettle();

    expect(find.textContaining("isn't available offline"), findsOneWidget);
    expect(find.text("Couldn't load this deck."), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsNothing);
  });

  final responsiveCases = <({Size size, double scale})>[
    for (final size in responsiveViewports) (size: size, scale: 1),
    (size: const Size(320, 568), scale: 2),
    (size: const Size(360, 640), scale: 2),
    (size: const Size(412, 915), scale: 2),
  ];

  for (final testCase in responsiveCases) {
    testWidgets('overview modes and final action remain reachable at '
        '${testCase.size.width.toInt()}x${testCase.size.height.toInt()} '
        'and ${testCase.scale}x text', (tester) async {
      configureResponsiveView(tester, viewport: testCase.size);
      await tester.pumpWidget(
        _host(
          FakeDeckRepository(
            cards: [
              _card(
                front: 'Paris is the capital of France',
                back: 'One point\nA second point',
                keywords: const ['Paris'],
                isConcept: true,
              ),
            ],
          ),
          textScale: testCase.scale,
        ),
      );
      await tester.pumpAndSettle();

      for (final label in const [
        'Flip & Rate',
        'Cloze Type-in',
        'Feynman Synthesis',
      ]) {
        final button = find.widgetWithText(FilledButton, label);
        await tester.scrollUntilVisible(
          button,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        expectTextIsComplete(tester, find.text(label));
        expect(button.hitTestable(), findsOneWidget);
      }

      final add = find.widgetWithText(OutlinedButton, 'Add cards');
      await tester.scrollUntilVisible(
        add,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(add.hitTestable(), findsOneWidget);
      expectTextIsComplete(tester, find.text('Add cards'));
      expect(tester.takeException(), isNull);
    });
  }
}

/// Always fails `fetchCards` with the offline-unavailable exception — the state
/// a never-downloaded deck's Overview hits with no connection.
class _AlwaysUnavailableRepo extends FakeDeckRepository {
  @override
  Future<List<FlashCard>> fetchCards(String deckId) async =>
      throw const DeckUnavailableOfflineException('deck-1');
}
