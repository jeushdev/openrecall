import 'package:flutter/material.dart';

import '../../domain/card.dart';
import 'card_fields.dart';

/// The result of a successful edit in [EditCardDialog].
typedef EditedCard = ({String front, String back, String? keyword});

/// Edits one card's content in a dialog (spec §3: "Edit / delete individual
/// cards after import"). Returns the new values, or `null` on cancel.
class EditCardDialog extends StatefulWidget {
  const EditCardDialog({super.key, required this.card});

  final FlashCard card;

  @override
  State<EditCardDialog> createState() => _EditCardDialogState();
}

class _EditCardDialogState extends State<EditCardDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _front = TextEditingController(text: widget.card.front);
  late final _back = TextEditingController(text: widget.card.back);
  late final _keyword = TextEditingController(text: widget.card.keyword ?? '');

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    _keyword.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final keyword = _keyword.text.trim();
    Navigator.of(context).pop<EditedCard>((
      front: _front.text.trim(),
      back: _back.text.trim(),
      keyword: keyword.isEmpty ? null : keyword,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit card'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: CardFields(
            frontController: _front,
            backController: _back,
            keywordController: _keyword,
            enabled: true,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

/// Shows [EditCardDialog] and resolves to the edited values, or `null`.
Future<EditedCard?> showEditCardDialog(BuildContext context, FlashCard card) {
  return showDialog<EditedCard>(
    context: context,
    builder: (_) => EditCardDialog(card: card),
  );
}
