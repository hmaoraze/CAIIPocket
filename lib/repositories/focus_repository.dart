import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../core/storage/hive_boxes.dart';
import '../models/focus/focus_session.dart';
import '../utils/date_x.dart';

/// 专注仓储：记录 + "正在进行中的这一次"。
class FocusRepository {
  static const _activeKey = '__active__';

  Box<String> get _box => HiveBoxes.focusBox;

  List<FocusSession> sessions() {
    final list = <FocusSession>[];
    for (final key in _box.keys) {
      if (key == _activeKey) continue;
      final raw = _box.get(key);
      if (raw == null) continue;
      try {
        final map = jsonDecode(raw);
        if (map is Map<String, dynamic>) {
          list.add(FocusSession.fromJson(map));
        }
      } catch (_) {
        continue;
      }
    }
    list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list;
  }

  Future<void> add(FocusSession session) =>
      _box.put(session.id, jsonEncode(session.toJson()));

  Future<void> delete(String id) => _box.delete(id);

  ActiveFocus? active() {
    final raw = _box.get(_activeKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) return ActiveFocus.fromJson(map);
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> saveActive(ActiveFocus active) =>
      _box.put(_activeKey, jsonEncode(active.toJson()));

  Future<void> clearActive() => _box.delete(_activeKey);

  /// 某一天的专注分钟数（按开始时刻归日）。
  int minutesOn(DateTime day) {
    final key = DateX.dateKey(day);
    var total = 0;
    for (final s in sessions()) {
      if (DateX.dateKey(s.startedAt) == key) total += s.minutes;
    }
    return total;
  }

  int minutesBetween(DateTime from, DateTime to) {
    var total = 0;
    for (final s in sessions()) {
      if (!s.startedAt.isBefore(from) && s.startedAt.isBefore(to)) {
        total += s.minutes;
      }
    }
    return total;
  }

  /// 最近 7 天（含今天）的分钟数，旧 → 新。
  List<int> last7Days(DateTime today) {
    final base = DateX.startOfDay(today);
    return List<int>.generate(
      7,
      (i) => minutesOn(base.subtract(Duration(days: 6 - i))),
    );
  }

  Future<void> clear() => _box.clear();
}
