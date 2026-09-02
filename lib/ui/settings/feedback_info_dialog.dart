import 'package:flutter/material.dart';

/// Placeholder feedback entry point (spec §9 / Beta logistics). The real channel
/// is a Google Form shared out-of-band; its URL isn't ready yet, so this just
/// tells the tester what's coming.
///
/// Shared by the Settings screen's "Send feedback" row and the More tab's
/// "Help & feedback" row (ui-spec-v4-navigation §5) so there is one dialog to
/// maintain, not two copies of the same `AlertDialog`.
Future<void> showFeedbackInfo(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Feedback link coming soon'),
      content: const Text(
        'A form will be shared with beta testers. Thanks for helping test '
        'ActiveRecall.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
