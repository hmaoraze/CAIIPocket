import 'package:flutter/material.dart';

import '../../../models/course/course.dart';
import '../../../models/course/period.dart';
import '../../../utils/date_x.dart';

/// 一周网格：左节次栏 + 7 天列，课程块按起止节次定位。
class WeekGrid extends StatelessWidget {
  const WeekGrid({
    super.key,
    required this.week,
    required this.coursesByDay,
    required this.dateOfDay,
    required this.onTapCourse,
  });

  final int week;
  final Map<int, List<Course>> coursesByDay;
  final DateTime Function(int weekday) dateOfDay;
  final void Function(Course course) onTapCourse;

  static const double cellHeight = 56;
  static const double gutter = 26;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: gutter, right: 4, bottom: 4),
          child: Row(
            children: [
              for (var day = 1; day <= 7; day++)
                Expanded(
                  child: _DayHeader(
                    weekday: day,
                    date: dateOfDay(day),
                    isToday: DateX.dateKey(dateOfDay(day)) ==
                        DateX.dateKey(today),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 110),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: gutter,
                  child: Column(
                    children: [
                      for (final p in Period.table)
                        SizedBox(
                          height: cellHeight,
                          child: Center(
                            child: Text(
                              '${p.index}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                for (var day = 1; day <= 7; day++)
                  Expanded(
                    child: _DayColumn(
                      courses: coursesByDay[day] ?? const [],
                      onTapCourse: onTapCourse,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.weekday,
    required this.date,
    required this.isToday,
  });

  final int weekday;
  final DateTime date;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: isToday ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            DateX.weekday(weekday).replaceFirst('周', ''),
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 11,
              color: isToday ? scheme.onPrimaryContainer : scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            DateX.monthDay(date),
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9,
              color: isToday
                  ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                  : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.courses, required this.onTapCourse});

  final List<Course> courses;
  final void Function(Course course) onTapCourse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final line = scheme.outlineVariant.withValues(alpha: 0.4);
    return SizedBox(
      height: Period.count * WeekGrid.cellHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                for (var i = 0; i < Period.count; i++)
                  Container(
                    height: WeekGrid.cellHeight,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: line, width: 0.6),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final course in courses)
            Positioned(
              top: (course.startPeriod - 1) * WeekGrid.cellHeight + 2,
              height: course.spanPeriods * WeekGrid.cellHeight - 4,
              left: 1,
              right: 1,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onTapCourse(course),
                child: _CourseTile(course: course),
              ),
            ),
        ],
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  const _CourseTile({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const palette = [
      Color(0xFF4F86F7),
      Color(0xFF2FB8A6),
      Color(0xFFE0A33E),
      Color(0xFFB06AE0),
      Color(0xFFE06A8B),
      Color(0xFF5AA96A),
      Color(0xFF7A8BA8),
    ];
    final accent = palette[course.colorSeed.abs() % palette.length];
    final dark = scheme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: dark ? 0.3 : 0.18),
          scheme.surfaceContainerHigh,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(5, 4, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            course.name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10.5,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const Spacer(),
          if (course.location.isNotEmpty)
            Text(
              course.location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
