import 'package:flutter/material.dart';

import '../../features/stats/domain/course_summary.dart';
import '../../theme/app_geometry.dart';
import '../../theme/app_tokens.dart';

/// The horizontally scrolling row of course chips on the Mastery tab
/// (ui-spec-v1 §6.3), sitting between the overall card and "Deck completions"
/// (coarsest-to-finest grouping: overall → course → deck → troublemakers).
///
/// [courses] is `courseSummariesProvider`'s value. Renders nothing when there
/// are no courses.
class CourseRollupStrip extends StatelessWidget {
  const CourseRollupStrip({super.key, required this.courses});

  final List<CourseSummary> courses;

  static const double _chipWidth = 120;
  static const double _chipHeight = 62;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: _chipHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: courses.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _CourseChip(course: courses[i], width: _chipWidth),
      ),
    );
  }
}

class _CourseChip extends StatelessWidget {
  const _CourseChip({required this.course, required this.width});

  final CourseSummary course;
  final double width;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final accent = tokens.accent(course.accentColor);
    final deckLabel = course.deckCount == 1 ? '1 deck' : '${course.deckCount} decks';

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: tokens.cardFill,
        borderRadius: AppRadii.gridTileRadius,
        border: Border.all(
          color: tokens.borderHairline,
          width: AppBorders.hairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Flat 4px left-edge accent bar — the deck tile's left-accent
          // language, simplified for a chip this small (§6.3).
          Container(width: 4, color: accent.fill),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${course.masteryPercent}% · $deckLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
