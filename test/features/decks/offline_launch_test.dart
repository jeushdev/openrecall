import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_deck_repository.dart';
import '../../support/pump_app.dart';

/// Milestone E1's headline guarantee: launching with no connection paints the
/// user's cached decks and the offline banner in the first couple of frames,
/// instead of blocking on a Supabase round-trip that cannot succeed.
///
/// The bug this pins: `tabDecksProvider` used to wrap the whole cache-first read
/// in `.timeout(6s)`, so an unreachable host burned the budget before the cache
/// fallback ran and the tab showed "Couldn't load your decks" over a perfectly
/// good local mirror.
class _OfflineMirror extends LocalDeckStore {
  _OfflineMirror() : super(null);

  @override
  bool get isNoop => false;

  @override
  Future<List<DeckSummary>> cachedDeckSummaries() async => const [
        DeckSummary(
          id: 'cached-1',
          name: 'Mitochondria',
          lastStudiedAt: null,
          totalCards: 8,
          dueCards: 8,
          masteryPercent: 0,
        ),
        DeckSummary(
          id: 'cached-2',
          name: 'Never opened',
          lastStudiedAt: null,
          totalCards: 0,
          dueCards: 0,
          masteryPercent: 0,
        ),
      ];

  @override
  Future<Set<String>> mirroredCardDeckIds() async => {'cached-1'};
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('offline launch paints cached decks and the banner immediately',
      (tester) async {
    await pumpApp(
      tester,
      signedIn: true,
      online: false,
      // Never completes — an interface that is up but has no route to Supabase,
      // the case the old timeout mishandled.
      decks: FakeDeckRepository()..hangForever = true,
      localDecks: _OfflineMirror(),
      settle: false,
    );

    // A bounded number of frames — no pumpAndSettle, no elapsed timeout.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('Mitochondria'), findsOneWidget);
    expect(find.text("You're offline"), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text("Couldn't load your decks"), findsNothing);

    // Advance past the revalidation bound so no timer outlives the test; the
    // fallback resolves to the same cached decks.
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.text('Mitochondria'), findsOneWidget);
  });

  testWidgets('a deck with no mirrored cards renders locked', (tester) async {
    await pumpApp(
      tester,
      signedIn: true,
      online: false,
      decks: FakeDeckRepository()..hangForever = true,
      localDecks: _OfflineMirror(),
      settle: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('Download to use offline'), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
  });
}
