import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/deck_providers.dart';
import '../domain/card.dart';
import 'widgets/bulk_paste_panel.dart';
import 'widgets/card_editor_form.dart';
import 'widgets/card_list_item.dart';
import 'widgets/edit_card_dialog.dart';

/// The Deck Creator / card-manager (spec §3). Reached both from "+Create deck"
/// (landing here on a brand-new empty deck) and by tapping an existing deck in
/// the Library. One unified form per card — no type picker — plus a bulk-paste
/// panel.
class DeckCreatorScreen extends ConsumerWidget {
  const DeckCreatorScreen({super.key, required this.deckId, this.deckName});

  final String deckId;
  final String? deckName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(decksControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Something went wrong: $error')));
      }
    });

    final cards = ref.watch(deckCardsProvider(deckId));

    return Scaffold(
      appBar: AppBar(title: Text(deckName ?? 'Deck')),
      body: ListView(
        children: [
          cards.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text("Couldn't load this deck's cards."),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => ref.invalidate(deckCardsProvider(deckId)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (list) => list.isEmpty
                ? const _EmptyCards()
                : Column(
                    children: [
                      for (final card in list)
                        CardListItem(
                          card: card,
                          onEdit: () => _editCard(context, ref, card),
                          onDelete: () => _deleteCard(context, ref, card),
                        ),
                    ],
                  ),
          ),
          const Divider(height: 32),
          CardEditorForm(deckId: deckId),
          const Divider(height: 8),
          BulkPastePanel(deckId: deckId),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _editCard(
    BuildContext context,
    WidgetRef ref,
    FlashCard card,
  ) async {
    final edited = await showEditCardDialog(context, card);
    if (edited == null) return;
    await ref.read(decksControllerProvider.notifier).updateCard(
          deckId: deckId,
          id: card.id,
          front: edited.front,
          back: edited.back,
          keyword: edited.keyword,
        );
  }

  Future<void> _deleteCard(
    BuildContext context,
    WidgetRef ref,
    FlashCard card,
  ) async {
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
    if (confirmed != true) return;
    await ref
        .read(decksControllerProvider.notifier)
        .deleteCard(deckId: deckId, id: card.id);
  }
}

class _EmptyCards extends StatelessWidget {
  const _EmptyCards();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 32, 24, 8),
      child: Text(
        'Add your first card below — type one in, or open "Bulk paste" to '
        'import a batch. "Copy AI Prompt" there gives you a prompt for any '
        'web LLM.',
        textAlign: TextAlign.center,
      ),
    );
  }
}
