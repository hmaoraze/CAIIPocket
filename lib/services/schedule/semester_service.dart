import '../../repositories/settings_repository.dart';
import '../../utils/date_x.dart';

/// 教学周换算。学校口径只差一个"第一周周一"，把它做成可设置项就不写死。
class SemesterService {
  SemesterService(this._settings);

  final SettingsRepository _settings;

  static const int totalWeeks = 20;

  /// 未设置时按"本周"当第一周，保证界面不会因为缺配置而空着。
  DateTime get start {
    final saved = _settings.semesterStart;
    return DateX.startOfWeek(saved ?? DateTime.now());
  }

  int get currentWeek => weekOf(DateTime.now());

  int weekOf(DateTime date) {
    final days = DateX.startOfWeek(date).difference(start).inDays;
    return (days ~/ 7) + 1;
  }

  DateTime mondayOf(int week) => start.add(Duration(days: (week - 1) * 7));

  DateTime dayOf(int week, int weekday) =>
      mondayOf(week).add(Duration(days: weekday - 1));

  Future<void> setStart(DateTime date) =>
      _settings.setSemesterStart(DateX.startOfWeek(date));
}
