import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/application/settings_providers.dart';
import '../../features/settings/application/settings_sections_expansion.dart';
import '../../features/settings/data/study_appearance_preferences.dart';
import '../../features/settings/presentation/widgets/delete_account_dialog.dart';
import '../../features/study/application/feynman_timer_providers.dart';
import '../../theme/app_tokens.dart';
import 'collapsible_settings_section.dart';
import 'feedback_info_dialog.dart';
import 'settings_segmented_control.dart';

// Stable ids for the collapsible sections — decoupled from the display titles
// so a copy change never silently resets a section's expand state.
const _kAppearance = 'appearance';
const _kStudyAppearance = 'study_appearance';
const _kFeynman = 'feynman';
const _kNotifications = 'notifications';
const _kGeneral = 'general';
const _kAccount = 'account';

/// The Settings screen (`/settings`, ui-spec-v1 §6.5).
///
/// "Study appearance" segmented toggles (persisted to `SharedPreferences` via
/// `studyAppearanceProvider`), a "Feynman mode" row that surfaces the last-used
/// timer preset as information only, and a "General" section with feedback and
/// about.
///
/// It also carries the account-scoped controls that have no home on the More
/// tab: the study-reminders toggle and the destructive "Delete account" flow.
/// "Delete account" deliberately lives only here, behind a type-`DELETE`
/// confirmation, and is never mirrored onto More (ui-spec-v4-navigation §5).
///
/// No longer a shell branch (ui-spec-v4-navigation §2) — a pushed route reached
/// from `MoreTabScreen`. The sections never remember their expand state: every
/// entry collapses them all (milestone A), done here in [initState] now that
/// there is no branch navigation for `ScaffoldWithNavBar` to hook.
class SettingsTabScreen extends ConsumerStatefulWidget {
  const SettingsTabScreen({super.key});

  @override
  ConsumerState<SettingsTabScreen> createState() => _SettingsTabScreenState();
}

class _SettingsTabScreenState extends ConsumerState<SettingsTabScreen> {
  @override
  void initState() {
    super.initState();
    // Deferred a frame: mutating a provider synchronously during `initState`
    // throws while the tree is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(settingsSectionsExpansionProvider.notifier).collapseAll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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

    final tokens = Theme.of(context).extension<AppTokens>()!;
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
    final expanded = ref.watch(settingsSectionsExpansionProvider);
    final sections = ref.read(settingsSectionsExpansionProvider.notifier);

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Text(
              'Settings',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            CollapsibleSettingsSection(
              title: 'Appearance',
              expanded: expanded.contains(_kAppearance),
              onToggle: () => sections.toggle(_kAppearance),
              children: [
                _AppearanceRow(
                  label: 'Theme',
                  caption: 'Follow the system setting, or force light or dark.',
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

            CollapsibleSettingsSection(
              title: 'Study appearance',
              expanded: expanded.contains(_kStudyAppearance),
              onToggle: () => sections.toggle(_kStudyAppearance),
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
                const SizedBox(height: 20),
                _AppearanceRow(
                  label: 'Progress indicator',
                  caption: 'The bar at the top of a study session.',
                  child: SettingsSegmentedControl<ProgressIndicatorStyle>(
                    value: appearance.progressIndicator,
                    onChanged: controller.setProgressIndicator,
                    options: const [
                      (value: ProgressIndicatorStyle.hairline, label: 'Hairline'),
                      (value: ProgressIndicatorStyle.pill, label: 'Pill'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
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

            CollapsibleSettingsSection(
              title: 'Feynman mode',
              expanded: expanded.contains(_kFeynman),
              onToggle: () => sections.toggle(_kFeynman),
              children: [
                Text(
                  switch (lastFeynman.asData?.value) {
                    null => "You haven't timed a Feynman session yet.",
                    final s => 'Last used timer: ${s}s. You pick this again at '
                        'the start of each Feynman session.',
                  },
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Local notifications can't fire from a hosted web page
            // (spec-web-mvp §5.3), so the section is absent on web entirely.
            if (!kIsWeb) ...[
              CollapsibleSettingsSection(
                title: 'Notifications',
                expanded: expanded.contains(_kNotifications),
                onToggle: () => sections.toggle(_kNotifications),
                children: [
                  _ToggleRow(
                    label: 'Study reminders',
                    caption: 'Nudge me a few hours after I leave cards '
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

            CollapsibleSettingsSection(
              title: 'General',
              expanded: expanded.contains(_kGeneral),
              onToggle: () => sections.toggle(_kGeneral),
              children: [
                _LinkRow(
                  label: 'Send feedback',
                  onTap: () => showFeedbackInfo(context),
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: tokens.borderHairline,
                ),
                _InfoRow(
                  label: 'About',
                  value: version.when(
                    data: (v) => v,
                    loading: () => '…',
                    error: (_, _) => 'unknown',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            CollapsibleSettingsSection(
              title: 'Account',
              expanded: expanded.contains(_kAccount),
              onToggle: () => sections.toggle(_kAccount),
              children: [
                _DangerRow(
                  label: 'Delete account',
                  caption: 'Permanently removes your account and every deck, '
                      'card and session tied to it.',
                  onTap: accountBusy ? null : () => _confirmDelete(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await DeleteAccountDialog.show(context);
    if (confirmed != true) return;
    await ref.read(accountActionsProvider.notifier).deleteAccount();
  }
}

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
    return Column(
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
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 15, color: tokens.textPrimary),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: tokens.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 15, color: tokens.textPrimary),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 13, color: tokens.textSecondary),
          ),
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
    return Row(
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
    );
  }
}

/// A destructive tappable row: label + caption in the fixed `red` accent, with
/// a trailing chevron. A null [onTap] renders it dimmed (while an action runs).
class _DangerRow extends StatelessWidget {
  const _DangerRow({
    required this.label,
    required this.caption,
    required this.onTap,
  });

  final String label;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final red = tokens.accent('red').text;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
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
                        color: red,
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
              Icon(Icons.chevron_right, size: 20, color: red),
            ],
          ),
        ),
      ),
    );
  }
}
