import 'package:flutter/material.dart';

import '../../core/format/mastery_delta_label.dart';
import '../../features/decks/domain/study_mode.dart';
import '../../features/stats/domain/history_log.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_type.dart';
import '../common/ios_list.dart';

/// Which way the History tab's session log is arranged (ui-spec-v4 §4).
enum HistoryFilter { all, byDeck }

/// The History tab's session log (ui-spec-v5 §6.5): completed study sessions,
/// newest first, laid out as grouped-inset [IosSection]s. In [HistoryFilter.all]
/// each section is a calendar day (its date as the header) holding one [IosRow]
/// per session; in [HistoryFilter.byDeck] each section is a deck. Every row shows
/// a mode-tinted [IosRowIcon] in the course accent, a title, and the run's
/// mastery delta as the trailing value.
///
/// [entries] is `historyLogProvider`'s value — already joined and sorted.
class SessionLogList extends StatelessWidget {
  const SessionLogList({
    super.key,
    required this.entries,
    required this.filter,
  });

  final List<HistoryEntry> entries;
  final HistoryFilter filter;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          'Your completed study sessions will show up here.',
          style: AppType.body.copyWith(color: tokens.textSecondary),
        ),
      );
    }

    final sections = filter == HistoryFilter.all
        ? _dayGroups(entries)
        : [
            for (final group in groupHistoryByDeck(entries))
              (
                header: group.courseName == null
                    ? group.deckName
                    : '${group.courseName} · ${group.deckName}',
                entries: group.entries,
                showDeckName: false,
              ),
          ];

    return Column(
      children: [
        for (final section in sections) ...[
          IosSection(
            header: section.header,
            children: [
              for (final entry in section.entries)
                _LogRow(entry: entry, showDeckName: section.showDeckName),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

typedef _LogSection = ({
  String header,
  List<HistoryEntry> entries,
  bool showDeckName,
});

/// Folds the flat (newest-first) [entries] into one section per calendar day,
/// the day rendered as its date.
List<_LogSection> _dayGroups(List<HistoryEntry> entries) {
  final order = <DateTime>[];
  final byDay = <DateTime, List<HistoryEntry>>{};
  for (final entry in entries) {
    final day = DateTime(
      entry.completedAt.year,
      entry.completedAt.month,
      entry.completedAt.day,
    );
    byDay
        .putIfAbsent(day, () {
          order.add(day);
          return <HistoryEntry>[];
        })
        .add(entry);
  }
  return [
    for (final day in order)
      (header: _dayLabel(day), entries: byDay[day]!, showDeckName: true),
  ];
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _dayLabel(DateTime day, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final daysApart = today.difference(day).inDays;
  if (daysApart == 0) return 'Today';
  if (daysApart == 1) return 'Yesterday';
  final base = '${_monthNames[day.month - 1]} ${day.day}';
  return day.year == current.year ? base : '$base, ${day.year}';
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry, required this.showDeckName});

  final HistoryEntry entry;
  final bool showDeckName;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final accent = tokens.accent(entry.accentColor);
    final delta = entry.masteryDelta;

    final detail = StringBuffer(_modeLabel(entry.studyMode));
    if (entry.cardsReviewed case final n?) {
      detail.write(' · $n card${n == 1 ? '' : 's'}');
    }

    return IosRow(
      leading: IosRowIcon(icon: _modeIcon(entry.studyMode), color: accent.fill),
      title: showDeckName ? entry.deckName : detail.toString(),
      trailing: Wrap(
        spacing: 8,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (showDeckName)
            Text(
              detail.toString(),
              style: AppType.caption.copyWith(color: tokens.textSecondary),
            ),
          if (delta != null) ...[
            Text(
              masteryDeltaLabel(delta),
              style: AppType.caption.copyWith(
                color: tokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _modeLabel(StudyMode mode) => switch (mode) {
    StudyMode.flip => 'Flip',
    StudyMode.cloze => 'Cloze',
    StudyMode.feynman => 'Feynman',
  };

  static IconData _modeIcon(StudyMode mode) => switch (mode) {
    StudyMode.flip => Icons.style_outlined,
    StudyMode.cloze => Icons.keyboard_outlined,
    StudyMode.feynman => Icons.mic_none_outlined,
  };
}
