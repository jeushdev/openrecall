import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../application/offline_providers.dart';

/// The "Available offline" switch on the Deck Overview (spec §10). Turning it on
/// downloads the deck's cards into local SQLite; turning it off drops the local
/// copy after a confirm, since any not-yet-synced study results go with it.
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
        title: const Text('Available offline'),
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
    if (downloaded) return "Cards are saved on this device for offline study.";
    if (!online) return 'Connect to the internet to download this deck.';
    return "Save this deck's cards to study it without a connection.";
  }

  Future<void> _download(BuildContext context, WidgetRef ref) {
    return ref
        .read(offlineControllerProvider.notifier)
        .download(deckId, deckName ?? 'Deck');
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove offline copy?'),
        content: const Text(
          "This deck's cards will no longer be available without a connection. "
          'Any study results not yet synced will be lost.',
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
