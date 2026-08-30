import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../application/offline_providers.dart';

/// The "Keep available offline" switch on the Deck Overview (spec-v4 §O4).
///
/// Since spec-v4 any deck opened online is auto-cached, so this toggle is a
/// *pin* (`offline_decks.is_pinned`): on, it fetches the deck without opening it
/// and never auto-evicts it; off, it drops the local copy after a confirm. The
/// confirm only warns about data loss when the deck actually holds unsynced
/// local work.
class OfflineToggle extends ConsumerWidget {
  const OfflineToggle({super.key, required this.deckId, required this.deckName});

  final String deckId;
  final String? deckName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids =
        ref.watch(offlineDeckIdsProvider).asData?.value ?? const <String>{};
    final downloaded = ids.contains(deckId);
    final online = ref.watch(onlineStatusProvider).asData?.value ?? true;
    final busy = ref.watch(offlineControllerProvider).isLoading;

    ref.listen(offlineControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text("Couldn't update offline copy: $error")),
          );
      }
    });

    // Can't start a download with no connection; can always remove one.
    final canToggle = !busy && (downloaded || online);

    return Card(
      child: SwitchListTile(
        secondary: Icon(
          downloaded ? Icons.download_done : Icons.download_outlined,
        ),
        title: const Text('Keep available offline'),
        subtitle: Text(_subtitle(downloaded: downloaded, online: online)),
        value: downloaded,
        onChanged: canToggle
            ? (want) {
                if (want) {
                  _download(context, ref);
                } else {
                  _confirmRemove(context, ref);
                }
              }
            : null,
      ),
    );
  }

  String _subtitle({required bool downloaded, required bool online}) {
    if (downloaded) {
      return 'Pinned — kept on this device and never removed automatically.';
    }
    if (!online) return 'Connect to the internet to pin this deck.';
    return "Pin this deck to keep its cards on this device.";
  }

  Future<void> _download(BuildContext context, WidgetRef ref) {
    return ref
        .read(offlineControllerProvider.notifier)
        .download(deckId, deckName ?? 'Deck');
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final unsynced =
        await ref.read(deckHasUnsyncedWorkProvider(deckId).future);
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove offline copy?'),
        content: Text(
          unsynced
              ? "This deck won't be kept on this device, and unsynced changes "
                  'to it will be lost.'
              : "This deck's cards will no longer be kept on this device for "
                  'offline study.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(offlineControllerProvider.notifier).remove(deckId);
    }
  }
}
