import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../core/storage/hive_boxes.dart';
import '../models/course/course.dart';

/// 课表仓储：只碰模型 + 本地箱子。
class CourseRepository {
  Box<String> get _box => HiveBoxes.coursesBox;

  List<Course> all() {
    final list = <Course>[];
    for (final raw in _box.values) {
      final course = _decode(raw);
      if (course != null) list.add(course);
    }
    list.sort((a, b) {
      final byDay = a.weekday.compareTo(b.weekday);
      return byDay != 0 ? byDay : a.startPeriod.compareTo(b.startPeriod);
    });
    return list;
  }

  List<Course> forWeek(int week) =>
      all().where((c) => c.activeInWeek(week)).toList();

  List<Course> forDay(int week, int weekday) => all()
      .where((c) => c.weekday == weekday && c.activeInWeek(week))
      .toList();

  Course? byId(String id) {
    final raw = _box.get(id);
    return raw == null ? null : _decode(raw);
  }

  Future<void> save(Course course) =>
      _box.put(course.id, jsonEncode(course.toJson()));

  Future<void> delete(String id) => _box.delete(id);

  /// 教务导入：只替换"导入来的"课程，手填的保留。
  Future<int> replaceImported(List<Course> courses) async {
    final old = all().where((c) => !c.custom).toList();
    for (final course in old) {
      await _box.delete(course.id);
    }
    for (final course in courses) {
      await _box.put(course.id, jsonEncode(course.toJson()));
    }
    return courses.length;
  }

  Future<void> clear() => _box.clear();

  int get count => _box.length;

  Course? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) return Course.fromJson(map);
    } catch (_) {
      return null;
    }
    return null;
  }
}
