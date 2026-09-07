import 'package:flutter/material.dart';

import '../../../../theme/app_geometry.dart';
import '../../../../theme/app_tokens.dart';
import 'pre_session_picker_layout.dart';

/// The Feynman timer preset picker (ui-spec-v1 §6.2.1).
///
/// Chosen once, at the start of a Feynman session — it applies to every card in
/// that run. Not a per-card setting and not a global Settings default (Settings
/// only ever *shows* the last-used value, U8). Presented right after the mode is
/// picked and before the session queue is built, the same "decided once up
/// front" shape [ModePicker] uses.
class FeynmanTimerPicker extends StatelessWidget {
  const FeynmanTimerPicker({super.key, required this.onSelected});

  /// The four presets, in seconds (§6.2.1). `60` is the default.
  static const List<int> presets = [30, 60, 90, 120];
  static const int defaultSeconds = 60;

  /// Fired with the chosen duration in seconds.
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return PreSessionPickerLayout(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How long for each card?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You get this long to explain the prompt out loud before the '
            'reference is revealed.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: tokens.textSecondary),
          ),
          const SizedBox(height: 24),
          for (final seconds in presets) ...[
            _PresetButton(
              seconds: seconds,
              isDefault: seconds == defaultSeconds,
              onTap: () => onSelected(seconds),
              tokens: tokens,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.seconds,
    required this.isDefault,
    required this.onTap,
    required this.tokens,
  });

  final int seconds;
  final bool isDefault;
  final VoidCallback onTap;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.cardFill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: tokens.borderHairline,
              width: AppBorders.hairline,
            ),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                '${seconds}s',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              if (isDefault)
                Text(
                  'default',
                  style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
