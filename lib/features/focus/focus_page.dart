import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';

import '../../core/graph.dart';
import '../../core/strings.dart';
import '../../ui/card/tonal_card.dart';
import '../../ui/widget/content_section.dart';
import '../../ui/widget/empty_state_widget.dart';
import '../../utils/date_x.dart';
import 'focus_controller.dart';

/// 专注：计时引擎 + 统计 + 记录。
class FocusPage extends StatefulWidget {
  const FocusPage({super.key});

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  final _graph = AppGraph.instance;
  late final ReactionDisposer _finishReaction;

  @override
  void initState() {
    super.initState();
    _finishReaction = reaction<int>(
      (_) => _graph.focus.finishTick.value,
      (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text(S.focusFinished)));
      },
    );
  }

  @override
  void dispose() {
    _finishReaction();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Observer(
          builder: (_) {
            final focus = _graph.focus;
            final running = focus.running.value;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                Text(
                  S.focusTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TonalCard(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      _Ring(
                        progress: focus.progress,
                        active: running,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatSeconds(
                                running
                                    ? focus.remainingSeconds
                                    : focus.targetMinutes.value * 60,
                              ),
                              style: theme.textTheme.displaySmall?.copyWith(
                                fontSize: 40,
                                fontWeight: FontWeight.w300,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              running
                                  ? (focus.paused.value
                                      ? S.focusPaused
                                      : S.focusRunning)
                                  : S.focusIdle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: running
                                  ? OutlinedButton(
                                      onPressed: () => focus.stop(),
                                      child: const Text(S.focusStop),
                                    )
                                  : FilledButton(
                                      onPressed: () => focus.start(),
                                      child: const Text(S.focusStart),
                                    ),
                            ),
                            if (running) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed: () => focus.paused.value
                                      ? focus.resume()
                                      : focus.pause(),
                                  child: Text(
                                    focus.paused.value
                                        ? S.focusResume
                                        : S.focusPause,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (!running) ...[
                  Text(
                    '标签',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final tag in FocusController.tags)
                        ChoiceChip(
                          label: Text(tag),
                          selected: focus.tag.value == tag,
                          onSelected: (_) => focus.setTag(tag),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '时长',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final minutes in FocusController.presetMinutes)
                        ChoiceChip(
                          label: Text('$minutes 分钟'),
                          selected: focus.targetMinutes.value == minutes,
                          onSelected: (_) => focus.setTarget(minutes),
                        ),
                    ],
                  ),
                ],
                const ContentSection(
                  title: S.focusTodayTitle,
                  padding: EdgeInsets.fromLTRB(0, 24, 0, 10),
                ),
                TonalCard(
                  child: Row(
                    children: [
                      _Stat(
                        value: '${focus.todayMinutes.value}',
                        unit: S.minuteUnit,
                        label: S.focusTodayTitle,
                      ),
                      Container(
                        width: 0.6,
                        height: 36,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      _Stat(
                        value: '${focus.weekMinutes.value}',
                        unit: S.minuteUnit,
                        label: '本周累计',
                      ),
                      Container(
                        width: 0.6,
                        height: 36,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      _Stat(
                        value: '${focus.sessions.length}',
                        unit: '次',
                        label: '总记录',
                      ),
                    ],
                  ),
                ),
                const ContentSection(
                  title: S.focusWeekTitle,
                  padding: EdgeInsets.fromLTRB(0, 24, 0, 10),
                ),
                TonalCard(child: _WeekBars(values: focus.last7)),
                const ContentSection(
                  title: S.focusRecords,
                  padding: EdgeInsets.fromLTRB(0, 24, 0, 10),
                ),
                if (focus.sessions.isEmpty)
                  const TonalCard(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: EmptyStateWidget(
                      icon: Icons.local_fire_department_outlined,
                      message: S.noFocusRecord,
                    ),
                  )
                else
                  TonalCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        for (final session
                            in focus.sessions.take(10).toList())
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  DateX.monthDay(session.startedAt),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  DateX.hhmm(session.startedAt),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    session.tag,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                                Text(
                                  '${session.minutes} ${S.minuteUnit}',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _formatSeconds(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.progress,
    required this.active,
    required this.child,
  });

  final double progress;
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 216,
      height: 216,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          color: active ? scheme.primary : scheme.outline,
          trackColor: scheme.surfaceContainerHighest,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.unit, required this.label});

  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxValue = values.fold<int>(1, (a, b) => math.max(a, b));
    final today = DateTime.now();

    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    values[i] == 0 ? '' : '${values[i]}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    height: 8 +
                        (values[i] / maxValue) *
                            62,
                    decoration: BoxDecoration(
                      color: i == values.length - 1
                          ? scheme.primary
                          : scheme.primary.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateX.weekday(
                      today.subtract(Duration(days: 6 - i)).weekday,
                    ).replaceFirst('周', ''),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
