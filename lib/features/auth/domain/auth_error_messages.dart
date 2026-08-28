import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Translates an error thrown by [AuthRepository] into a short, user-facing
/// sentence. Spec §"Error states": standard invalid-credentials /
/// already-registered messaging, plus a safe generic fallback so a raw server
/// string is never shown.
String authErrorMessage(Object error) {
  const generic = 'Something went wrong. Please try again.';
  const connectivity =
      "Can't reach the server. Check your connection and try again.";

  if (error is SocketException || error is http.ClientException) {
    return connectivity;
  }
  if (error is AuthRetryableFetchException) {
    return connectivity;
  }
  if (error is AuthWeakPasswordException) {
    return 'Please choose a stronger password.';
  }
  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return 'Incorrect email or password.';
      case 'user_already_exists':
      case 'email_exists':
        return 'An account with this email already exists.';
      case 'email_not_confirmed':
        return 'Check your inbox and confirm your email before logging in.';
      case 'weak_password':
        return 'Please choose a stronger password.';
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return 'Too many attempts. Wait a minute and try again.';
      default:
        return generic;
    }
  }
  return generic;
}
