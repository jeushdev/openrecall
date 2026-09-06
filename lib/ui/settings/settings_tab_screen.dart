import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/application/settings_providers.dart';
import '../../features/settings/data/study_appearance_preferences.dart';
import '../../features/settings/presentation/widgets/delete_account_dialog.dart';
import '../../features/study/application/feynman_timer_providers.dart';
import '../../theme/app_tokens.dart';
import '../common/ios_list.dart';
import '../common/large_title_scaffold.dart';
import 'feedback_info_dialog.dart';
import 'settings_segmented_control.dart';

/// The Settings screen (`/settings`, ui-spec-v1 §6.5; rebuilt as iOS grouped
/// lists in ui-spec-v5 §5.3/§6.6).
///
/// Appearance (theme mode), "Study appearance" segmented toggles (persisted to
/// `SharedPreferences` via `studyAppearanceProvider`), a "Feynman mode" row that
/// surfaces the last-used timer preset as information only, notifications, and a
/// "General" section with feedback and about.
///
/// It also carries the account-scoped controls that have no home on the More
/// tab: the study-reminders toggle and the destructive "Delete account" flow.
/// "Delete account" deliberately lives only here, behind a type-`DELETE`
/// confirmation as its own standalone red row at the very bottom, and is never
/// mirrored onto More (ui-spec-v4-navigation §5).
///
/// A pushed route reached from `MoreTabScreen` (ui-spec-v4-navigation §2). iOS
/// grouped settings do not collapse, so the per-section expand/collapse
/// behaviour this screen used to carry (milestone A) is gone.
class SettingsTabScreen extends ConsumerWidget {
  const SettingsTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Surface a failed sign-out / account deletion the same way the old
    // Settings screen did — the action providers hold no value of their own.
    ref.listen(accountActionsProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Something went wrong: $error')),
          );
      }
    });

    final themeMode =
        ref.watch(themeModeProvider).asData?.value ?? ThemeMode.system;
    final themeController = ref.read(themeModeProvider.notifier);
    final appearance =
        ref.watch(studyAppearanceProvider).asData?.value ??
        StudyAppearance.defaults;
    final controller = ref.read(studyAppearanceProvider.notifier);
    final lastFeynman = ref.watch(lastFeynmanTimerProvider);
    final version = ref.watch(appVersionProvider);
    final reminders = ref.watch(notificationsEnabledProvider);
    final accountBusy = ref.watch(accountActionsProvider).isLoading;
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return LargeTitleScaffold(
      title: 'Settings',
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              IosSection(
                header: 'Appearance',
                children: [
                  _AppearanceRow(
                    label: 'Theme',
                    caption:
                        'Follow the system setting, or force light or dark.',
                    child: SettingsSegmentedControl<ThemeMode>(
                      value: themeMode,
                      onChanged: themeController.setThemeMode,
                      options: const [
                        (value: ThemeMode.system, label: 'System'),
                        (value: ThemeMode.light, label: 'Light'),
                        (value: ThemeMode.dark, label: 'Dark'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              IosSection(
                header: 'Study appearance',
                children: [
                  _AppearanceRow(
                    label: 'Card transition',
                    caption: 'How a Flip card reveals its answer.',
                    child: SettingsSegmentedControl<CardTransition>(
                      value: appearance.cardTransition,
                      onChanged: controller.setCardTransition,
                      options: const [
                        (value: CardTransition.flip3d, label: '3D flip'),
                        (value: CardTransition.fade, label: 'Fade & slide'),
                      ],
                    ),
                  ),
                  _AppearanceRow(
                    label: 'Progress indicator',
                    caption: 'The bar at the top of a study session.',
                    child: SettingsSegmentedControl<ProgressIndicatorStyle>(
                      value: appearance.progressIndicator,
                      onChanged: controller.setProgressIndicator,
                      options: const [
                        (
                          value: ProgressIndicatorStyle.hairline,
                          label: 'Hairline',
                        ),
                        (value: ProgressIndicatorStyle.pill, label: 'Pill'),
                      ],
                    ),
                  ),
                  _AppearanceRow(
                    label: 'Card text size',
                    caption: 'Size of the text on study cards.',
                    child: SettingsSegmentedControl<CardFontSize>(
                      value: appearance.cardFontSize,
                      onChanged: controller.setCardFontSize,
                      options: const [
                        (value: CardFontSize.small, label: 'S'),
                        (value: CardFontSize.medium, label: 'M'),
                        (value: CardFontSize.large, label: 'L'),
                        (value: CardFontSize.xlarge, label: 'XL'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              IosSection(
                header: 'Feynman mode',
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      switch (lastFeynman.asData?.value) {
                        null => "You haven't timed a Feynman session yet.",
                        final s =>
                          'Last used timer: ${s}s. You pick this again at '
                              'the start of each Feynman session.',
                      },
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Local notifications can't fire from a hosted web page
              // (spec-web-mvp §5.3), so the section is absent on web entirely.
              if (!kIsWeb) ...[
                IosSection(
                  header: 'Notifications',
                  children: [
                    _ToggleRow(
                      label: 'Study reminders',
                      caption:
                          'Nudge me a few hours after I leave cards '
                          'unfinished or parked.',
                      value: reminders.asData?.value ?? true,
                      onChanged: reminders.isLoading
                          ? null
                          : (v) => ref
                                .read(notificationsEnabledProvider.notifier)
                                .setEnabled(v),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
              ],

              IosSection(
                header: 'General',
                children: [
                  IosRow(
                    title: 'Send feedback',
                    showChevron: true,
                    onTap: () => showFeedbackInfo(context),
                  ),
                  IosRow(
                    title: 'About',
                    trailingValue: version.when(
                      data: (v) => v,
                      loading: () => '…',
                      error: (_, _) => 'unknown',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Standalone, last, red — never mirrored onto More.
              IosSection(
                children: [
                  IosRow(
                    title: 'Delete account',
                    destructive: true,
                    onTap: accountBusy
                        ? null
                        : () => _confirmDelete(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await DeleteAccountDialog.show(context);
    if (confirmed != true) return;
    await ref.read(accountActionsProvider.notifier).deleteAccount();
  }
}

/// A label + caption stack above a full-width control, padded to sit inside an
/// [IosSection] card.
class _AppearanceRow extends StatelessWidget {
  const _AppearanceRow({
    required this.label,
    required this.caption,
    required this.child,
  });

  final String label;
  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: TextStyle(fontSize: 12, color: tokens.textTertiary),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// A labelled switch row, matching [_AppearanceRow]'s label + caption stack.
/// A null [onChanged] renders the switch disabled (while the preference loads).
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.caption,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String caption;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: TextStyle(fontSize: 12, color: tokens.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
