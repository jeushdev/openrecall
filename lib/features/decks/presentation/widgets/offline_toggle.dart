import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../application/offline_providers.dart';

/// The "Keep available offline" switch on the Deck Overview (spec-v4 §O4).
///
/// Since spec-v4 any deck opened online is auto-cached, so this toggle is a
/// *pin* (`offline_decks.is_pinned`): on, it fetches the deck without opening it
/// and never auto-evicts it; off, it drops the local copy after a confirm. The
/// Pending local work and application history are retained when it is unpinned.
class OfflineToggle extends ConsumerWidget {
  const OfflineToggle({
    super.key,
    required this.deckId,
    required this.deckName,
  });

  final String deckId;
  final String? deckName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The "keep available offline" pin needs a local mirror, which the web
    // build never has (spec-web-mvp §5.3).
    if (kIsWeb || !ref.watch(offlineStorageAvailableProvider)) {
      return const SizedBox.shrink();
    }

    final ids =
        ref.watch(offlineDeckIdsProvider).asData?.value ?? const <String>{};
    final downloaded = ids.contains(deckId);
    final online = ref.watch(onlineStatusProvider).asData?.value ?? true;
    final busy = ref.watch(offlineControllerProvider).isLoading;
    final progress = ref.watch(downloadProgressProvider);

    ref.listen(offlineControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text("Couldn't update offline copy: $error")),
          );
      }
    });

    // Can't start a download with no connection; can always remove one. Never
    // while a download is mid-flight.
    final canToggle = !busy && progress == null && (downloaded || online);

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
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
          if (progress != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.total > 0 ? progress.fraction : null,
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Downloading ${progress.done} of ${progress.total} cards…',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
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
    final confirmed = await confirmRemoveOfflineCopy(context, ref, deckId);
    if (confirmed) {
      await ref.read(offlineControllerProvider.notifier).remove(deckId);
    }
  }
}

/// Shared wording for local package removal. This deliberately names the
/// cloud distinction so it cannot be confused with the separate Delete action.
Future<bool> confirmRemoveOfflineCopy(
  BuildContext context,
  WidgetRef ref,
  String deckId,
) async {
  final unsynced = await ref.read(deckHasUnsyncedWorkProvider(deckId).future);
  if (!context.mounted) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Remove offline copy?'),
      content: Text(
        unsynced
            ? 'The cloud deck will remain unchanged. This copy will no '
                  'longer be kept for offline study. Pending changes will '
                  'stay on this device until they are safely synced.'
            : 'The cloud deck will remain unchanged. This copy will no '
                  'longer be kept on this device for offline study.',
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
  return confirmed == true;
}
