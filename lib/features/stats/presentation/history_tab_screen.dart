import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/application_cache.dart';
import '../../../theme/app_tokens.dart';
import '../../../theme/app_type.dart';
import '../../../ui/common/large_title_scaffold.dart';
import '../../../ui/settings/settings_segmented_control.dart';
import '../../../ui/stats/calendar_heatmap.dart';
import '../../../ui/stats/session_log_list.dart';
import '../application/stats_providers.dart';
import '../data/local_stats_store.dart';

/// The History tab (`/history`, ui-spec-v4-navigation §4, restyled ui-spec-v5
/// §6.5) — replaces the retired Mastery tab.
///
/// A large-title shell over: a month calendar heatmap of study activity, an
/// All / By Deck toggle, and the merged session log rendered as grouped-inset
/// sections. Every value comes from a provider that degrades cleanly offline;
/// nothing here is on the study path. `CourseRollupStrip` is dropped per §4 —
/// its information is implicit in the By Deck grouping.
class HistoryTabScreen extends ConsumerStatefulWidget {
  const HistoryTabScreen({super.key});

  @override
  ConsumerState<HistoryTabScreen> createState() => _HistoryTabScreenState();
}

class _HistoryTabScreenState extends ConsumerState<HistoryTabScreen> {
  late DateTime _visibleMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  HistoryFilter _filter = HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final activity = ref.watch(dailyActivityProvider);
    final log = ref.watch(historyLogProvider);
    final retry = ref.read(retryHistorySourcesProvider);

    return LargeTitleScaffold(
      title: 'History',
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const _CoverageNotice(),
              _AsyncSection(
                value: activity,
                onRetry: retry,
                builder: (counts) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CalendarHeatmap(
                    counts: counts,
                    visibleMonth: _visibleMonth,
                    onMonthChanged: (m) => setState(() => _visibleMonth = m),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SettingsSegmentedControl<HistoryFilter>(
                  value: _filter,
                  onChanged: (f) => setState(() => _filter = f),
                  options: const [
                    (value: HistoryFilter.all, label: 'All'),
                    (value: HistoryFilter.byDeck, label: 'By Deck'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _AsyncSection(
                value: log,
                onRetry: retry,
                builder: (entries) =>
                    SessionLogList(entries: entries, filter: _filter),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CoverageNotice extends ConsumerWidget {
  const _CoverageNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSessionCacheStateProvider).asData?.value;
    final completed = ref
        .watch(completedSessionCacheStateProvider)
        .asData
        ?.value;
    final states = <SessionCacheState>[?recent, ?completed];
    if (!states.any((state) => state.hasCachedData)) {
      return const SizedBox.shrink();
    }
    final partial = states.any(
      (state) =>
          state.hasCachedData && state.coverage != CacheCoverage.complete,
    );
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text(
        partial
            ? 'Saved history is available offline, but older activity may be missing.'
            : 'Showing saved history while fresh activity is checked.',
        key: const ValueKey('history-cache-coverage'),
        style: AppType.caption.copyWith(color: tokens.textSecondary),
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
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: tokens.mutedFill,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
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
      ),
    );
  }
}
