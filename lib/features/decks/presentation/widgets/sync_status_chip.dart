import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../../theme/app_tokens.dart';

/// The minimal sync-status chip (spec-v4 §O4). Deliberately quiet — ambient
/// status, not an alert:
///
/// - offline               → `☁ offline` (with `· N` when writes are queued)
/// - online, N queued (>0) → `⟳ N`, or `⚠ N` if the last push stalled
/// - online, nothing queued → nothing at all
///
/// When anything is queued the chip is tappable and runs a forced sync
/// ([manualSyncProvider], milestone E3) — the reconnect pass backs off after a
/// failure, and this is how the user asks for an immediate retry.
class SyncStatusChip extends ConsumerWidget {
  const SyncStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final online = ref.watch(onlineStatusProvider).asData?.value ?? true;
    final count = ref.watch(pendingSyncCountProvider).asData?.value ?? 0;
    final lastSyncFailed = ref.watch(syncOutcomeProvider).asData?.value.isFailure
        ?? false;

    if (online && count == 0) return const SizedBox.shrink();

    final canRetry = count > 0;
    final IconData icon;
    final String label;
    final String tooltip;
    if (!online) {
      icon = Icons.cloud_off_outlined;
      label = count > 0 ? 'offline · $count' : 'offline';
      tooltip = count > 0
          ? "You're offline — $count change${count == 1 ? '' : 's'} waiting to sync"
          : "You're offline";
    } else {
      icon = lastSyncFailed ? Icons.sync_problem : Icons.sync;
      label = '$count';
      tooltip = '$count change${count == 1 ? '' : 's'} waiting to sync';
    }

    return GestureDetector(
      onTap: canRetry ? () => ref.read(manualSyncProvider)() : null,
      child: Tooltip(
        message: canRetry ? '$tooltip — tap to retry now' : tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: tokens.mutedFill,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: tokens.textSecondary),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
