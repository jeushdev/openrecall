import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/connectivity/connectivity_service.dart';
import 'package:open_recall/core/sync/sync_providers.dart';
import 'package:open_recall/features/decks/presentation/widgets/sync_status_chip.dart';
import 'package:open_recall/theme/app_theme.dart';

Future<void> _pump(
  WidgetTester tester, {
  required int count,
  required bool online,
  Future<void> Function()? onManualSync,
}) {
  return tester.pumpWidget(ProviderScope(
    overrides: [
      pendingSyncCountProvider.overrideWith((ref) async => count),
      onlineStatusProvider.overrideWith((ref) => Stream.value(online)),
      if (onManualSync != null)
        manualSyncProvider.overrideWithValue(onManualSync),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: Center(child: SyncStatusChip())),
    ),
  ));
}

void main() {
  testWidgets('online with a stalled queue: tapping the chip runs a manual sync',
      (tester) async {
    var ran = false;
    await _pump(tester,
        count: 3, online: true, onManualSync: () async => ran = true);
    await tester.pump();

    await tester.tap(find.byType(SyncStatusChip));
    await tester.pump();

    expect(ran, isTrue);
  });

  testWidgets('nothing queued while online: the chip is absent', (tester) async {
    await _pump(tester, count: 0, online: true);
    await tester.pump();

    expect(find.byType(Icon), findsNothing);
    expect(find.byType(Row), findsNothing);
  });

  testWidgets('offline: the chip shows but a manual sync still fires on tap',
      (tester) async {
    var ran = false;
    await _pump(tester,
        count: 2, online: false, onManualSync: () async => ran = true);
    await tester.pump();

    expect(find.textContaining('offline'), findsOneWidget);
    await tester.tap(find.byType(SyncStatusChip));
    await tester.pump();
    expect(ran, isTrue);
  });
}
