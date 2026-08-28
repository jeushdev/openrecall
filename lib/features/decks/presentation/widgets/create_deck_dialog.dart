import 'package:flutter/material.dart';

/// Prompts for a deck name (spec §2: "+Create deck" — prompts for a name).
///
/// Returns the trimmed name, or `null` if the user cancels. Show it with
/// [showCreateDeckDialog].
class CreateDeckDialog extends StatefulWidget {
  const CreateDeckDialog({super.key});

  @override
  State<CreateDeckDialog> createState() => _CreateDeckDialogState();
}

class _CreateDeckDialogState extends State<CreateDeckDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name for the deck.');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New deck'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'Deck name',
          border: const OutlineInputBorder(),
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}

/// Shows [CreateDeckDialog] and resolves to the entered name, or `null`.
Future<String?> showCreateDeckDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const CreateDeckDialog(),
  );
}
