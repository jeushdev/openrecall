import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/study/application/session_controller.dart';
import 'package:open_recall/features/study/domain/study_session.dart';
import 'package:open_recall/features/study/presentation/study_session_screen.dart';
import 'package:open_recall/features/study/presentation/widgets/feynman_card_view.dart';
import 'package:open_recall/features/study/presentation/widgets/feynman_reference_dialog.dart';
import 'package:open_recall/features/study/presentation/widgets/rating_row.dart';
import 'package:open_recall/features/study/presentation/widgets/session_summary_view.dart';
import 'package:open_recall/theme/app_theme.dart';

import '../../support/fake_deck_repository.dart';
import '../../support/fake_study_repository.dart';

FlashCard _multiLineCard(String id) => FlashCard(
  id: id,
  deckId: 'deck-1',
  front: 'Branches of government',
  back: 'Legislative\nExecutive\nJudicial',
  keywords: const [],
  isConcept: true,
  masteryLevel: 0,
  failCount: 0,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Widget _host({
  required FakeDeckRepository decks,
  required FakeStudyRepository study,
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
              scope: cardScopeFromDb(
                state.uri.queryParameters['scope'] ?? 'due',
              ),
            ),
          ),
        ],
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
}) async {
  await tester.pumpWidget(_host(decks: decks, study: study));
  GoRouter.of(tester.element(find.text('Home')))
      .go('/home/study/deck-1?scope=due');
  await tester.pumpAndSettle();
}

/// Picks Feynman from the mode picker and the given timer preset, landing on
/// the first card in the Pre-Ready state.
Future<void> _startFeynman(WidgetTester tester, {int preset = 30}) async {
  await tester.tap(find.text('Feynman Synthesis'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('${preset}s'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('picking Feynman shows the timer preset picker, not a card yet', (
    tester,
  ) async {
    await _open(
      tester,
      decks: FakeDeckRepository(cards: [_multiLineCard('a')]),
      study: FakeStudyRepository(),
    );

    expect(find.text('Feynman Synthesis'), findsOneWidget);
    await tester.tap(find.text('Feynman Synthesis'));
    await tester.pumpAndSettle();

    expect(find.text('How long for each card?'), findsOneWidget);
    for (final p in const ['30s', '60s', '90s', '120s']) {
      expect(find.text(p), findsOneWidget);
    }
    expect(find.byType(FeynmanCardView), findsNothing);
  });

  testWidgets(
    'after a preset: prompt + Ready, no Finished button, no rating row',
    (tester) async {
      await _open(
        tester,
        decks: FakeDeckRepository(cards: [_multiLineCard('a')]),
        study: FakeStudyRepository(),
      );
      await _startFeynman(tester);

      expect(find.byType(FeynmanCardView), findsOneWidget);
      expect(find.text('Branches of government'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Ready'), findsOneWidget);
      expect(find.text('Finished'), findsNothing);
      expect(find.byType(RatingRow), findsNothing);
    },
  );

  testWidgets('tapping Ready starts the countdown and shows Finished', (
    tester,
  ) async {
    await _open(
      tester,
      decks: FakeDeckRepository(cards: [_multiLineCard('a')]),
      study: FakeStudyRepository(),
    );
    await _startFeynman(tester);

    await tester.tap(find.text('Ready'));
    await tester.pump();

    expect(find.text('Finished'), findsOneWidget);
    expect(find.byType(RatingRow), findsNothing);

    // Drain the timer so the test leaves nothing pending.
    await tester.tap(find.text('Finished'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'tapping Finished reveals the rating row and the reference chip',
    (tester) async {
      await _open(
        tester,
        decks: FakeDeckRepository(cards: [_multiLineCard('a')]),
        study: FakeStudyRepository(),
      );
      await _startFeynman(tester);
      await tester.tap(find.text('Ready'));
      await tester.pump();
      await tester.tap(find.text('Finished'));
      await tester.pumpAndSettle();

      expect(find.byType(RatingRow), findsOneWidget);
      expect(find.text('Reveal reference'), findsOneWidget);
    },
  );

  testWidgets(
    'the reference modal opens over a scrim and dismisses on outside tap',
    (tester) async {
      await _open(
        tester,
        decks: FakeDeckRepository(cards: [_multiLineCard('a')]),
        study: FakeStudyRepository(),
      );
      await _startFeynman(tester);
      await tester.tap(find.text('Ready'));
      await tester.pump();
      await tester.tap(find.text('Finished'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reveal reference'));
      await tester.pumpAndSettle();
      expect(find.byType(FeynmanReferenceDialog), findsOneWidget);
      expect(find.text('Legislative'), findsOneWidget);

      // Tap the scrim, well away from the card.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(FeynmanReferenceDialog), findsNothing);
    },
  );

  testWidgets('rating is submittable without ever opening the reference', (
    tester,
  ) async {
    await _open(
      tester,
      decks: FakeDeckRepository(cards: [_multiLineCard('a')]),
      study: FakeStudyRepository(),
    );
    await _startFeynman(tester);
    await tester.tap(find.text('Ready'));
    await tester.pump();
    await tester.tap(find.text('Finished'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mastered'));
    await tester.pumpAndSettle();
    expect(find.byType(SessionSummaryView), findsOneWidget);
  });

  testWidgets('the countdown reaching zero auto-advances to the rating state', (
    tester,
  ) async {
    await _open(
      tester,
      decks: FakeDeckRepository(cards: [_multiLineCard('a')]),
      study: FakeStudyRepository(),
    );
    await _startFeynman(tester, preset: 30);

    await tester.tap(find.text('Ready'));
    await tester.pump();
    expect(find.byType(RatingRow), findsNothing);

    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();

    expect(find.text('Finished'), findsNothing);
    expect(find.byType(RatingRow), findsOneWidget);
    expect(find.text('Reveal reference'), findsOneWidget);
  });
}
