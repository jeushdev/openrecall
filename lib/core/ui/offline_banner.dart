import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_motion.dart';
import '../../theme/app_tokens.dart';
import '../connectivity/connectivity_service.dart';

/// The app-wide "you're offline" strip (design spec §E.1).
///
/// Persistent but unobtrusive: a hairline bar above the tab content, never a
/// dialog, a snackbar or anything that has to be dismissed. It states a fact —
/// the `SyncStatusChip` on the Decks tab is what counts queued writes.
///
/// Collapses to nothing while online, and defaults to hidden until connectivity
/// resolves so it cannot flash on a cold start. Expand/collapse uses the shared
/// [AppMotion] disclosure timing so it reads as part of the same motion system
/// as the Settings sections and tab slide.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final online = ref.watch(onlineStatusProvider).asData?.value ?? true;

    return AnimatedSize(
      duration: AppMotion.expandDuration,
      curve: AppMotion.expandCurve,
      alignment: Alignment.topCenter,
      child: online
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: tokens.mutedFill,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_outlined,
                      size: 14, color: tokens.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    "You're offline",
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
