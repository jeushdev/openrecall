import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/app.dart';
import 'package:open_recall/core/connectivity/connectivity_service.dart';
import 'package:open_recall/features/auth/application/auth_providers.dart';
import 'package:open_recall/features/courses/application/course_providers.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/home/presentation/home_tab_screen.dart';
import 'package:open_recall/features/profile/application/profile_providers.dart';
import 'package:open_recall/features/settings/application/settings_providers.dart';
import 'package:open_recall/features/stats/application/stats_providers.dart';
import 'package:open_recall/features/stats/domain/active_session.dart';
import 'package:open_recall/features/study/application/session_controller.dart';
import 'package:open_recall/features/study/domain/session_length.dart';
import 'package:open_recall/features/study/domain/study_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_course_repository.dart';
import '../../support/fake_deck_repository.dart';
import '../../support/fake_stats_repository.dart';
import '../../support/fake_study_repository.dart';

DeckSummary _deck(String id, {String? name, String? courseId, int cards = 6}) =>
    DeckSummary(
      id: id,
      name: name ?? 'Deck $id',
      lastStudiedAt: null,
      totalCards: cards,
      dueCards: cards,
      masteryPercent: 0,
      courseId: courseId,
    );

ActiveSessionProgress _active(String deckId, int mastered, int total) =>
    ActiveSessionProgress(
      sessionId: 's-$deckId',
      deckId: deckId,
      studyMode: StudyMode.flip,
      lengthMode: SessionLengthMode.untilMastered,
      cardScope: CardScope.all,
      cappedLength: null,
      startedAt: DateTime(2026, 9, 1),
      masteredCards: mastered,
      totalCards: total,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpHome(
    WidgetTester tester, {
    required List<DeckSummary> decks,
    required FakeStatsRepository stats,
    String? username,
    String courseName = 'Biology',
    double textScale = 1,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final auth = FakeAuthRepository(signedIn: true);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          deckRepositoryProvider.overrideWithValue(
            FakeDeckRepository(decks: decks),
          ),
          studyRepositoryProvider.overrideWithValue(FakeStudyRepository()),
          courseRepositoryProvider.overrideWithValue(
            FakeCourseRepository(
              courses: [fakeCourse(id: 'c1', name: courseName)],
            ),
          ),
          statsRepositoryProvider.overrideWithValue(stats),
          onlineStatusProvider.overrideWith((ref) => Stream.value(true)),
          profileProvider.overrideWith(
            (ref) async => username == null
                ? null
                : (id: 'u1', email: 'a@b.com', username: username),
          ),
          initialThemeModeProvider.overrideWithValue(themeMode),
        ],
        child: const OpenRecallApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the greeting and welcome content', (tester) async {
    await pumpHome(
      tester,
      decks: [_deck('d1', courseId: 'c1')],
      stats: FakeStatsRepository(),
    );

    expect(find.byType(HomeTabScreen), findsOneWidget);
    expect(find.textContaining('Hello,'), findsOneWidget);
    expect(find.text('What would you like to do today?'), findsOneWidget);
  });

  testWidgets('carries no create action — that lives only on the Decks tab', (
    tester,
  ) async {
    await pumpHome(
      tester,
      decks: [_deck('d1', courseId: 'c1')],
      stats: FakeStatsRepository(),
    );

    expect(find.byKey(const ValueKey('home-create')), findsNothing);
  });

  testWidgets(
    'shows an unfinished-session card with its deck name and percent',
    (tester) async {
      await pumpHome(
        tester,
        decks: [_deck('d1', courseId: 'c1')],
        stats: FakeStatsRepository(activeSessions: [_active('d1', 1, 4)]),
      );

      expect(find.text('Pick up where you left off'), findsOneWidget);
      expect(find.text('Deck d1'), findsWidgets);
      expect(find.text('25%'), findsOneWidget);
    },
  );

  testWidgets('hides the unfinished-sessions section when there are none', (
    tester,
  ) async {
    await pumpHome(
      tester,
      decks: [_deck('d1', courseId: 'c1')],
      stats: FakeStatsRepository(),
    );

    expect(find.text('Pick up where you left off'), findsNothing);
  });

  testWidgets('renders the most-reviewed deck stack with a View Deck action', (
    tester,
  ) async {
    await pumpHome(
      tester,
      decks: [
        _deck('d1', courseId: 'c1'),
        _deck('d2', courseId: 'c1'),
      ],
      stats: FakeStatsRepository(sessionCountsByDeck: {'d1': 4, 'd2': 1}),
    );

    expect(find.text('Most reviewed decks'), findsOneWidget);
    expect(find.text('View Deck'), findsWidgets);
    expect(find.text('BIOLOGY'), findsWidgets);
  });

  testWidgets('the greeting uses the username when one is set', (tester) async {
    await pumpHome(
      tester,
      decks: [_deck('d1', courseId: 'c1')],
      stats: FakeStatsRepository(),
      username: 'Ada',
    );

    expect(find.text('Hello, Ada!'), findsOneWidget);
  });

  testWidgets('one unfinished session does not reserve three row slots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHome(
      tester,
      decks: [_deck('d1', courseId: 'c1')],
      stats: FakeStatsRepository(
        activeSessions: [_active('d1', 4, 4)],
        sessionCountsByDeck: {'d1': 1},
      ),
    );

    final sessionTop = tester.getTopLeft(find.text('100%')).dy;
    final reviewedTop = tester.getTopLeft(find.text('Most reviewed decks')).dy;
    expect(reviewedTop - sessionTop, lessThan(130));
  });

  testWidgets('unfinished sessions retain the three-session display limit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHome(
      tester,
      decks: [
        _deck('d1', courseId: 'c1'),
        _deck('d2', courseId: 'c1'),
        _deck('d3', courseId: 'c1'),
        _deck('d4', courseId: 'c1'),
      ],
      stats: FakeStatsRepository(
        activeSessions: [
          _active('d1', 1, 4),
          _active('d2', 2, 4),
          _active('d3', 3, 4),
          _active('d4', 4, 4),
        ],
      ),
    );

    expect(find.text('25%'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('100%'), findsNothing);
  });

  testWidgets(
    'long Home content fits the responsive viewport and scale matrix',
    (tester) async {
      const viewports = [
        Size(320, 568),
        Size(360, 640),
        Size(360, 800),
        Size(393, 873),
        Size(412, 915),
        Size(480, 960),
      ];
      const scales = [1.0, 1.3, 1.5, 2.0];
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final viewport in viewports) {
        for (final scale in scales) {
          tester.view.physicalSize = viewport;
          await pumpHome(
            tester,
            decks: [
              _deck(
                'd1',
                name: 'Cellular respiration pathways and energy conversion',
                courseId: 'c1',
                cards: 999999,
              ),
            ],
            courseName: 'Advanced molecular and cellular biology',
            stats: FakeStatsRepository(
              activeSessions: [_active('d1', 99, 100)],
              sessionCountsByDeck: {'d1': 12},
            ),
            textScale: scale,
          );

          expect(
            tester.takeException(),
            isNull,
            reason: '$viewport at text scale $scale before scrolling',
          );
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -1200),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$viewport at text scale $scale after scrolling',
          );
          expect(find.text('View Deck'), findsWidgets);
        }
      }
    },
  );

  testWidgets('the deck carousel pages between reviewed decks', (tester) async {
    await pumpHome(
      tester,
      decks: [
        _deck('d1', courseId: 'c1'),
        _deck('d2', courseId: 'c1'),
        _deck('d3', courseId: 'c1'),
      ],
      stats: FakeStatsRepository(
        sessionCountsByDeck: {'d1': 3, 'd2': 2, 'd3': 1},
      ),
    );

    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.controller!.page, 1);
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(pageView.controller!.page, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the carousel action opens the selected deck', (tester) async {
    await pumpHome(
      tester,
      decks: [_deck('d1', courseId: 'c1')],
      stats: FakeStatsRepository(sessionCountsByDeck: {'d1': 3}),
    );

    await tester.tap(find.text('View Deck'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeTabScreen), findsNothing);
  });

  testWidgets('responsive Home content renders in dark theme', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHome(
      tester,
      decks: [
        _deck(
          'd1',
          name: 'Cellular respiration pathways and energy conversion',
          courseId: 'c1',
          cards: 999999,
        ),
      ],
      stats: FakeStatsRepository(
        activeSessions: [_active('d1', 1, 1)],
        sessionCountsByDeck: {'d1': 3},
      ),
      courseName: 'Advanced molecular and cellular biology',
      textScale: 2,
      themeMode: ThemeMode.dark,
    );

    expect(
      Theme.of(tester.element(find.byType(HomeTabScreen))).brightness,
      Brightness.dark,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('View Deck'), findsWidgets);
  });
}
