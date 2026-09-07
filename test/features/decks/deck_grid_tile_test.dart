import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_recall/features/decks/application/decks_tab_view.dart';
import 'package:open_recall/features/decks/presentation/widgets/deck_grid.dart';
import 'package:open_recall/features/decks/presentation/widgets/deck_grid_tile.dart';
import 'package:open_recall/routing/app_routes.dart';
import 'package:open_recall/theme/app_theme.dart';

import '../../support/responsive_test_harness.dart';

Widget _host(DeckTileView deck) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: DeckGridTile(deck: deck),
            ),
          ),
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

Widget _gridHost({
  required double textScale,
  Brightness brightness = Brightness.light,
}) {
  const decks = [
    DeckTileView(
      id: 'long',
      name: 'Cellular respiration pathways and energy conversion',
      cardCount: 999999,
      accentKey: 'green',
    ),
    DeckTileView(
      id: 'offline',
      name: 'Offline molecular biology reference collection',
      cardCount: 0,
      accentKey: 'blue',
      isLockedOffline: true,
    ),
  ];
  return ProviderScope(
    child: MaterialApp(
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: DeckGrid(
            courseId: 'course',
            decks: decks,
            showCreateTile: true,
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('an unlocked tile opens the deck on tap', (tester) async {
    await tester.pumpWidget(
      _host(
        const DeckTileView(
          id: 'd1',
          name: 'Biology',
          cardCount: 12,
          accentKey: 'green',
        ),
      ),
    );
    await tester.tap(find.text('Biology'));
    await tester.pumpAndSettle();
    expect(find.text('DECK DETAIL'), findsOneWidget);
  });

  testWidgets('a locked tile shows the offline affordance and does not open', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const DeckTileView(
          id: 'd1',
          name: 'Biology',
          cardCount: 12,
          accentKey: 'green',
          isLockedOffline: true,
        ),
      ),
    );
    expect(find.text('Download to use offline'), findsOneWidget);

    await tester.tap(find.text('Biology'));
    await tester.pumpAndSettle();
    expect(find.text('DECK DETAIL'), findsNothing);
    expect(find.textContaining("isn't available offline"), findsOneWidget);
  });

  testWidgets(
    'grid content fits the responsive viewport and text-scale matrix',
    (tester) async {
      for (final viewport in responsiveViewports) {
        for (final scale in responsiveTextScales) {
          configureResponsiveView(tester, viewport: viewport);
          await tester.pumpWidget(_gridHost(textScale: scale));
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: '$viewport at text scale $scale',
          );
          final tiles = find.byType(DeckGridTile);
          expect(tiles, findsNWidgets(2));
          final firstRect = tester.getRect(tiles.at(0));
          final secondRect = tester.getRect(tiles.at(1));
          expect(
            firstRect.top,
            secondRect.top,
            reason: 'two columns at $viewport / $scale',
          );
          expect(firstRect.height, greaterThanOrEqualTo(firstRect.width));

          for (final label in [
            'Cellular respiration pathways and energy conversion',
            'Offline molecular biology reference collection',
            'Download to use offline',
          ]) {
            final textRect = tester.getRect(find.text(label));
            final tileRect = tester.getRect(
              find.ancestor(
                of: find.text(label),
                matching: find.byType(DeckGridTile),
              ),
            );
            expect(tileRect.contains(textRect.topLeft), isTrue);
            expect(tileRect.contains(textRect.bottomRight), isTrue);
          }
        }
      }
    },
  );

  testWidgets('responsive grid content renders in dark theme', (tester) async {
    configureResponsiveView(tester, viewport: const Size(320, 568));

    await tester.pumpWidget(
      _gridHost(textScale: 2, brightness: Brightness.dark),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      Theme.of(tester.element(find.byType(DeckGridTile).first)).brightness,
      Brightness.dark,
    );
  });
}
