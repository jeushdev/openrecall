import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/auth/domain/auth_validators.dart';

void main() {
  group('emailError', () {
    test('returns null for a well-formed address', () {
      expect(emailError('user@example.com'), isNull);
      expect(emailError('  user@example.com  '), isNull);
    });

    test('rejects empty input', () {
      expect(emailError(''), 'Enter your email.');
      expect(emailError('   '), 'Enter your email.');
    });

    test('rejects input without an @ and domain', () {
      expect(emailError('user'), 'Enter a valid email.');
      expect(emailError('user@'), 'Enter a valid email.');
      expect(emailError('user@example'), 'Enter a valid email.');
    });
  });

  group('passwordError', () {
    test('returns null for six or more characters', () {
      expect(passwordError('secret'), isNull);
      expect(passwordError('a-longer-passphrase'), isNull);
    });

    test('rejects empty input', () {
      expect(passwordError(''), 'Enter your password.');
    });

    test('rejects fewer than six characters', () {
      expect(passwordError('short'), 'Password must be at least 6 characters.');
    });

    test('does not trim the password', () {
      expect(passwordError('  a  '), 'Password must be at least 6 characters.');
      expect(passwordError('   x   '), isNull);
    });
  });
}
