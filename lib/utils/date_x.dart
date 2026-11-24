/// 日期工具：只做纯函数，不依赖 BuildContext。
class DateX {
  const DateX._();

  static const weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  static String weekday(int weekday) => weekdayNames[(weekday - 1).clamp(0, 6)];

  static DateTime startOfDay(DateTime t) => DateTime(t.year, t.month, t.day);

  static DateTime startOfWeek(DateTime t) {
    final day = startOfDay(t);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  static DateTime addDays(DateTime t, int days) =>
      startOfDay(t).add(Duration(days: days));

  static String dateKey(DateTime t) =>
      '${t.year}-${_two(t.month)}-${_two(t.day)}';

  static String monthDay(DateTime t) => '${_two(t.month)}-${_two(t.day)}';

  static String hhmm(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

  static String fullDate(DateTime t) =>
      '${t.year} 年 ${t.month} 月 ${t.day} 日 ${weekday(t.weekday)}';

  static String minutesLabel(int minutes) {
    if (minutes < 60) return '$minutes 分钟';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h 小时' : '$h 小时 $m 分';
  }

  /// 两个时刻相差的分钟数（向下取整）。
  static int minutesBetween(DateTime from, DateTime to) =>
      to.difference(from).inMinutes;

  static String greeting(DateTime now) {
    final h = now.hour;
    if (h < 6) return '凌晨好';
    if (h < 11) return '早上好';
    if (h < 13) return '中午好';
    if (h < 18) return '下午好';
    return '晚上好';
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
