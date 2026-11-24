/// 一节课的默认时刻表。学校作息不同，改这里即可。
class Period {
  const Period(this.index, this.startMinute, this.endMinute);

  final int index;
  final int startMinute;
  final int endMinute;

  String get startLabel => _label(startMinute);

  String get endLabel => _label(endMinute);

  String get rangeLabel => '$startLabel-$endLabel';

  static String _label(int minute) {
    final h = (minute ~/ 60) % 24;
    final m = minute % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static const List<Period> table = [
    Period(1, 8 * 60, 8 * 60 + 45),
    Period(2, 8 * 60 + 55, 9 * 60 + 40),
    Period(3, 10 * 60, 10 * 60 + 45),
    Period(4, 10 * 60 + 55, 11 * 60 + 40),
    Period(5, 14 * 60, 14 * 60 + 45),
    Period(6, 14 * 60 + 55, 15 * 60 + 40),
    Period(7, 16 * 60, 16 * 60 + 45),
    Period(8, 16 * 60 + 55, 17 * 60 + 40),
    Period(9, 19 * 60, 19 * 60 + 45),
    Period(10, 19 * 60 + 55, 20 * 60 + 40),
    Period(11, 20 * 60 + 50, 21 * 60 + 35),
    Period(12, 21 * 60 + 45, 22 * 60 + 30),
  ];

  static int get count => table.length;

  static Period byIndex(int index) => table[(index - 1).clamp(0, count - 1)];

  /// 上午 1-4 / 下午 5-8 / 晚上 9-12，用于课表分组线。
  static int partOf(int index) {
    if (index <= 4) return 0;
    if (index <= 8) return 1;
    return 2;
  }
}
