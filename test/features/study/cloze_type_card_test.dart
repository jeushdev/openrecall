import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/study/domain/cloze_outcome.dart';
import 'package:open_recall/features/study/presentation/widgets/cloze_type_card.dart';
import 'package:open_recall/theme/app_theme.dart';

FlashCard _card({
  required String front,
  required String back,
  required List<String> keywords,
}) => FlashCard(
  id: 'a',
  deckId: 'deck-1',
  front: front,
  back: back,
  keywords: keywords,
  isConcept: false,
  masteryLevel: 0,
  failCount: 0,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  late ClozeOutcome? outcome;

  Future<void> pump(WidgetTester tester, FlashCard card) async {
    outcome = null;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ClozeTypeCard(card: card, onOutcome: (o) => outcome = o),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> check(WidgetTester tester, String answer) async {
    await tester.enterText(find.byType(TextField), answer);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Check'));
    await tester.pumpAndSettle();
  }

  final single = _card(
    front: 'Paris is the capital',
    back: 'of France',
    keywords: ['Paris'],
  );

  testWidgets('a first-try exact hit derives Mastered (correct)', (
    tester,
  ) async {
    await pump(tester, single);
    await check(tester, 'Paris');
    expect(outcome, ClozeOutcome.correct);
  });

  testWidgets('a typo within the Levenshtein budget still counts as correct', (
    tester,
  ) async {
    await pump(tester, single);
    await check(tester, 'Pariss');
    expect(outcome, ClozeOutcome.correct);
  });

  testWidgets('a miss then "I was right" derives Familiar (overridden)', (
    tester,
  ) async {
    await pump(tester, single);
    await check(tester, 'Berlin');

    expect(find.text('Not quite'), findsOneWidget);
    expect(outcome, isNull);

    await tester.tap(find.widgetWithText(OutlinedButton, 'I was right'));
    await tester.pumpAndSettle();
    expect(outcome, ClozeOutcome.overridden);
  });

  testWidgets('a miss then "Next" derives Forgotten (missed)', (tester) async {
    await pump(tester, single);
    await check(tester, 'Berlin');
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(outcome, ClozeOutcome.missed);
  });

  testWidgets('a two-keyword card blanks both, answered in sequence; the '
      'aggregate is the worst blank', (tester) async {
    await pump(
      tester,
      _card(
        front: 'Mitosis and meiosis differ',
        back: 'in outcome',
        keywords: ['Mitosis', 'meiosis'],
      ),
    );

    expect(find.text('Blank 1 of 2'), findsOneWidget);
    await check(tester, 'Mitosis');
    expect(outcome, isNull);
    expect(find.text('Blank 2 of 2'), findsOneWidget);

    await check(tester, 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();

    expect(outcome, ClozeOutcome.missed);
  });

  testWidgets('a card whose keyword never appears auto-completes as correct', (
    tester,
  ) async {
    await pump(
      tester,
      _card(front: 'front text', back: 'back text', keywords: ['absent']),
    );
    expect(outcome, ClozeOutcome.correct);
  });
}
