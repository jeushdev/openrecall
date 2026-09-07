import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../../theme/app_tokens.dart';

/// The minimal sync-status chip (spec-v4 §O4). Deliberately quiet — ambient
/// status, not an alert:
///
/// - offline, N queued (>0) → `☁ offline · N` (retry disabled)
/// - online, N queued (>0)  → `⟳ N`, or `⚠ N` if the last push stalled
/// - nothing queued         → nothing at all
///
/// A queued online change is tappable and runs a forced sync
/// ([manualSyncProvider], milestone E3). A failed attempt does not disable that
/// action; only a definitive offline connectivity reading does.
class SyncStatusChip extends ConsumerWidget {
  const SyncStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final online = ref.watch(onlineStatusProvider).asData?.value ?? true;
    final count = ref.watch(pendingSyncCountProvider).asData?.value ?? 0;
    final lastSyncFailed =
        ref.watch(syncOutcomeProvider).asData?.value.isFailure ?? false;

    if (count == 0) return const SizedBox.shrink();

    final canRetry = online;
    final IconData icon;
    final String label;
    final String tooltip;
    if (!online) {
      icon = Icons.cloud_off_outlined;
      label = 'offline · $count';
      tooltip =
          "You're offline — $count change${count == 1 ? '' : 's'} waiting to sync";
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
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Icon(icon, size: 14, color: tokens.textSecondary),
              Text(
                label,
                textAlign: TextAlign.center,
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
