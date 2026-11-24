import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../core/graph.dart';
import '../../core/strings.dart';
import '../../models/course/course.dart';
import '../../ui/widget/empty_state_widget.dart';
import '../../utils/date_x.dart';
import 'widgets/week_grid.dart';

/// 课表：周切换 + 7 天网格 + 自定义课程。
class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final _graph = AppGraph.instance;

  @override
  void initState() {
    super.initState();
    _graph.schedule.load();
  }

  void _openEditor([Course? course]) {
    _graph.navArgs.editCourse(course?.id ?? '');
    context.pushNamed('/course-edit');
  }

  Future<void> _pickSemesterStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _graph.schedule.semesterStart,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      helpText: S.semesterStart,
    );
    if (picked == null) return;
    await _graph.schedule.setSemesterStart(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Observer(
          builder: (_) {
            final controller = _graph.schedule;
            return Column(
              children: [
                _WeekHeader(
                  week: controller.week.value,
                  start: controller.dateOfDay(1),
                  end: controller.dateOfDay(7),
                  isCurrent: controller.isCurrentWeek,
                  onPrev: () => controller.shift(-1),
                  onNext: () => controller.shift(1),
                  onToday: () => controller.goToWeek(controller.currentWeek),
                  onSettings: _pickSemesterStart,
                ),
                Expanded(
                  child: controller.courses.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.event_available_outlined,
                          message: S.noCourseThisWeek,
                          hint: '点右下角「添加课程」，或者先设置开学第一周的周一。',
                        )
                      : WeekGrid(
                          week: controller.week.value,
                          coursesByDay: {
                            for (var day = 1; day <= 7; day++)
                              day: controller.dayCourses(day),
                          },
                          dateOfDay: controller.dateOfDay,
                          onTapCourse: _openEditor,
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text(S.addCourse),
      ),
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.week,
    required this.start,
    required this.end,
    required this.isCurrent,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onSettings,
  });

  final int week;
  final DateTime start;
  final DateTime end;
  final bool isCurrent;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${S.weekPrefix}$week${S.weekSuffix}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${DateX.monthDay(start)} - ${DateX.monthDay(end)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (!isCurrent)
            TextButton(
              onPressed: onToday,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text(S.thisWeek),
            ),
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: '上一周',
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: '下一周',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune_rounded, size: 20),
            onSelected: (value) {
              if (value == 'import') {
                context.pushNamed('/import');
                return;
              }
              onSettings();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'start',
                child: Text(S.semesterStart),
              ),
              PopupMenuItem(
                value: 'import',
                child: Text(S.importTitle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
