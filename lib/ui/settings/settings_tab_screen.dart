import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/application/settings_providers.dart';
import '../../features/settings/application/settings_sections_expansion.dart';
import '../../features/settings/data/study_appearance_preferences.dart';
import '../../features/study/application/feynman_timer_providers.dart';
import '../../theme/app_tokens.dart';
import 'collapsible_settings_section.dart';
import 'settings_segmented_control.dart';

// Stable ids for the collapsible sections — decoupled from the display titles
// so a copy change never silently resets a section's expand state.
const _kAppearance = 'appearance';
const _kStudyAppearance = 'study_appearance';
const _kFeynman = 'feynman';
const _kGeneral = 'general';

/// The Settings tab (`/settings`, ui-spec-v1 §6.5).
///
/// "Study appearance" segmented toggles (persisted to `SharedPreferences` via
/// `studyAppearanceProvider`), a "Feynman mode" row that surfaces the last-used
/// timer preset as information only, and a "General" section with feedback and
/// about.
class SettingsTabScreen extends ConsumerWidget {
  const SettingsTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

            CollapsibleSettingsSection(
              title: 'General',
              expanded: expanded.contains(_kGeneral),
              onToggle: () => sections.toggle(_kGeneral),
              children: [
                _LinkRow(
                  label: 'Send feedback',
                  onTap: () => _showFeedbackInfo(context),
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
          ],
        ),
      ),
    );
  }

  void _showFeedbackInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Feedback link coming soon'),
        content: const Text(
          'A form will be shared with beta testers. Thanks for helping test '
          'ActiveRecall.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
