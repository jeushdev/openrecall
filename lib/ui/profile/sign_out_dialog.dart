import 'package:flutter/material.dart';

/// Confirmation for "Sign out" on the Profile tab (ui-spec-v1 §6.4).
///
/// When [hasUnsyncedWrites] is true the body explicitly warns that local
/// progress hasn't reached the server — signing out clears the device-local
/// session rows along with it. Returns `true` from [showDialog] on confirm.
class SignOutDialog extends StatelessWidget {
  const SignOutDialog({super.key, required this.hasUnsyncedWrites});

  final bool hasUnsyncedWrites;

  static Future<bool?> show(
    BuildContext context, {
    required bool hasUnsyncedWrites,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => SignOutDialog(hasUnsyncedWrites: hasUnsyncedWrites),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sign out?'),
      content: Text(
        hasUnsyncedWrites
            ? "You have study progress that hasn't synced to the server yet. "
                'Signing out now will discard it. Sign out anyway?'
            : "You'll need to sign back in to keep studying.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}
