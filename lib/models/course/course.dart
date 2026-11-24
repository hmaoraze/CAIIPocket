import 'period.dart';

/// 一门课（本地实体）。weekday 1=周一 … 7=周日；节次是 1 基。
class Course {
  const Course({
    required this.id,
    required this.name,
    required this.weekday,
    required this.startPeriod,
    required this.endPeriod,
    this.teacher = '',
    this.location = '',
    this.startWeek = 1,
    this.endWeek = 18,
    this.colorSeed = 0,
    this.note = '',
    this.custom = true,
  });

  final String id;
  final String name;
  final String teacher;
  final String location;
  final int weekday;
  final int startPeriod;
  final int endPeriod;
  final int startWeek;
  final int endWeek;
  final int colorSeed;
  final String note;

  /// true = 本机手填；false = 从教务系统同步下来（暂未接入）。
  final bool custom;

  int get spanPeriods => (endPeriod - startPeriod + 1).clamp(1, Period.count);

  String get periodLabel => startPeriod == endPeriod
      ? '第 $startPeriod 节'
      : '第 $startPeriod-$endPeriod 节';

  String get timeRange => startPeriod == endPeriod
      ? Period.byIndex(startPeriod).rangeLabel
      : '${Period.byIndex(startPeriod).startLabel}-${Period.byIndex(endPeriod).endLabel}';

  bool activeInWeek(int week) => week >= startWeek && week <= endWeek;

  bool isNow(DateTime now) {
    if (now.weekday != weekday) return false;
    final minute = now.hour * 60 + now.minute;
    return minute >= Period.byIndex(startPeriod).startMinute &&
        minute <= Period.byIndex(endPeriod).endMinute;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'teacher': teacher,
        'location': location,
        'weekday': weekday,
        'startPeriod': startPeriod,
        'endPeriod': endPeriod,
        'startWeek': startWeek,
        'endWeek': endWeek,
        'colorSeed': colorSeed,
        'note': note,
        'custom': custom,
      };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '未命名课程',
        teacher: (json['teacher'] as String?) ?? '',
        location: (json['location'] as String?) ?? '',
        weekday: (json['weekday'] as num?)?.toInt() ?? 1,
        startPeriod: (json['startPeriod'] as num?)?.toInt() ?? 1,
        endPeriod: (json['endPeriod'] as num?)?.toInt() ?? 2,
        startWeek: (json['startWeek'] as num?)?.toInt() ?? 1,
        endWeek: (json['endWeek'] as num?)?.toInt() ?? 18,
        colorSeed: (json['colorSeed'] as num?)?.toInt() ?? 0,
        note: (json['note'] as String?) ?? '',
        custom: (json['custom'] as bool?) ?? true,
      );

  Course copyWith({
    String? name,
    String? teacher,
    String? location,
    int? weekday,
    int? startPeriod,
    int? endPeriod,
    int? startWeek,
    int? endWeek,
    int? colorSeed,
    String? note,
  }) =>
      Course(
        id: id,
        name: name ?? this.name,
        teacher: teacher ?? this.teacher,
        location: location ?? this.location,
        weekday: weekday ?? this.weekday,
        startPeriod: startPeriod ?? this.startPeriod,
        endPeriod: endPeriod ?? this.endPeriod,
        startWeek: startWeek ?? this.startWeek,
        endWeek: endWeek ?? this.endWeek,
        colorSeed: colorSeed ?? this.colorSeed,
        note: note ?? this.note,
        custom: custom,
      );
}
