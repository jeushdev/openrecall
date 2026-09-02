import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_tokens.dart';
import '../../../theme/app_type.dart';
import '../../../ui/settings/settings_segmented_control.dart';
import '../../../ui/stats/calendar_heatmap.dart';
import '../../../ui/stats/session_log_list.dart';
import '../application/stats_providers.dart';

/// The History tab (`/history`, ui-spec-v4-navigation §4) — replaces the retired
/// Mastery tab.
///
/// Top to bottom: a month calendar heatmap of study activity, an All / By Deck
/// toggle, and the merged session log. Every value comes from a provider that
/// degrades cleanly offline; nothing here is on the study path. `CourseRollupStrip`
/// is dropped per §4 — its information is implicit in the By Deck grouping.
class HistoryTabScreen extends ConsumerStatefulWidget {
  const HistoryTabScreen({super.key});

  @override
  ConsumerState<HistoryTabScreen> createState() => _HistoryTabScreenState();
}

class _HistoryTabScreenState extends ConsumerState<HistoryTabScreen> {
  late DateTime _visibleMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  HistoryFilter _filter = HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final activity = ref.watch(dailyActivityProvider);
    final log = ref.watch(historyLogProvider);

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Text(
              'History',
              style: AppType.headline.copyWith(color: tokens.textPrimary),
            ),
            const SizedBox(height: 20),

            _AsyncSection(
              value: activity,
              onRetry: () => ref.invalidate(dailyActivityProvider),
              builder: (counts) => CalendarHeatmap(
                counts: counts,
                visibleMonth: _visibleMonth,
                onMonthChanged: (m) => setState(() => _visibleMonth = m),
              ),
            ),
            const SizedBox(height: 28),

            SettingsSegmentedControl<HistoryFilter>(
              value: _filter,
              onChanged: (f) => setState(() => _filter = f),
              options: const [
                (value: HistoryFilter.all, label: 'All'),
                (value: HistoryFilter.byDeck, label: 'By Deck'),
              ],
            ),
            const SizedBox(height: 16),

            _AsyncSection(
              value: log,
              onRetry: () => ref.invalidate(historyLogProvider),
              builder: (entries) =>
                  SessionLogList(entries: entries, filter: _filter),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders [builder] once [value] has data; a static placeholder while it loads
/// and a one-line retry affordance if it errors — a dashboard shouldn't spin,
/// and an animating indicator would keep the widget tester from settling.
class _AsyncSection<T> extends StatelessWidget {
  const _AsyncSection({
    required this.value,
    required this.onRetry,
    required this.builder,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return value.when(
      data: builder,
      loading: () => Container(
        height: 120,
        decoration: BoxDecoration(
          color: tokens.mutedFill,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      error: (_, _) => Row(
        children: [
          Expanded(
            child: Text(
              "Couldn't load this section.",
              style: AppType.body.copyWith(color: tokens.textSecondary),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
