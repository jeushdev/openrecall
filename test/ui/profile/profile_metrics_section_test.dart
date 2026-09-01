import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/stats/application/stats_providers.dart';
import 'package:open_recall/features/stats/domain/study_metrics.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/ui/profile/profile_metrics_section.dart';

const _metrics = StudyMetrics(
  currentStreak: 4,
  longestStreak: 7,
  sessionsCompleted: 31,
  totalCardsReviewed: 540,
  totalStudyTime: Duration(hours: 3, minutes: 20),
  thisWeekSessions: 5,
  thisWeekCards: 88,
  thisWeekStudyTime: Duration(minutes: 45),
);

Widget _app() => MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: SingleChildScrollView(child: ProfileMetricsSection()),
      ),
    );

void main() {
  testWidgets('renders a tile per metric with its value', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studyMetricsProvider.overrideWith((ref) async => _metrics),
        ],
        child: _app(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Longest streak'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Sessions completed'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
    expect(find.text('Cards reviewed'), findsOneWidget);
    expect(find.text('540'), findsOneWidget);
    expect(find.text('Study time'), findsOneWidget);
    expect(find.text('3h 20m'), findsOneWidget);

    expect(find.text('This week'), findsOneWidget);
    expect(find.text('88'), findsOneWidget);
    expect(find.text('45m'), findsOneWidget);
  });

  testWidgets('every tile shows a placeholder while the metrics load',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studyMetricsProvider
              .overrideWith((ref) => Completer<StudyMetrics>().future),
        ],
        child: _app(),
      ),
    );
    await tester.pump();

    expect(find.text('7'), findsNothing);
    expect(find.text('3h 20m'), findsNothing);
    expect(find.text('Longest streak'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
  });
}
