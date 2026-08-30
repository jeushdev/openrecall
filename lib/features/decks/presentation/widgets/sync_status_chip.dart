import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../../theme/app_tokens.dart';

/// The minimal sync-status chip (spec-v4 §O4). Deliberately quiet — ambient
/// status, not an alert:
///
/// - offline               → `☁ offline` (with `· N` when writes are queued)
/// - online, N queued (>0) → `⟳ N`
/// - online, nothing queued → nothing at all
class SyncStatusChip extends ConsumerWidget {
  const SyncStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final online = ref.watch(onlineStatusProvider).asData?.value ?? true;
    final count = ref.watch(pendingSyncCountProvider).asData?.value ?? 0;

    if (online && count == 0) return const SizedBox.shrink();

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
      icon = Icons.sync;
      label = '$count';
      tooltip = '$count change${count == 1 ? '' : 's'} waiting to sync';
    }

    return Tooltip(
      message: tooltip,
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
    );
  }
}
