import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/deck_providers.dart';
import 'card_fields.dart';

/// The always-visible "add a card" form on the Deck Creator (spec §3).
///
/// On a successful add it clears itself so the next card can be typed straight
/// in. Errors surface through the screen's SnackBar listener.
class CardEditorForm extends ConsumerStatefulWidget {
  const CardEditorForm({super.key, required this.deckId});

  final String deckId;

  @override
  ConsumerState<CardEditorForm> createState() => _CardEditorFormState();
}

class _CardEditorFormState extends ConsumerState<CardEditorForm> {
  final _formKey = GlobalKey<FormState>();
  final _front = TextEditingController();
  final _back = TextEditingController();
  final _keyword = TextEditingController();

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    _keyword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final keyword = _keyword.text.trim();
    final card = await ref.read(decksControllerProvider.notifier).addCard(
          deckId: widget.deckId,
          front: _front.text.trim(),
          back: _back.text.trim(),
          keyword: keyword.isEmpty ? null : keyword,
        );

    if (card == null || !mounted) return;
    _formKey.currentState!.reset();
    _front.clear();
    _back.clear();
    _keyword.clear();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(decksControllerProvider).isLoading;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add a card', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            CardFields(
              frontController: _front,
              backController: _back,
              keywordController: _keyword,
              enabled: !busy,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: const Text('Add card'),
            ),
          ],
        ),
      ),
    );
  }
}
