import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/presentation/add_card_screen.dart';
import 'package:open_recall/theme/app_theme.dart';

import '../../support/fake_deck_repository.dart';

/// Pumps [AddCardScreen] for `deck-1`, pushed on top of a stub `/` so Cancel has
/// somewhere to pop to.
Future<void> _pump(
  WidgetTester tester, {
  required FakeDeckRepository decks,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
      GoRoute(
        path: '/deck/:deckId/add-card',
        builder: (_, state) => AddCardScreen(
          deckId: state.pathParameters['deckId']!,
          deckName: state.uri.queryParameters['name'],
        ),
      ),
    ],
  );

  await tester.pumpWidget(ProviderScope(
    overrides: [deckRepositoryProvider.overrideWithValue(decks)],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  ));
  router.push('/deck/deck-1/add-card');
  await tester.pumpAndSettle();
}

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<TextButton>(find.widgetWithText(TextButton, 'Save')).onPressed !=
    null;

Future<void> _enter(WidgetTester tester, String label, String text) =>
    tester.enterText(find.widgetWithText(TextFormField, label), text);

void main() {
  testWidgets('Save is disabled until both Front and Back are filled',
      (tester) async {
    await _pump(tester, decks: FakeDeckRepository());

    expect(_saveEnabled(tester), isFalse);

    await _enter(tester, 'Front', 'Capital of France');
    await tester.pump();
    expect(_saveEnabled(tester), isFalse);

    await _enter(tester, 'Back', 'Paris');
    await tester.pump();
    expect(_saveEnabled(tester), isTrue);
  });

  testWidgets('Save writes the card, clears the fields and stays put',
      (tester) async {
    final decks = FakeDeckRepository();
    await _pump(tester, decks: decks);

    await _enter(tester, 'Front', 'Capital of France');
    await _enter(tester, 'Back', 'Paris');
    await _enter(tester, 'Keyword (optional)', 'Paris');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      decks.calls,
      contains(
          'addCard(deck=deck-1, front=Capital of France, back=Paris, keyword=Paris)'),
    );
    expect(find.text('Card added'), findsOneWidget);
    // Rapid-add: still on the screen, fields blank.
    expect(find.byType(AddCardScreen), findsOneWidget);
    expect(find.text('Capital of France'), findsNothing);
    expect(find.text('Paris'), findsNothing);
  });

  testWidgets('a keyword absent from Front and Back blocks the write',
      (tester) async {
    final decks = FakeDeckRepository();
    await _pump(tester, decks: decks);

    await _enter(tester, 'Front', 'Capital of France');
    await _enter(tester, 'Back', 'Paris');
    await _enter(tester, 'Keyword (optional)', 'Berlin');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('must appear in the front or back'),
        findsOneWidget);
    expect(decks.calls.where((c) => c.startsWith('addCard')), isEmpty);
  });

  testWidgets('a failed write surfaces an error and keeps the text',
      (tester) async {
    final decks = FakeDeckRepository()..throwOnNextCall = StateError('offline');
    await _pump(tester, decks: decks);

    await _enter(tester, 'Front', 'Capital of France');
    await _enter(tester, 'Back', 'Paris');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't save the card"), findsOneWidget);
    expect(find.text('Capital of France'), findsOneWidget);
  });

  testWidgets('Cancel pops back', (tester) async {
    await _pump(tester, decks: FakeDeckRepository());

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.byType(AddCardScreen), findsNothing);
  });
}
