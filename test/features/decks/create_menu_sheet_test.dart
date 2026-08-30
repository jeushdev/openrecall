import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/decks/presentation/widgets/create_menu_sheet.dart';
import 'package:open_recall/routing/app_routes.dart';
import 'package:open_recall/theme/app_theme.dart';

import '../../support/fake_deck_repository.dart';

DeckSummary _deck(String id, String name) => DeckSummary(
      id: id,
      name: name,
      lastStudiedAt: null,
      totalCards: 3,
      dueCards: 3,
      masteryPercent: 0,
    );

Future<void> _pump(
  WidgetTester tester, {
  required FakeDeckRepository decks,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => CreateMenuSheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.courseCreatorPath,
        builder: (_, _) => const Scaffold(body: Text('course-creator-stub')),
      ),
      GoRoute(
        path: AppRoutes.deckCreatorPath,
        builder: (_, _) => const Scaffold(body: Text('deck-creator-stub')),
      ),
    ],
  );

  await tester.pumpWidget(ProviderScope(
    overrides: [deckRepositoryProvider.overrideWithValue(decks)],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the sheet lists the three create options', (tester) async {
    await _pump(tester, decks: FakeDeckRepository());
    await _openSheet(tester);

    expect(find.text('Create course'), findsOneWidget);
    expect(find.text('Create deck'), findsOneWidget);
    expect(find.text('Import card'), findsOneWidget);
  });

  testWidgets('Create course pushes /course-creator', (tester) async {
    await _pump(tester, decks: FakeDeckRepository());
    await _openSheet(tester);

    await tester.tap(find.text('Create course'));
    await tester.pumpAndSettle();

    expect(find.text('course-creator-stub'), findsOneWidget);
    expect(find.text('Create course'), findsNothing);
  });

  testWidgets('Create deck pushes /deck-creator', (tester) async {
    await _pump(tester, decks: FakeDeckRepository());
    await _openSheet(tester);

    await tester.tap(find.text('Create deck'));
    await tester.pumpAndSettle();

    expect(find.text('deck-creator-stub'), findsOneWidget);
  });

  testWidgets(
      'Import card expands the deck list; picking one is stubbed until U14',
      (tester) async {
    await _pump(
      tester,
      decks: FakeDeckRepository(decks: [_deck('deck-1', 'Spanish')]),
    );
    await _openSheet(tester);

    await tester.tap(find.text('Import card'));
    await tester.pumpAndSettle();
    expect(find.text('Spanish'), findsOneWidget);

    await tester.tap(find.text('Spanish'));
    await tester.pumpAndSettle();

    expect(find.text('Create course'), findsNothing); // sheet closed
    expect(find.textContaining('coming soon'), findsOneWidget);
  });

  testWidgets('Import card with no decks routes to the Deck Creator with a hint',
      (tester) async {
    await _pump(tester, decks: FakeDeckRepository());
    await _openSheet(tester);

    await tester.tap(find.text('Import card'));
    await tester.pumpAndSettle();

    expect(find.text('deck-creator-stub'), findsOneWidget);
    expect(find.textContaining('Create a deck first'), findsOneWidget);
  });
}
