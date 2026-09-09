import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:open_recall/features/auth/domain/auth_error_messages.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('authErrorMessage', () {
    test('maps invalid credentials', () {
      final message = authErrorMessage(
        const AuthApiException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
      );
      expect(message, 'Incorrect email or password.');
    });

    test('maps an already-registered email', () {
      expect(
        authErrorMessage(
          const AuthApiException(
            'User already registered',
            statusCode: '422',
            code: 'user_already_exists',
          ),
        ),
        'An account with this email already exists.',
      );
      expect(
        authErrorMessage(
          const AuthApiException(
            'Email address already in use',
            statusCode: '422',
            code: 'email_exists',
          ),
        ),
        'An account with this email already exists.',
      );
    });

    test('maps an unconfirmed email', () {
      expect(
        authErrorMessage(
          const AuthApiException(
            'Email not confirmed',
            statusCode: '400',
            code: 'email_not_confirmed',
          ),
        ),
        'Check your inbox and confirm your email before logging in.',
      );
    });

    test('maps a weak password', () {
      expect(
        authErrorMessage(
          AuthWeakPasswordException(
            message: 'Password is too weak',
            statusCode: '422',
            reasons: const ['length'],
          ),
        ),
        'Please choose a stronger password.',
      );
    });

    test('maps rate limiting', () {
      expect(
        authErrorMessage(
          const AuthApiException(
            'Too many requests',
            statusCode: '429',
            code: 'over_request_rate_limit',
          ),
        ),
        'Too many attempts. Wait a minute and try again.',
      );
    });

    test('maps a retryable fetch failure to a connectivity message', () {
      expect(
        authErrorMessage(AuthRetryableFetchException()),
        'Can\'t reach the server. Check your connection and try again.',
      );
    });

    test(
      'maps dart:io and http transport errors to a connectivity message',
      () {
        const connectivity =
            'Can\'t reach the server. Check your connection and try again.';
        expect(
          authErrorMessage(const SocketException('Failed host lookup')),
          connectivity,
        );
        expect(
          authErrorMessage(http.ClientException('Connection closed')),
          connectivity,
        );
      },
    );

    test(
      'falls back to a generic message for an unknown AuthException code',
      () {
        expect(
          authErrorMessage(
            const AuthApiException('Some new server error', code: 'brand_new'),
          ),
          'Something went wrong. Please try again.',
        );
      },
    );

    test('falls back to a generic message for an unrelated error', () {
      expect(
        authErrorMessage(Exception('boom')),
        'Something went wrong. Please try again.',
      );
    });
  });
}
