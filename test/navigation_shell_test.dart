import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/app.dart';
import 'package:open_recall/features/auth/presentation/login_screen.dart';
import 'package:open_recall/features/decks/presentation/deck_library_screen.dart';
import 'package:open_recall/features/splash/presentation/splash_screen.dart';

void main() {
  testWidgets('navigates Splash -> Login -> Deck Library', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OpenRecallApp()));

    // Starts on the splash screen.
    expect(find.byType(SplashScreen), findsOneWidget);

    // Splash auto-advances to Login after its delay.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    // "Log in" opens the Deck Library.
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();
    expect(find.byType(DeckLibraryScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Decks'), findsOneWidget);
  });
}
