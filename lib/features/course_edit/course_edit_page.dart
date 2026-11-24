import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../core/graph.dart';
import '../../core/strings.dart';
import '../../models/course/course.dart';
import '../../models/course/period.dart';
import '../../ui/appbar/sys_app_bar.dart';
import '../../ui/card/tonal_card.dart';
import '../../utils/date_x.dart';
import '../../utils/id_x.dart';

/// 新建 / 编辑一门课。UI 上不引下拉菜单，用小块选择器，窄屏也好点。
class CourseEditPage extends StatefulWidget {
  const CourseEditPage({super.key});

  @override
  State<CourseEditPage> createState() => _CourseEditPageState();
}

class _CourseEditPageState extends State<CourseEditPage> {
  final _graph = AppGraph.instance;

  final _name = TextEditingController();
  final _teacher = TextEditingController();
  final _location = TextEditingController();

  late String _courseId;
  int _weekday = 1;
  int _startPeriod = 1;
  int _endPeriod = 2;
  int _startWeek = 1;
  int _endWeek = 18;
  int _colorSeed = 0;

  bool get _isNew => _courseId.isEmpty;

  @override
  void initState() {
    super.initState();
    _courseId = _graph.navArgs.courseId;
    final existing =
        _courseId.isEmpty ? null : _graph.courseRepository.byId(_courseId);
    if (existing != null) {
      _name.text = existing.name;
      _teacher.text = existing.teacher;
      _location.text = existing.location;
      _weekday = existing.weekday;
      _startPeriod = existing.startPeriod;
      _endPeriod = existing.endPeriod;
      _startWeek = existing.startWeek;
      _endWeek = existing.endWeek;
      _colorSeed = existing.colorSeed;
    } else {
      _weekday = DateTime.now().weekday;
      _colorSeed = _graph.schedule.courses.length % 7;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _teacher.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast('先给这门课起个名字');
      return;
    }
    if (_endPeriod < _startPeriod) {
      _toast('结束节次要大于等于起始节次');
      return;
    }
    if (_endWeek < _startWeek) {
      _toast('结束周要大于等于起始周');
      return;
    }

    await _graph.schedule.save(
      Course(
        id: _isNew ? newId() : _courseId,
        name: name,
        teacher: _teacher.text.trim(),
        location: _location.text.trim(),
        weekday: _weekday,
        startPeriod: _startPeriod,
        endPeriod: _endPeriod,
        startWeek: _startWeek,
        endWeek: _endWeek,
        colorSeed: _colorSeed,
        custom: true,
      ),
    );
    if (!mounted) return;
    _toast(S.courseSaved);
    context.pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(S.deleteCourseTitle),
        content: const Text(S.deleteCourseBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(S.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _graph.schedule.delete(_courseId);
    if (!mounted) return;
    context.pop();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SysAppBar(
        title: _isNew ? S.addCourse : S.editCourse,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          if (!_isNew)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: S.delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TonalCard(
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: S.courseName,
                    hintText: '例如：民航概论',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _teacher,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: S.courseTeacher),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _location,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: S.courseLocation),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            S.courseWeekday,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var day = 1; day <= 7; day++)
                ChoiceChip(
                  label: Text(DateX.weekday(day)),
                  selected: _weekday == day,
                  onSelected: (_) => setState(() => _weekday = day),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _NumberStepper(
                  label: '开始节次',
                  value: _startPeriod,
                  min: 1,
                  max: Period.count,
                  hint: Period.byIndex(_startPeriod).startLabel,
                  onChanged: (v) => setState(() {
                    _startPeriod = v;
                    if (_endPeriod < v) _endPeriod = v;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberStepper(
                  label: '结束节次',
                  value: _endPeriod,
                  min: _startPeriod,
                  max: Period.count,
                  hint: Period.byIndex(_endPeriod).endLabel,
                  onChanged: (v) => setState(() => _endPeriod = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _NumberStepper(
                  label: '起始周',
                  value: _startWeek,
                  min: 1,
                  max: 20,
                  onChanged: (v) => setState(() {
                    _startWeek = v;
                    if (_endWeek < v) _endWeek = v;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberStepper(
                  label: '结束周',
                  value: _endWeek,
                  min: _startWeek,
                  max: 20,
                  onChanged: (v) => setState(() => _endWeek = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '颜色',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              for (var i = 0; i < 7; i++)
                GestureDetector(
                  onTap: () => setState(() => _colorSeed = i),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _colorSeed == i
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const [
                          Color(0xFF4F86F7),
                          Color(0xFF2FB8A6),
                          Color(0xFFE0A33E),
                          Color(0xFFB06AE0),
                          Color(0xFFE06A8B),
                          Color(0xFF5AA96A),
                          Color(0xFF7A8BA8),
                        ][i],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton(onPressed: _save, child: const Text(S.save)),
        ],
      ),
    );
  }
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final String? hint;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return TonalCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: value > min ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove_rounded, size: 18),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$value',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (hint != null)
                      Text(
                        hint!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: value < max ? () => onChanged(value + 1) : null,
                icon: const Icon(Icons.add_rounded, size: 18),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
