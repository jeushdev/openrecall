import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_recall/features/courses/application/course_providers.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/decks/presentation/decks_tab_screen.dart';
import 'package:open_recall/features/stats/application/stats_providers.dart';
import 'package:open_recall/theme/app_theme.dart';

import '../../support/fake_course_repository.dart';
import '../../support/fake_deck_repository.dart';
import '../../support/fake_stats_repository.dart';

DeckSummary _deck(
  String id, {
  String? name,
  String? courseId,
  int dueCards = 0,
}) =>
    DeckSummary(
      id: id,
      name: name ?? id,
      courseId: courseId,
      lastStudiedAt: null,
      totalCards: dueCards,
      dueCards: dueCards,
      masteryPercent: 0,
    );

/// Records the location the router last resolved to.
class _Recorder {
  String? location;
}

Widget _host(
  _Recorder recorder, {
  required FakeDeckRepository decks,
  FakeCourseRepository? courses,
  FakeStatsRepository? stats,
}) {
  final router = GoRouter(
    initialLocation: '/decks',
    routes: [
      GoRoute(
        path: '/decks',
        builder: (context, state) => const DecksTabScreen(),
      ),
      GoRoute(
        path: '/study/:deckId',
        name: 'study-session',
        builder: (context, state) {
          recorder.location = state.uri.toString();
          return const Scaffold(body: Text('study stub'));
        },
      ),
      GoRoute(
        path: '/deck-creator',
        name: 'deck-creator',
        builder: (context, state) {
          recorder.location = state.uri.toString();
          return const Scaffold(body: Text('creator stub'));
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      deckRepositoryProvider.overrideWithValue(decks),
      courseRepositoryProvider
          .overrideWithValue(courses ?? FakeCourseRepository()),
      statsRepositoryProvider.overrideWithValue(stats ?? FakeStatsRepository()),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

void main() {
  testWidgets('renders a tile per deck and taps route to /study/:deckId',
      (tester) async {
    final recorder = _Recorder();
    await tester.pumpWidget(_host(
      recorder,
      decks: FakeDeckRepository(decks: [
        _deck('deck-1', name: 'Cell structure', dueCards: 4),
        _deck('deck-2', name: 'Photosynthesis'),
      ]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Cell structure'), findsOneWidget);
    expect(find.text('Photosynthesis'), findsOneWidget);
    expect(find.text('4 due'), findsOneWidget);
    expect(find.text('up to date'), findsOneWidget);

    await tester.tap(find.text('Cell structure'));
    await tester.pumpAndSettle();

    expect(recorder.location, '/study/deck-1?scope=due');
  });

  testWidgets('the All segment carries scope=all and shows the cleared count',
      (tester) async {
    final recorder = _Recorder();
    await tester.pumpWidget(_host(
      recorder,
      decks: FakeDeckRepository(decks: [_deck('deck-1', name: 'Cell structure')]),
      stats: FakeStatsRepository(runThroughs: {'deck-1': 3}),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.text('×3 cleared'), findsOneWidget);

    await tester.tap(find.text('Cell structure'));
    await tester.pumpAndSettle();

    expect(recorder.location, '/study/deck-1?scope=all');
  });

  testWidgets('the trailing Create tile routes to /deck-creator', (tester) async {
    final recorder = _Recorder();
    await tester.pumpWidget(_host(
      recorder,
      decks: FakeDeckRepository(decks: [_deck('deck-1')]),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(recorder.location, '/deck-creator');
  });

  testWidgets('a deck-list failure shows an error with Retry', (tester) async {
    final recorder = _Recorder();
    final decks = FakeDeckRepository()..throwOnNextCall = StateError('offline');
    await tester.pumpWidget(_host(recorder, decks: decks));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your decks."), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    // Second fetch (throw already consumed) succeeds → error state clears.
    expect(find.text("Couldn't load your decks."), findsNothing);
  });
}
