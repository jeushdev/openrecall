import 'package:flutter/material.dart';

/// The "park this card?" prompt shown after three consecutive fails (spec §5).
/// Parking a card sets it aside so an uncapped session can still terminate.
///
/// Returns `true` from [showDialog] on "Park it", `false` on "Keep going".
class ParkPromptDialog extends StatelessWidget {
  const ParkPromptDialog({super.key});

  static Future<bool?> show(BuildContext context) => showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const ParkPromptDialog(),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Park this card?'),
      content: const Text(
        "You've missed this one three times in a row. Park it to set it aside "
        'for now and keep the session moving — it comes back next session.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep going'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Park it'),
        ),
      ],
    );
  }
}
