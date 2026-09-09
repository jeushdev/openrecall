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
  late ClozeResult? result;
  late int hintCalls;

  Future<void> pump(
    WidgetTester tester,
    FlashCard card, {
    Key? key,
    bool initialHintUsed = false,
  }) async {
    result = null;
    hintCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ClozeTypeCard(
              key: key,
              card: card,
              initialHintUsed: initialHintUsed,
              onHintUsed: () => hintCalls++,
              onResult: (value) => result = value,
            ),
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
    expect(result?.outcome, ClozeOutcome.correct);
    expect(result?.hintUsed, isFalse);
  });

  testWidgets('a typo within the Levenshtein budget still counts as correct', (
    tester,
  ) async {
    await pump(tester, single);
    await check(tester, 'Pariss');
    expect(result?.outcome, ClozeOutcome.correct);
  });

  testWidgets('a miss then "I was right" derives Familiar (overridden)', (
    tester,
  ) async {
    await pump(tester, single);
    await check(tester, 'Berlin');

    expect(find.text('Not quite'), findsOneWidget);
    expect(result, isNull);

    await tester.tap(find.widgetWithText(OutlinedButton, 'I was right'));
    await tester.pumpAndSettle();
    expect(result?.outcome, ClozeOutcome.overridden);
  });

  testWidgets('a miss then "Next" derives Forgotten (missed)', (tester) async {
    await pump(tester, single);
    await check(tester, 'Berlin');
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(result?.outcome, ClozeOutcome.missed);
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
    expect(result, isNull);
    expect(find.text('Blank 2 of 2'), findsOneWidget);

    await check(tester, 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();

    expect(result?.outcome, ClozeOutcome.missed);
  });

  testWidgets('a card whose keyword never appears auto-completes as correct', (
    tester,
  ) async {
    await pump(
      tester,
      _card(front: 'front text', back: 'back text', keywords: ['absent']),
    );
    expect(result?.outcome, ClozeOutcome.correct);
    expect(result?.hintUsed, isFalse);
    expect(hintCalls, 0);
  });

  testWidgets('hints progressively reveal only the active blank', (
    tester,
  ) async {
    await pump(
      tester,
      _card(
        front: 'New York then Paris',
        back: 'Cities',
        keywords: ['New York', 'Paris'],
      ),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Hint'));
    await tester.pump();
    expect(find.text('N•• ••••'), findsOneWidget);
    expect(hintCalls, 1);

    await tester.tap(find.widgetWithText(TextButton, 'Hint'));
    await tester.pump();
    expect(find.text('Ne• ••••'), findsOneWidget);
    expect(hintCalls, 1);

    await check(tester, 'New York');
    expect(find.text('Blank 2 of 2'), findsOneWidget);
    expect(find.byKey(const Key('cloze-hint-preview')), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Hint'));
    await tester.pump();
    expect(find.text('P••••'), findsOneWidget);
  });

  testWidgets('a hint preserves typed input exactly', (tester) async {
    await pump(tester, single);
    const typed = '  PaRi  ';
    await tester.enterText(find.byType(TextField), typed);
    await tester.tap(find.widgetWithText(TextButton, 'Hint'));
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      typed,
    );
  });

  testWidgets('full reveal neither submits nor advances and disables Hint', (
    tester,
  ) async {
    final short = _card(front: 'A', back: 'letter', keywords: ['A']);
    await pump(tester, short);
    await tester.tap(find.widgetWithText(TextButton, 'Hint'));
    await tester.pump();

    expect(find.text('A'), findsWidgets);
    expect(find.text('Blank 1 of 1'), findsOneWidget);
    expect(result, isNull);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Hint'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('Hint is unavailable during miss review', (tester) async {
    await pump(tester, single);
    await check(tester, 'Berlin');
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Hint'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('assistance survives an override and emits exactly once', (
    tester,
  ) async {
    var emissions = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ClozeTypeCard(
            card: single,
            onHintUsed: () {},
            onResult: (value) {
              result = value;
              emissions++;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Hint'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Berlin');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Check'));
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'I was right'));
    await tester.pumpAndSettle();

    expect(result?.outcome, ClozeOutcome.overridden);
    expect(result?.hintUsed, isTrue);
    expect(emissions, 1);
    expect(find.widgetWithText(TextButton, 'Hint'), findsNothing);
  });

  testWidgets('a new same-card attempt resets reveal progress', (tester) async {
    await pump(tester, single, key: const ValueKey('attempt-1'));
    await tester.tap(find.widgetWithText(TextButton, 'Hint'));
    await tester.pump();
    expect(find.byKey(const Key('cloze-hint-preview')), findsOneWidget);

    await pump(tester, single, key: const ValueKey('attempt-2'));
    expect(find.byKey(const Key('cloze-hint-preview')), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Hint'))
          .onPressed,
      isNotNull,
    );
  });
}
