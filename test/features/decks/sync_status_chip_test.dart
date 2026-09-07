import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/connectivity/connectivity_service.dart';
import 'package:open_recall/core/sync/sync_providers.dart';
import 'package:open_recall/core/sync/sync_service.dart';
import 'package:open_recall/features/decks/presentation/widgets/sync_status_chip.dart';
import 'package:open_recall/theme/app_theme.dart';

Future<void> _pump(
  WidgetTester tester, {
  required int count,
  required bool online,
  SyncOutcome outcome = const SyncOutcome.idle(),
  Future<void> Function()? onManualSync,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        pendingSyncCountProvider.overrideWith((ref) async => count),
        onlineStatusProvider.overrideWith((ref) => Stream.value(online)),
        syncOutcomeProvider.overrideWith((ref) => Stream.value(outcome)),
        if (onManualSync != null)
          manualSyncProvider.overrideWithValue(onManualSync),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: Center(child: SyncStatusChip())),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'online with a stalled queue: tapping the chip runs a manual sync',
    (tester) async {
      var ran = false;
      await _pump(
        tester,
        count: 3,
        online: true,
        onManualSync: () async => ran = true,
      );
      await tester.pump();

      await tester.tap(find.byType(SyncStatusChip));
      await tester.pump();

      expect(ran, isTrue);
    },
  );

  testWidgets('nothing queued while online: the chip is absent', (
    tester,
  ) async {
    await _pump(
      tester,
      count: 0,
      online: true,
      outcome: SyncOutcome.ok(DateTime.utc(2026)),
    );
    await tester.pump();

    expect(find.byType(Icon), findsNothing);
    expect(find.byType(Row), findsNothing);
    expect(find.textContaining('synced'), findsNothing);
  });

  testWidgets('offline pending work is shown but retry is disabled', (
    tester,
  ) async {
    var ran = false;
    await _pump(
      tester,
      count: 2,
      online: false,
      onManualSync: () async => ran = true,
    );
    await tester.pump();

    expect(find.textContaining('offline'), findsOneWidget);
    await tester.tap(find.byType(SyncStatusChip));
    await tester.pump();
    expect(ran, isFalse);
  });

  testWidgets('offline without pending work is left to the global banner', (
    tester,
  ) async {
    await _pump(tester, count: 0, online: false);
    await tester.pump();

    expect(find.byType(Icon), findsNothing);
    expect(find.textContaining('offline'), findsNothing);
  });

  testWidgets('a failed online sync shows failure and keeps retry enabled', (
    tester,
  ) async {
    var ran = false;
    await _pump(
      tester,
      count: 2,
      online: true,
      outcome: SyncOutcome.failed(StateError('stalled'), DateTime.utc(2026)),
      onManualSync: () async => ran = true,
    );
    await tester.pump();

    expect(find.byIcon(Icons.sync_problem), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('synced'), findsNothing);
    await tester.tap(find.byType(SyncStatusChip));
    await tester.pump();
    expect(ran, isTrue);
  });
}
