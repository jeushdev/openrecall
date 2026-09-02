import 'package:flutter/material.dart';

import '../../features/stats/domain/daily_activity.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_type.dart';

/// The History tab's month calendar heatmap (ui-spec-v4 §4): a 7-column grid of
/// the visible month's days, each cell shaded on a 0–[maxHeatLevel] ramp of the
/// study accent by that day's completed-session count. Prev/next chevrons page
/// the month; only the current and past months have data, and the "next"
/// chevron is disabled once the visible month is the current one.
///
/// [counts] is `dailyActivityProvider`'s value — a map keyed by date-only
/// `DateTime`s. Stateless on purpose; the visible month lives in the parent.
class CalendarHeatmap extends StatelessWidget {
  const CalendarHeatmap({
    super.key,
    required this.counts,
    required this.visibleMonth,
    required this.onMonthChanged,
    this.today,
  });

  final Map<DateTime, int> counts;

  /// Any day in the month to show — normalised to the first of the month here.
  final DateTime visibleMonth;
  final ValueChanged<DateTime> onMonthChanged;

  /// Overridable for tests; defaults to [DateTime.now].
  final DateTime? today;

  static const List<String> _weekdayLabels = [
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final accent = tokens.accent('teal');
    final now = today ?? DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final month = DateTime(visibleMonth.year, visibleMonth.month);
    final canGoForward = month.isBefore(currentMonth);

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Dart weekday: Mon = 1 … Sun = 7. Leading blanks before the 1st.
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _monthLabel(month),
                style: AppType.title.copyWith(color: tokens.textPrimary),
              ),
            ),
            _Chevron(
              icon: Icons.chevron_left,
              onTap: () => onMonthChanged(
                DateTime(month.year, month.month - 1),
              ),
              tokens: tokens,
            ),
            _Chevron(
              icon: Icons.chevron_right,
              onTap: canGoForward
                  ? () => onMonthChanged(DateTime(month.year, month.month + 1))
                  : null,
              tokens: tokens,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: AppType.overline.copyWith(color: tokens.textTertiary),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
          children: [
            for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
            for (var day = 1; day <= daysInMonth; day++)
              _DayCell(
                day: day,
                level: heatLevel(
                  counts[DateTime(month.year, month.month, day)] ?? 0,
                ),
                isFuture: DateTime(month.year, month.month, day)
                    .isAfter(DateTime(now.year, now.month, now.day)),
                accent: accent,
                tokens: tokens,
              ),
          ],
        ),
      ],
    );
  }

  static String _monthLabel(DateTime month) {
    const names = [
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
    return '${names[month.month - 1]} ${month.year}';
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.icon, required this.onTap, required this.tokens});

  final IconData icon;
  final VoidCallback? onTap;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        size: 22,
        color: onTap == null ? tokens.textTertiary : tokens.textSecondary,
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.level,
    required this.isFuture,
    required this.accent,
    required this.tokens,
  });

  final int day;
  final int level;
  final bool isFuture;
  final AccentPair accent;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    // Level 0 sits on the muted track; 1–4 ramp the accent fill's opacity.
    final Color fill;
    if (isFuture) {
      fill = Colors.transparent;
    } else if (level == 0) {
      fill = tokens.mutedFill;
    } else {
      fill = accent.fill.withValues(alpha: 0.25 + 0.2 * level);
    }

    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(7),
        border: isFuture
            ? Border.all(color: tokens.borderHairline, width: 0.5)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '$day',
        style: AppType.caption.copyWith(
          color: level >= 3 ? tokens.background : tokens.textTertiary,
          fontSize: 11,
        ),
      ),
    );
  }
}
