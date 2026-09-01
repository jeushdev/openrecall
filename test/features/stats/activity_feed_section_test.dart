import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/stats/domain/activity_feed.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/ui/mastery/activity_feed_section.dart';

Future<void> _pump(WidgetTester tester, List<ActivityItem> items) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(child: ActivityFeedSection(items: items)),
      ),
    ),
  );
}

void main() {
  final old = DateTime(2020, 1, 1);

  testWidgets('renders a labelled, icon-led row for each item type',
      (tester) async {
    await _pump(tester, [
      ActivityItem(
        kind: ActivityKind.sessionCompleted,
        timestamp: old,
        title: 'Biology · Chapter 3',
        masteryDelta: 12,
      ),
      ActivityItem(
        kind: ActivityKind.deckCreated,
        timestamp: old,
        title: 'Spanish verbs',
      ),
      ActivityItem(
        kind: ActivityKind.courseCreated,
        timestamp: old,
        title: 'Medicine',
      ),
    ]);

    expect(find.text('Recent activity'), findsOneWidget);

    expect(find.text('Completed Biology · Chapter 3'), findsOneWidget);
    expect(find.text('Created deck Spanish verbs'), findsOneWidget);
    expect(find.text('Created course Medicine'), findsOneWidget);

    expect(find.byIcon(Icons.school_outlined), findsOneWidget);
    expect(find.byIcon(Icons.style_outlined), findsOneWidget);
    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);

    // Completion rows reuse the session-summary "+X%" formatting.
    expect(find.text('+12%'), findsOneWidget);
  });

  testWidgets('shows the empty state when there is no activity', (tester) async {
    await _pump(tester, const []);

    expect(
      find.text('Your recent study activity will show up here.'),
      findsOneWidget,
    );
  });
}
