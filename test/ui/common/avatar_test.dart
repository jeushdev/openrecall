import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/ui/common/avatar.dart';

void main() {
  group('displayNameOr', () {
    test('uses the trimmed username when it has content', () {
      expect(displayNameOr('  Ada Lovelace  ', 'x@y.com'), 'Ada Lovelace');
    });

    test('falls back to the email-derived greeting when username is null', () {
      expect(displayNameOr(null, 'jeush.b@example.com'), 'Jeush');
    });

    test('falls back when username is blank / whitespace', () {
      expect(displayNameOr('   ', 'jeush.b@example.com'), 'Jeush');
    });
  });

  group('initialsFrom', () {
    test('first letters of the first two words', () {
      expect(initialsFrom('Ada Lovelace'), 'AL');
    });

    test('first two letters of a single word', () {
      expect(initialsFrom('Ada'), 'AD');
    });

    test('one letter for a single-character name', () {
      expect(initialsFrom('A'), 'A');
    });
  });

  testWidgets('Avatar uses name initials when name is given', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Avatar(email: 'jeush.b@example.com', name: 'Ada Lovelace'),
        ),
      ),
    );
    expect(find.text('AL'), findsOneWidget);
  });

  testWidgets('Avatar falls back to email initials when name is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: Avatar(email: 'jeush.b@example.com')),
      ),
    );
    expect(find.text('JE'), findsOneWidget);
  });
}
