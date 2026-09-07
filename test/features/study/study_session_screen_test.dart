import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/study/application/session_controller.dart';
import 'package:open_recall/features/study/domain/study_session.dart';
import 'package:open_recall/features/study/presentation/study_session_args.dart';
import 'package:open_recall/features/study/presentation/study_session_screen.dart';
import 'package:open_recall/features/study/presentation/widgets/cloze_type_card.dart';
import 'package:open_recall/features/study/presentation/widgets/flip_card.dart';
import 'package:open_recall/features/study/presentation/widgets/rating_row.dart';
import 'package:open_recall/features/study/presentation/widgets/session_summary_view.dart';
import 'package:open_recall/routing/app_routes.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_deck_repository.dart';
import '../../support/fake_study_repository.dart';

FlashCard _card(
  String id, {
  int mastery = 0,
  List<String> keywords = const [],
  bool isConcept = false,
  String? front,
  String? back,
}) => FlashCard(
  id: id,
  deckId: 'deck-1',
  front: front ?? 'front-$id',
  back: back ?? 'back-$id',
  keywords: keywords,
  isConcept: isConcept,
  masteryLevel: mastery,
  failCount: 0,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Widget _host({
  required FakeDeckRepository decks,
  required FakeStudyRepository study,
  String scope = 'due',
  double textScale = 1,
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
            builder: (_, state) {
              final args = state.extra as StudySessionArgs?;
              return StudySessionScreen(
                deckId: state.pathParameters['deckId']!,
                scope: cardScopeFromDb(
                  state.uri.queryParameters['scope'] ?? 'due',
                ),
                requestedMode: args?.mode,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.importCardsPath,
        name: AppRoutes.importCardsName,
        builder: (_, state) =>
            Scaffold(body: Text('import ${state.pathParameters['deckId']}')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      deckRepositoryProvider.overrideWithValue(decks),
      studyRepositoryProvider.overrideWithValue(study),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
}

Future<void> _open(
  WidgetTester tester, {
  required FakeDeckRepository decks,
  required FakeStudyRepository study,
  String scope = 'due',
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    _host(decks: decks, study: study, scope: scope, textScale: textScale),
  );
  GoRouter.of(tester.element(find.text('Home')))
      .go('/home/study/deck-1?scope=$scope');
  await tester.pumpAndSettle();
}

/// Navigates to the study route the way the deck-detail picker does — with a
/// [StudySessionArgs] `extra` carrying the chosen [mode].
void _goWithMode(WidgetTester tester, StudyMode mode) {
  GoRouter.of(tester.element(find.text('Home'))).go(
    '/home/study/deck-1',
    extra: StudySessionArgs(
      deckId: 'deck-1',
      mode: mode,
      cardScope: CardScope.all,
    ),
  );
}

Future<void> _openWithMode(
  WidgetTester tester,
  StudyMode mode, {
  required FakeDeckRepository decks,
  required FakeStudyRepository study,
}) async {
  await tester.pumpWidget(_host(decks: decks, study: study));
  _goWithMode(tester, mode);
  await tester.pumpAndSettle();
}

void main() {
  // Pin the "Card transition" setting so `studyAppearanceProvider` resolves
  // deterministically (to the flip3d default) instead of degrading off a
  // missing SharedPreferences plugin. Individual tests re-seed it as needed.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a single-mode deck skips the picker and opens Flip', (
    tester,
  ) async {
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

  testWidgets('the fade transition setting still reveals the back on tap', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'card_transition': 'fade'});
    await _open(
      tester,
      decks: FakeDeckRepository(cards: [_card('a')]),
      study: FakeStudyRepository(),
    );

    await tester.tap(find.byType(FlipCard));
    await tester.pumpAndSettle();
    expect(find.text('back-a'), findsOneWidget);
  });

  testWidgets('the rating row is inert until the card is flipped', (
    tester,
  ) async {
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

  testWidgets('a deck supporting several modes shows the picker', (
    tester,
  ) async {
    await _open(
      tester,
      decks: FakeDeckRepository(
        cards: [
          _card('a', front: 'Paris is the capital', keywords: ['Paris']),
        ],
      ),
      study: FakeStudyRepository(),
    );

    expect(find.text('How do you want to study this deck?'), findsOneWidget);
    expect(find.text('Flip & Rate'), findsOneWidget);
    expect(find.text('Cloze Type-in'), findsOneWidget);

    await tester.tap(find.text('Flip & Rate'));
    await tester.pumpAndSettle();
    expect(find.text('Paris is the capital'), findsOneWidget);
  });

  testWidgets('picker and active ratings fit at 320x568 and 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);

    await _open(
      tester,
      decks: FakeDeckRepository(
        cards: [
          _card(
            'a',
            front: 'Paris is the capital',
            back: 'of France',
            keywords: const ['Paris'],
          ),
        ],
      ),
      study: FakeStudyRepository(),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Flip & Rate'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FlipCard));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Mastered').hitTestable(), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Unfamiliar')).overflow,
      isNot(TextOverflow.ellipsis),
    );
  });

  testWidgets('Cloze has no rating row; answering the blank ends the session', (
    tester,
  ) async {
    await _open(
      tester,
      decks: FakeDeckRepository(
        cards: [
          _card(
            'a',
            front: 'Paris is the capital',
            keywords: ['Paris'],
            back: 'of France',
          ),
        ],
      ),
      study: FakeStudyRepository(),
    );

    await tester.tap(find.text('Cloze Type-in'));
    await tester.pumpAndSettle();
    expect(find.byType(ClozeTypeCard), findsOneWidget);
    expect(find.byType(RatingRow), findsNothing);

    await tester.enterText(find.byType(TextField), 'Paris');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Check'));
    await tester.pumpAndSettle();

    // A first-try hit → Mastered → the one-card queue drains → Summary.
    expect(find.byType(SessionSummaryView), findsOneWidget);
  });

  testWidgets('Cloze field and submit stay reachable above the keyboard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'card_font_size': 'xlarge'});
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetViewInsets);

    await _open(
      tester,
      decks: FakeDeckRepository(
        cards: [
          _card(
            'a',
            front: 'Paris is the capital of France and a major European city',
            keywords: const ['Paris'],
            back: 'A long explanation that must remain scrollable.',
          ),
        ],
      ),
      study: FakeStudyRepository(),
      textScale: 2,
    );
    await tester.tap(find.text('Cloze Type-in'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Paris');
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    final check = find.widgetWithText(FilledButton, 'Check');
    await tester.ensureVisible(check);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(RatingRow), findsNothing);
    expect(check.hitTestable(), findsOneWidget);
    expect(tester.getBottomRight(check).dy, lessThanOrEqualTo(308));
    await tester.tap(check);
    await tester.pumpAndSettle();
    expect(find.text('This session'), findsOneWidget);
  });

  testWidgets('completing the session shows the Summary, then Done pops back', (
    tester,
  ) async {
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

    final done = find.widgetWithText(TextButton, 'Done');
    await tester.ensureVisible(done);
    await tester.pumpAndSettle();
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.byType(StudySessionScreen), findsNothing);
  });

  testWidgets('the close button leaves the session active and pops', (
    tester,
  ) async {
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

  testWidgets('an all-mastered deck on the due scope shows nothing to study', (
    tester,
  ) async {
    await _open(
      tester,
      decks: FakeDeckRepository(cards: [_card('a', mastery: 4)]),
      study: FakeStudyRepository(),
    );

    expect(find.textContaining('Nothing to study'), findsOneWidget);
  });

  testWidgets('a deck with no cards shows the empty state, not a spinner', (
    tester,
  ) async {
    await _open(
      tester,
      decks: FakeDeckRepository(cards: const []),
      study: FakeStudyRepository(),
    );

    expect(find.text('Nothing to study in this deck yet.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('the no-cards empty state opens the import screen for the deck', (
    tester,
  ) async {
    await _open(
      tester,
      decks: FakeDeckRepository(cards: const []),
      study: FakeStudyRepository(),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Add cards'));
    await tester.pumpAndSettle();

    expect(find.text('import deck-1'), findsOneWidget);
  });

  testWidgets('the all-mastered dead-end offers to import cards', (
    tester,
  ) async {
    await _open(
      tester,
      decks: FakeDeckRepository(cards: [_card('a', mastery: 4)]),
      study: FakeStudyRepository(),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Add cards'));
    await tester.pumpAndSettle();

    expect(find.text('import deck-1'), findsOneWidget);
  });

  testWidgets('the active session shows a "resolved / total" counter', (
    tester,
  ) async {
    await _open(
      tester,
      decks: FakeDeckRepository(cards: [_card('a'), _card('b'), _card('c')]),
      study: FakeStudyRepository(),
    );

    expect(find.text('0 / 3'), findsOneWidget);

    await tester.tap(find.byType(FlipCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mastered'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('a larger "Card text size" preset scales only the card context', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'card_font_size': 'xlarge'});
    await _open(
      tester,
      decks: FakeDeckRepository(cards: [_card('a')]),
      study: FakeStudyRepository(),
    );

    // The card surface picks up the 1.3 scaler from the setting…
    final cardContext = tester.element(find.text('front-a'));
    expect(MediaQuery.textScalerOf(cardContext).scale(10), closeTo(13.0, 1e-6));

    // …while the session chrome (the counter) stays at the app's normal size.
    final counterContext = tester.element(find.text('0 / 1'));
    expect(MediaQuery.textScalerOf(counterContext).scale(10), 10.0);
  });

  testWidgets('the default preset leaves the card text context unscaled', (
    tester,
  ) async {
    await _open(
      tester,
      decks: FakeDeckRepository(cards: [_card('a')]),
      study: FakeStudyRepository(),
    );

    final cardContext = tester.element(find.text('front-a'));
    expect(MediaQuery.textScalerOf(cardContext).scale(10), 10.0);
  });

  group('mode routing (milestone R1)', () {
    FakeDeckRepository twoModeDeck() => FakeDeckRepository(
      cards: [
        _card(
          'a',
          front: 'Paris is the capital',
          keywords: ['Paris'],
          back: 'of France',
        ),
        _card('b', front: 'Rome', keywords: ['Rome'], back: 'is in Italy'),
      ],
    );

    testWidgets('a forwarded mode starts it, skipping the in-screen picker', (
      tester,
    ) async {
      await _openWithMode(
        tester,
        StudyMode.cloze,
        decks: twoModeDeck(),
        study: FakeStudyRepository(),
      );

      expect(find.text('How do you want to study this deck?'), findsNothing);
      expect(find.byType(ClozeTypeCard), findsOneWidget);
    });

    testWidgets('re-entering with a different mode starts fresh, not the '
        'stale session', (tester) async {
      final decks = twoModeDeck();
      await _openWithMode(
        tester,
        StudyMode.flip,
        decks: decks,
        study: FakeStudyRepository(),
      );
      expect(find.byType(FlipCard), findsOneWidget);

      // Close (keeps the session alive) → back Home.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);

      // Re-open the same deck asking for Cloze.
      _goWithMode(tester, StudyMode.cloze);
      await tester.pumpAndSettle();

      expect(find.byType(FlipCard), findsNothing);
      expect(find.byType(ClozeTypeCard), findsOneWidget);
    });

    testWidgets('completing a mode-forwarded session shows the Summary, not a '
        'spinner', (tester) async {
      await _openWithMode(
        tester,
        StudyMode.flip,
        decks: FakeDeckRepository(cards: [_card('a')]),
        study: FakeStudyRepository(),
      );

      await tester.tap(find.byType(FlipCard));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mastered'));
      await tester.pumpAndSettle();

      expect(find.byType(SessionSummaryView), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('re-entering with the same mode resumes the live session', (
      tester,
    ) async {
      final decks = twoModeDeck();
      await _openWithMode(
        tester,
        StudyMode.flip,
        decks: decks,
        study: FakeStudyRepository(),
      );

      // Master card a → advance to card b.
      await tester.tap(find.byType(FlipCard));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mastered'));
      await tester.pumpAndSettle();
      expect(find.text('Rome'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      _goWithMode(tester, StudyMode.flip);
      await tester.pumpAndSettle();

      // Resumed mid-session on card b — not restarted at card a.
      expect(find.text('Rome'), findsOneWidget);
      expect(find.text('Paris is the capital'), findsNothing);
    });
  });
}
