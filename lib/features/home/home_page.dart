import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../core/graph.dart';
import '../../core/strings.dart';
import '../../models/course/course.dart';
import '../../ui/breakpoints.dart';
import '../../ui/card/tonal_card.dart';
import '../../ui/widget/content_section.dart';
import '../../ui/widget/empty_state_widget.dart';
import '../../utils/date_x.dart';

/// 首页：今天的时间轴 + 快捷入口。
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onOpenTab});

  final ValueChanged<int>? onOpenTab;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _graph = AppGraph.instance;

  @override
  void initState() {
    super.initState();
    _graph.home.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final pad = Breakpoints.pagePadding(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            _graph.home.refresh();
            await _graph.auth.refreshSession();
          },
          child: Observer(
            builder: (_) {
              final now = _graph.home.now.value;
              return ListView(
                padding: EdgeInsets.fromLTRB(pad, 12, pad, 96),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _Greeting(now: now, week: _graph.home.week.value),
                  if (!_graph.auth.loggedIn) ...[
                    const SizedBox(height: 16),
                    _LoginPrompt(onTap: () => context.pushNamed('/login')),
                  ],
                  const ContentSection(
                    title: S.todayTimeline,
                    padding: EdgeInsets.fromLTRB(0, 24, 0, 10),
                  ),
                  _Timeline(courses: _graph.home.todayCourses, now: now),
                  const ContentSection(
                    title: S.quickAccess,
                    padding: EdgeInsets.fromLTRB(0, 24, 0, 10),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickCard(
                          icon: Icons.credit_card_outlined,
                          label: S.campusCard,
                          value: S.balanceUnknown,
                          onTap: () => widget.onOpenTab?.call(3),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickCard(
                          icon: Icons.bolt_outlined,
                          label: S.electricity,
                          value: S.balanceUnknown,
                          onTap: () => widget.onOpenTab?.call(3),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickCard(
                          icon: Icons.timer_outlined,
                          label: S.focusToday,
                          value:
                              '${_graph.home.focusMinutesToday.value} ${S.minuteUnit}',
                          highlight: _graph.home.focusMinutesToday.value > 0,
                          onTap: () => widget.onOpenTab?.call(2),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.now, required this.week});

  final DateTime now;
  final int week;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateX.greeting(now),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateX.fullDate(now),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${S.weekPrefix}$week${S.weekSuffix}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return TonalCard(
      color: scheme.primaryContainer,
      onTap: onTap,
      child: Row(
        children: [
          Icon(Icons.key_rounded, color: scheme.onPrimaryContainer, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.loginRequiredTitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  S.loginRequiredBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.82),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onPrimaryContainer),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.courses, required this.now});

  final List<Course> courses;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return const TonalCard(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: EmptyStateWidget(
          icon: Icons.wb_sunny_outlined,
          message: S.todayNoCourse,
        ),
      );
    }

    return TonalCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          for (var i = 0; i < courses.length; i++)
            _TimelineRow(
              course: courses[i],
              now: now,
              isLast: i == courses.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.course,
    required this.now,
    required this.isLast,
  });

  final Course course;
  final DateTime now;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = course.isNow(now);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.timeRange.split('-').first,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: active ? scheme.primary : scheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  course.timeRange.split('-').last,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? scheme.primary : scheme.outlineVariant,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  margin: const EdgeInsets.only(top: 2),
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: active ? scheme.primaryContainer : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: active ? scheme.onPrimaryContainer : null,
                    ),
                  ),
                  if (course.location.isNotEmpty || course.teacher.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        [
                          if (course.location.isNotEmpty) course.location,
                          if (course.teacher.isNotEmpty) course.teacher,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: active
                              ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                              : scheme.onSurfaceVariant,
                        ),
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

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return TonalCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: highlight ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: highlight ? scheme.primary : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
