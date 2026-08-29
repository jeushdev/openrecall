import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/study/presentation/widgets/session_progress_indicator.dart';

void main() {
  Widget host({required int resolved, required int total}) => MaterialApp(
        home: Scaffold(
          body: SessionProgressIndicator(resolved: resolved, total: total),
        ),
      );

  testWidgets('shows resolved / total and the matching bar value',
      (tester) async {
    await tester.pumpWidget(host(resolved: 1, total: 4));

    expect(find.text('1 / 4 mastered'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.25);
  });

  testWidgets('a zero total does not divide by zero', (tester) async {
    await tester.pumpWidget(host(resolved: 0, total: 0));
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.0);
  });
}
