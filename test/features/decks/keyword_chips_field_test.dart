import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/presentation/widgets/keyword_chips_field.dart';

/// Hosts a [KeywordChipsField] inside a [Form] with a fixed front/back and a
/// Save button that reports whether the form validates.
Widget _host({
  List<String> initial = const [],
  String front = 'The mitochondria makes ATP',
  String back = 'cellular respiration',
  required ValueChanged<List<String>> onChanged,
  GlobalKey<FormState>? formKey,
}) {
  final key = formKey ?? GlobalKey<FormState>();
  return MaterialApp(
    home: Scaffold(
      body: Form(
        key: key,
        child: KeywordChipsField(
          initialValue: initial,
          onChanged: onChanged,
          enabled: true,
          front: () => front,
          back: () => back,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('commits a keyword as a chip on the done action', (tester) async {
    var current = <String>[];
    await tester.pumpWidget(_host(onChanged: (v) => current = v));

    await tester.enterText(
      find.widgetWithText(TextField, 'Add a keyword'),
      'mitochondria',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.widgetWithText(InputChip, 'mitochondria'), findsOneWidget);
    expect(current, ['mitochondria']);
  });

  testWidgets('rejects a keyword that is not in the front or back',
      (tester) async {
    var current = <String>[];
    await tester.pumpWidget(_host(onChanged: (v) => current = v));

    await tester.enterText(
      find.widgetWithText(TextField, 'Add a keyword'),
      'ribosome',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.widgetWithText(InputChip, 'ribosome'), findsNothing);
    expect(current, isEmpty);
    expect(find.text('Keyword must appear in the front or back text.'),
        findsOneWidget);
  });

  testWidgets('deleting a chip removes it from the value', (tester) async {
    var current = <String>['ATP'];
    await tester.pumpWidget(_host(initial: const ['ATP'], onChanged: (v) => current = v));

    expect(find.widgetWithText(InputChip, 'ATP'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pump();

    expect(find.widgetWithText(InputChip, 'ATP'), findsNothing);
    expect(current, isEmpty);
  });

  testWidgets('a duplicate keyword is not added twice', (tester) async {
    var current = <String>['ATP'];
    await tester.pumpWidget(
      _host(initial: const ['ATP'], onChanged: (v) => current = v),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Add a keyword'),
      'ATP',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.widgetWithText(InputChip, 'ATP'), findsOneWidget);
    expect(current, ['ATP']);
  });
}
