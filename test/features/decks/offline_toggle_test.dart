import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/application/offline_providers.dart';
import 'package:open_recall/features/decks/domain/offline_download.dart';
import 'package:open_recall/features/decks/presentation/widgets/offline_toggle.dart';
import 'package:open_recall/theme/app_theme.dart';

class _StubProgress extends DownloadProgressController {
  _StubProgress(this._initial);
  final DownloadProgress? _initial;
  @override
  DownloadProgress? build() => _initial;
}

Future<void> _pump(
  WidgetTester tester, {
  DownloadProgress? progress,
  Set<String> pinned = const {},
  bool unsynced = false,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        offlineStorageAvailableProvider.overrideWithValue(true),
        downloadProgressProvider.overrideWith(() => _StubProgress(progress)),
        offlineDeckIdsProvider.overrideWith((ref) async => pinned),
        deckHasUnsyncedWorkProvider.overrideWith((ref, _) async => unsynced),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: OfflineToggle(deckId: 'd1', deckName: 'Biology'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows a determinate bar and a count while downloading', (
    tester,
  ) async {
    await _pump(tester, progress: const DownloadProgress(done: 40, total: 200));
    await tester.pump();

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.2, 0.001));
    expect(find.textContaining('40'), findsOneWidget);
    expect(find.textContaining('200'), findsOneWidget);
  });

  testWidgets('no bar when idle; pinned deck shows the pinned subtitle', (
    tester,
  ) async {
    await _pump(tester, pinned: const {'d1'});
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('Pinned'), findsOneWidget);
  });

  testWidgets('unpin dialog promises pending work is retained', (tester) async {
    await _pump(tester, pinned: const {'d1'}, unsynced: true);
    await tester.pump();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.textContaining('until they are safely synced'), findsOneWidget);
    expect(find.textContaining('will be lost'), findsNothing);
  });

  testWidgets('no SQLite keeps the offline control hidden', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [offlineStorageAvailableProvider.overrideWithValue(false)],
        child: const MaterialApp(
          home: Scaffold(
            body: OfflineToggle(deckId: 'd1', deckName: 'Biology'),
          ),
        ),
      ),
    );

    expect(find.byType(SwitchListTile), findsNothing);
  });
}
