import 'package:flutter/material.dart';

/// App-wide [ScaffoldMessenger], wired into [MaterialApp.router] in `app.dart`.
///
/// Milestone R1's optimistic deletes pop the screen that triggered them (deck
/// detail, the edit-card dialog) before the Supabase write resolves, so a
/// failure snackbar can't rely on that screen's `ScaffoldMessenger`. Controllers
/// route it here instead.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Shows [message] as a snackbar through [scaffoldMessengerKey], replacing any
/// current one. A no-op when there is no live messenger — a unit test with no
/// `MaterialApp`, or before the widgets binding is initialized (reading
/// `currentState` then throws, hence the guard).
void showAppSnackBar(String message) {
  try {
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  } catch (_) {
    // No binding / messenger available — nothing to surface the snackbar on.
  }
}
