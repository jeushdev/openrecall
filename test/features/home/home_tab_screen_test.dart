import 'package:flutter/widgets.dart';
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

DeckSummary _deck(String id, {String? courseId, int cards = 6}) => DeckSummary(
      id: id,
      name: 'Deck $id',
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
  }) async {
    final auth = FakeAuthRepository(signedIn: true);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          deckRepositoryProvider
              .overrideWithValue(FakeDeckRepository(decks: decks)),
          studyRepositoryProvider.overrideWithValue(FakeStudyRepository()),
          courseRepositoryProvider.overrideWithValue(
            FakeCourseRepository(courses: [fakeCourse(id: 'c1', name: 'Biology')]),
          ),
          statsRepositoryProvider.overrideWithValue(stats),
          onlineStatusProvider.overrideWith((ref) => Stream.value(true)),
          profileProvider.overrideWith(
            (ref) async => username == null
                ? null
                : (id: 'u1', email: 'a@b.com', username: username),
          ),
        ],
        child: const OpenRecallApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the greeting and the reused Overall Mastery card',
      (tester) async {
    await pumpHome(
      tester,
      decks: [_deck('d1', courseId: 'c1')],
      stats: FakeStatsRepository(),
    );

    expect(find.byType(HomeTabScreen), findsOneWidget);
    expect(find.textContaining('Hello,'), findsOneWidget);
    expect(find.text('Overall mastery'), findsOneWidget);
  });

  testWidgets('carries no create action — that lives only on the Decks tab',
      (tester) async {
    await pumpHome(
      tester,
      decks: [_deck('d1', courseId: 'c1')],
      stats: FakeStatsRepository(),
    );

    expect(find.byKey(const ValueKey('home-create')), findsNothing);
  });

  testWidgets('shows an unfinished-session card with its deck name and percent',
      (tester) async {
    await pumpHome(
      tester,
      decks: [_deck('d1', courseId: 'c1')],
      stats: FakeStatsRepository(activeSessions: [_active('d1', 1, 4)]),
    );

    expect(find.text('Unfinished sessions'), findsOneWidget);
    expect(find.text('Deck d1'), findsWidgets);
    expect(find.text('25%'), findsOneWidget);
  });

  testWidgets('hides the unfinished-sessions section when there are none',
      (tester) async {
    await pumpHome(
      tester,
      decks: [_deck('d1', courseId: 'c1')],
      stats: FakeStatsRepository(),
    );

    expect(find.text('Unfinished sessions'), findsNothing);
  });

  testWidgets('renders the most-reviewed deck stack with a View Deck action',
      (tester) async {
    await pumpHome(
      tester,
      decks: [_deck('d1', courseId: 'c1'), _deck('d2', courseId: 'c1')],
      stats: FakeStatsRepository(sessionCountsByDeck: {'d1': 4, 'd2': 1}),
    );

    expect(find.text('Most reviewed decks'), findsOneWidget);
    expect(find.text('View Deck'), findsOneWidget);
    expect(find.text('BIOLOGY'), findsWidgets);
  });

  testWidgets('the greeting uses the username when one is set', (tester) async {
    await pumpHome(
      tester,
      decks: [_deck('d1', courseId: 'c1')],
      stats: FakeStatsRepository(),
      username: 'Ada',
    );

    expect(find.text('Hello, Ada'), findsOneWidget);
  });
}
