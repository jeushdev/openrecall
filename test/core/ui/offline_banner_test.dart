import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/connectivity/connectivity_service.dart';
import 'package:open_recall/core/ui/offline_banner.dart';
import 'package:open_recall/theme/app_theme.dart';

Future<void> _pump(WidgetTester tester, {required bool online}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        onlineStatusProvider.overrideWith((ref) => Stream.value(online)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: OfflineBanner()),
      ),
    ),
  );
}

void main() {
  testWidgets('renders nothing while online', (tester) async {
    await _pump(tester, online: true);
    await tester.pump();
    expect(find.text("You're offline"), findsNothing);
  });

  testWidgets('renders a persistent strip while offline', (tester) async {
    await _pump(tester, online: false);
    await tester.pump();
    expect(find.text("You're offline"), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
  });

  testWidgets('defaults to hidden before connectivity resolves', (
    tester,
  ) async {
    // The platform channel is unavailable in tests and on a cold start the
    // stream has not emitted yet. Assuming online keeps the banner from
    // flashing on every launch.
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: OfflineBanner()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text("You're offline"), findsNothing);
  });
}
