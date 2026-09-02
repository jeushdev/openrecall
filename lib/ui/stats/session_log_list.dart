import 'package:flutter/material.dart';

import '../../core/format/mastery_delta_label.dart';
import '../../core/format/relative_time.dart';
import '../../features/decks/domain/study_mode.dart';
import '../../features/stats/domain/history_log.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_type.dart';

/// Which way the History tab's session log is arranged (ui-spec-v4 §4).
enum HistoryFilter { all, byDeck }

/// The History tab's session log: completed study sessions, newest first. In
/// [HistoryFilter.all] it's a flat chronological list; in [HistoryFilter.byDeck]
/// the rows are grouped under a per-deck header. Each row shows the deck name
/// (in "All"), the mode + card count, a relative time and the run's mastery
/// delta, with a course-accent left bar.
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
      return Text(
        'Your completed study sessions will show up here.',
        style: AppType.body.copyWith(color: tokens.textSecondary),
      );
    }

    if (filter == HistoryFilter.all) {
      return Column(
        children: [
          for (final entry in entries)
            _LogRow(entry: entry, showDeckName: true),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in groupHistoryByDeck(entries)) ...[
          _GroupHeader(group: group),
          for (final entry in group.entries)
            _LogRow(entry: entry, showDeckName: false),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final HistoryDeckGroup group;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final accent = tokens.accent(group.accentColor);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(
            color: accent.fill,
            borderRadius: BorderRadius.circular(2),
          )),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              group.courseName == null
                  ? group.deckName
                  : '${group.courseName} · ${group.deckName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.label.copyWith(color: tokens.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
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

    final subtitle = StringBuffer(_modeLabel(entry.studyMode));
    if (entry.cardsReviewed case final n?) {
      subtitle.write(' · $n card${n == 1 ? '' : 's'}');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 34,
            margin: const EdgeInsets.only(right: 12, top: 1),
            decoration: BoxDecoration(
              color: accent.fill,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showDeckName)
                  Text(
                    entry.deckName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body.copyWith(color: tokens.textPrimary),
                  ),
                Text(
                  subtitle.toString(),
                  style: AppType.caption.copyWith(color: tokens.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (delta != null) ...[
            _DeltaBadge(delta: delta),
            const SizedBox(width: 8),
          ],
          Text(
            relativeTime(entry.completedAt),
            style: AppType.caption.copyWith(color: tokens.textTertiary),
          ),
        ],
      ),
    );
  }

  static String _modeLabel(StudyMode mode) => switch (mode) {
        StudyMode.flip => 'Flip',
        StudyMode.cloze => 'Cloze',
        StudyMode.feynman => 'Feynman',
      };
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.delta});

  final int delta;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.mutedFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        masteryDeltaLabel(delta),
        style: AppType.caption.copyWith(
          color: tokens.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
