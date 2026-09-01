import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_recall/features/decks/application/decks_tab_view.dart';
import 'package:open_recall/features/decks/presentation/widgets/deck_grid_tile.dart';
import 'package:open_recall/routing/app_routes.dart';
import 'package:open_recall/theme/app_theme.dart';

Widget _host(DeckTileView deck) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => Scaffold(
          body: Center(child: SizedBox(width: 160, height: 160, child: DeckGridTile(deck: deck))),
        ),
      ),
      GoRoute(
        path: '/deck/:deckId',
        name: AppRoutes.deckDetailName,
        builder: (_, _) => const Scaffold(body: Text('DECK DETAIL')),
      ),
    ],
  );
  return MaterialApp.router(theme: AppTheme.light, routerConfig: router);
}

void main() {
  testWidgets('an unlocked tile opens the deck on tap', (tester) async {
    await tester.pumpWidget(_host(const DeckTileView(
      id: 'd1',
      name: 'Biology',
      cardCount: 12,
      accentKey: 'green',
    )));
    await tester.tap(find.text('Biology'));
    await tester.pumpAndSettle();
    expect(find.text('DECK DETAIL'), findsOneWidget);
  });

  testWidgets('a locked tile shows the offline affordance and does not open',
      (tester) async {
    await tester.pumpWidget(_host(const DeckTileView(
      id: 'd1',
      name: 'Biology',
      cardCount: 12,
      accentKey: 'green',
      isLockedOffline: true,
    )));
    expect(find.text('Download to use offline'), findsOneWidget);

    await tester.tap(find.text('Biology'));
    await tester.pumpAndSettle();
    expect(find.text('DECK DETAIL'), findsNothing);
    expect(find.textContaining("isn't available offline"), findsOneWidget);
  });
}
