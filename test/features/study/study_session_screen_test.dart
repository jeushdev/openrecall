import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/study/application/session_controller.dart';
import 'package:open_recall/features/study/domain/study_session.dart';
import 'package:open_recall/features/study/presentation/study_session_screen.dart';
import 'package:open_recall/features/study/presentation/widgets/cloze_reveal_card.dart';
import 'package:open_recall/features/study/presentation/widgets/flip_card.dart';
import 'package:open_recall/features/study/presentation/widgets/session_summary_view.dart';
import 'package:open_recall/routing/app_routes.dart';
import 'package:open_recall/theme/app_theme.dart';

import '../../support/fake_deck_repository.dart';
import '../../support/fake_study_repository.dart';

FlashCard _card(
  String id, {
  int mastery = 0,
  String? keyword,
  String? front,
  String? back,
}) =>
    FlashCard(
      id: id,
      deckId: 'deck-1',
      front: front ?? 'front-$id',
      back: back ?? 'back-$id',
      keyword: keyword,
      masteryLevel: mastery,
      failCount: 0,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

Widget _host({
  required FakeDeckRepository decks,
  required FakeStudyRepository study,
  String scope = 'due',
}) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Home')),
        routes: [
          GoRoute(
            path: 'study/:deckId',
            builder: (_, state) => StudySessionScreen(
              deckId: state.pathParameters['deckId']!,
              scope: cardScopeFromDb(state.uri.queryParameters['scope'] ?? 'due'),
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.importCardsPath,
        name: AppRoutes.importCardsName,
        builder: (_, state) => Scaffold(
          body: Text('import ${state.pathParameters['deckId']}'),
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      deckRepositoryProvider.overrideWithValue(decks),
      studyRepositoryProvider.overrideWithValue(study),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

Future<void> _open(
  WidgetTester tester, {
  required FakeDeckRepository decks,
  required FakeStudyRepository study,
  String scope = 'due',
}) async {
  await tester.pumpWidget(_host(decks: decks, study: study, scope: scope));
  GoRouter.of(tester.element(find.text('Home')))
      .go('/home/study/deck-1?scope=$scope');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a single-mode deck skips the picker and opens Flip',
      (tester) async {
    await _open(
      tester,
      decks: FakeDeckRepository(cards: [_card('a'), _card('b')]),
      study: FakeStudyRepository(),
    );

    expect(find.text('How do you want to study this deck?'), findsNothing);
    expect(find.text('front-a'), findsOneWidget);
  });

  testWidgets('tapping the card flips it to the back', (tester) async {
    await _open(
      tester,
      decks: FakeDeckRepository(cards: [_card('a')]),
      study: FakeStudyRepository(),
    );

    await tester.tap(find.byType(FlipCard));
    await tester.pumpAndSettle();
    expect(find.text('back-a'), findsOneWidget);
  });

  testWidgets('the rating row is inert until the card is flipped',
      (tester) async {
    await _open(
      tester,
      decks: FakeDeckRepository(cards: [_card('a'), _card('b')]),
      study: FakeStudyRepository(),
    );

    // Before flipping, "Mastered" does nothing — still on card a.
    await tester.tap(find.text('Mastered'));
    await tester.pumpAndSettle();
    expect(find.text('front-a'), findsOneWidget);

    await tester.tap(find.byType(FlipCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mastered'));
    await tester.pumpAndSettle();
    expect(find.text('front-b'), findsOneWidget);
  });

  testWidgets('swipe-right on a flipped card masters it', (tester) async {
    await _open(
      tester,
      decks: FakeDeckRepository(cards: [_card('a'), _card('b')]),
      study: FakeStudyRepository(),
    );

    await tester.tap(find.byType(FlipCard));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(FlipCard), const Offset(500, 0), 1200);
    await tester.pumpAndSettle();

    expect(find.text('front-b'), findsOneWidget);
  });

  testWidgets('a deck supporting several modes shows the picker', (tester) async {
    await _open(
      tester,
      decks: FakeDeckRepository(cards: [
        _card('a', front: 'Paris is the capital', keyword: 'Paris'),
      ]),
      study: FakeStudyRepository(),
    );

    expect(find.text('How do you want to study this deck?'), findsOneWidget);
    expect(find.text('Flip & Rate'), findsOneWidget);
    expect(find.text('Cloze Type-in'), findsOneWidget);

    await tester.tap(find.text('Flip & Rate'));
    await tester.pumpAndSettle();
    expect(find.text('Paris is the capital'), findsOneWidget);
  });

  testWidgets('Cloze gates the rating row on revealing every blank',
      (tester) async {
    await _open(
      tester,
      decks: FakeDeckRepository(cards: [
        _card('a',
            front: 'Paris is the capital', keyword: 'Paris', back: 'of France'),
        _card('b'),
      ]),
      study: FakeStudyRepository(),
    );

    await tester.tap(find.text('Cloze Type-in'));
    await tester.pumpAndSettle();
    expect(find.byType(ClozeRevealCard), findsOneWidget);

    // Rating is inert — the blank is still hidden.
    await tester.tap(find.text('Mastered'));
    await tester.pumpAndSettle();
    expect(find.byType(SessionSummaryView), findsNothing);

    // Reveal the blank, then rate.
    await tester.tap(find.byIcon(Icons.touch_app_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mastered'));
    await tester.pumpAndSettle();
    expect(find.byType(SessionSummaryView), findsOneWidget);
  });

  testWidgets('List reveals items in any order and gates the rating row',
      (tester) async {
    await _open(
      tester,
      decks: FakeDeckRepository(cards: [
        _card('a', front: 'Primary colours', back: 'red\ngreen\nblue'),
      ]),
      study: FakeStudyRepository(),
    );

    await tester.tap(find.text('List Unmask'));
    await tester.pumpAndSettle();

    expect(find.text('Tap to reveal'), findsNWidgets(3));

    // Reveal out of order (last, then first, then middle).
    await tester.tap(find.text('Tap to reveal').at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tap to reveal').at(0));
    await tester.pumpAndSettle();

    // One still hidden — rating inert.
    await tester.tap(find.text('Mastered'));
    await tester.pumpAndSettle();
    expect(find.byType(SessionSummaryView), findsNothing);

    await tester.tap(find.text('Tap to reveal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mastered'));
    await tester.pumpAndSettle();
    expect(find.byType(SessionSummaryView), findsOneWidget);
  });

  testWidgets('completing the session shows the Summary, then Done pops back',
      (tester) async {
    await _open(
      tester,
      decks: FakeDeckRepository(cards: [_card('a')]),
      study: FakeStudyRepository(),
    );

    await tester.tap(find.byType(FlipCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mastered'));
    await tester.pumpAndSettle();

    expect(find.text('This session'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Done'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.byType(StudySessionScreen), findsNothing);
  });

  testWidgets('the close button leaves the session active and pops',
      (tester) async {
    final study = FakeStudyRepository();
    await _open(
      tester,
      decks: FakeDeckRepository(cards: [_card('a')]),
      study: study,
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(study.sessions.single.status.name, 'active');
  });

  testWidgets('an all-mastered deck on the due scope shows nothing to study',
      (tester) async {
    await _open(
      tester,
      decks: FakeDeckRepository(cards: [_card('a', mastery: 4)]),
      study: FakeStudyRepository(),
    );

    expect(find.textContaining('Nothing to study'), findsOneWidget);
  });

  testWidgets('a deck with no cards shows the empty state, not a spinner',
      (tester) async {
    await _open(
      tester,
      decks: FakeDeckRepository(cards: const []),
      study: FakeStudyRepository(),
    );

    expect(find.text('Nothing to study in this deck yet.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('the no-cards empty state opens the import screen for the deck',
      (tester) async {
    await _open(
      tester,
      decks: FakeDeckRepository(cards: const []),
      study: FakeStudyRepository(),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Add cards'));
    await tester.pumpAndSettle();

    expect(find.text('import deck-1'), findsOneWidget);
  });

  testWidgets('the all-mastered dead-end offers to import cards', (tester) async {
    await _open(
      tester,
      decks: FakeDeckRepository(cards: [_card('a', mastery: 4)]),
      study: FakeStudyRepository(),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Add cards'));
    await tester.pumpAndSettle();

    expect(find.text('import deck-1'), findsOneWidget);
  });
}
