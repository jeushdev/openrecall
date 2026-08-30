import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/deck_providers.dart';
import '../../domain/card.dart';
import 'card_fields.dart';

/// Edits one card's content (ui-spec-v2 §6.5). Opened from a [CardListItem] row.
///
/// The form reuses [CardFields] (Front / Back / Keyword + `keywordError`
/// validation). **Save** calls [DecksController.updateCard]; the **delete**
/// action in the title bar confirms, then calls [DecksController.deleteCard].
/// Both pop the dialog on success; a failure is left in `decksControllerProvider`
/// for the host screen's listener to surface.
class EditCardDialog extends ConsumerStatefulWidget {
  const EditCardDialog({super.key, required this.card, required this.deckId});

  final FlashCard card;
  final String deckId;

  @override
  ConsumerState<EditCardDialog> createState() => _EditCardDialogState();
}

class _EditCardDialogState extends ConsumerState<EditCardDialog> {
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final keyword = _keyword.text.trim();
    final card = await ref.read(decksControllerProvider.notifier).updateCard(
          deckId: widget.deckId,
          id: widget.card.id,
          front: _front.text.trim(),
          back: _back.text.trim(),
          keyword: keyword.isEmpty ? null : keyword,
        );
    if (card != null && mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete card?'),
        content: const Text('This removes the card permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(decksControllerProvider.notifier).deleteCard(
          deckId: widget.deckId,
          id: widget.card.id,
        );
    if (!ref.read(decksControllerProvider).hasError && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(decksControllerProvider).isLoading;

    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Edit card')),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete card',
            onPressed: busy ? null : _confirmDelete,
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: CardFields(
            frontController: _front,
            backController: _back,
            keywordController: _keyword,
            enabled: !busy,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Opens [EditCardDialog] for [card]. The dialog drives the update / delete
/// itself, so this resolves to nothing.
Future<void> showEditCardDialog(
  BuildContext context, {
  required FlashCard card,
  required String deckId,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => EditCardDialog(card: card, deckId: deckId),
  );
}
