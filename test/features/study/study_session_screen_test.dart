import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/study/application/session_controller.dart';
import 'package:open_recall/features/study/domain/session_length.dart';
import 'package:open_recall/features/study/presentation/study_session_args.dart';
import 'package:open_recall/features/study/presentation/study_session_screen.dart';

import '../../support/fake_deck_repository.dart';
import '../../support/fake_study_repository.dart';

FlashCard _card(String id, {int mastery = 0}) => FlashCard(
      id: id,
      deckId: 'deck-1',
      front: 'front-$id',
      back: 'back-$id',
      keyword: null,
      masteryLevel: mastery,
      failCount: 0,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

StudySessionArgs _args({
  SessionLengthMode lengthMode = SessionLengthMode.untilMastered,
  int? cap,
}) =>
    StudySessionArgs(
      deckId: 'deck-1',
      deckName: 'Biology',
      mode: StudyMode.flip,
      lengthMode: lengthMode,
      cap: cap,
    );

Widget _host({
  required FakeDeckRepository decks,
  required FakeStudyRepository study,
}) {
  final router = GoRouter(
    initialLocation: '/overview',
    routes: [
      GoRoute(
        path: '/overview',
        builder: (_, _) => const Scaffold(body: Text('Deck Overview')),
        routes: [
          GoRoute(
            path: 'study',
            builder: (_, state) => StudySessionScreen(
              args: state.extra as StudySessionArgs?,
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
    child: MaterialApp.router(routerConfig: router),
  );
}

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _openSession(
  WidgetTester tester, {
  required FakeDeckRepository decks,
  required FakeStudyRepository study,
  StudySessionArgs? args,
}) async {
  await tester.pumpWidget(_host(decks: decks, study: study));
  final context = tester.element(find.text('Deck Overview'));
  GoRouter.of(context).go('/overview/study', extra: args ?? _args());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the first card front, then flips to the back',
      (tester) async {
    await _openSession(
      tester,
      decks: FakeDeckRepository(cards: [_card('a'), _card('b')]),
      study: FakeStudyRepository(),
    );

    expect(find.text('front-a'), findsOneWidget);
    expect(find.text('Biology'), findsOneWidget);

    await tester.tap(find.text('front-a'));
    await tester.pumpAndSettle();
    expect(find.text('back-a'), findsOneWidget);
  });

  testWidgets('rating buttons are disabled until the card is flipped',
      (tester) async {
    await _openSession(
      tester,
      decks: FakeDeckRepository(cards: [_card('a')]),
      study: FakeStudyRepository(),
    );

    FilledButton mastered() => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Mastered'),
        );
    expect(mastered().onPressed, isNull);

    await tester.tap(find.text('front-a'));
    await tester.pumpAndSettle();
    expect(mastered().onPressed, isNotNull);
  });

  testWidgets('mastering a card advances progress', (tester) async {
    await _openSession(
      tester,
      decks: FakeDeckRepository(cards: [_card('a'), _card('b')]),
      study: FakeStudyRepository(),
    );

    expect(find.text('0 / 2 mastered'), findsOneWidget);

    await tester.tap(find.text('front-a'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Mastered'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2 mastered'), findsOneWidget);
    expect(find.text('front-b'), findsOneWidget);
  });

  testWidgets('completing every card shows the Session Summary, then Done '
      'returns to the Deck Overview', (tester) async {
    _useTallSurface(tester);
    await _openSession(
      tester,
      decks: FakeDeckRepository(cards: [_card('a')]),
      study: FakeStudyRepository(),
    );

    await tester.tap(find.text('front-a'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Mastered'));
    await tester.pumpAndSettle();

    expect(find.text('This session'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Drill parked cards now'),
        findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'Done'));
    await tester.pumpAndSettle();

    expect(find.text('Deck Overview'), findsOneWidget);
    expect(find.byType(StudySessionScreen), findsNothing);
  });

  testWidgets('parking the last card shows the Summary with a drill button',
      (tester) async {
    _useTallSurface(tester);
    await _openSession(
      tester,
      decks: FakeDeckRepository(cards: [_card('a')]),
      study: FakeStudyRepository(),
    );

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('front-a'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Forgotten'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Park this card?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Park it'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Drill parked cards now'),
        findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Done'));
    await tester.pumpAndSettle();

    expect(find.text('Deck Overview'), findsOneWidget);
  });

  testWidgets('declining the park keeps studying the card', (tester) async {
    await _openSession(
      tester,
      decks: FakeDeckRepository(cards: [_card('a')]),
      study: FakeStudyRepository(),
    );

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('front-a'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Forgotten'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.widgetWithText(TextButton, 'Keep going'));
    await tester.pumpAndSettle();

    expect(find.byType(StudySessionScreen), findsOneWidget);
    expect(find.text('front-a'), findsOneWidget);
  });

  testWidgets('the close button leaves the session active and pops',
      (tester) async {
    final study = FakeStudyRepository();
    await _openSession(
      tester,
      decks: FakeDeckRepository(cards: [_card('a')]),
      study: study,
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Deck Overview'), findsOneWidget);
    expect(study.sessions.single.status.name, 'active');
  });

  testWidgets('an all-mastered deck shows "nothing to study"', (tester) async {
    await _openSession(
      tester,
      decks: FakeDeckRepository(cards: [_card('a', mastery: 4)]),
      study: FakeStudyRepository(),
    );

    expect(find.textContaining('Nothing to study'), findsOneWidget);
  });

  testWidgets('a creation failure offers a retry', (tester) async {
    final decks = FakeDeckRepository(cards: [_card('a')])
      ..throwOnNextCall = Exception('boom');
    await _openSession(tester, decks: decks, study: FakeStudyRepository());

    expect(find.textContaining("Couldn't start"), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
  });
}
