import 'dart:async';

import 'package:mobx/mobx.dart';

import '../../models/course/course.dart';
import '../../models/course/period.dart';
import '../../repositories/course_repository.dart';
import '../../repositories/focus_repository.dart';
import '../../services/schedule/semester_service.dart';
import '../auth/auth_controller.dart';

/// 首页：今天的时间轴 + 今日专注 + 教学周。
class HomeController {
  HomeController(
    this._courses,
    this._focus,
    this._semester,
    this.auth,
  );

  final CourseRepository _courses;
  final FocusRepository _focus;
  final SemesterService _semester;
  final AuthController auth;

  final now = Observable(DateTime.now());
  final todayCourses = ObservableList<Course>();
  final focusMinutesToday = Observable(0);
  final week = Observable(1);

  Timer? _clock;

  void start() {
    refresh();
    _clock ??= Timer.periodic(const Duration(seconds: 30), (_) {
      runInAction(() => now.value = DateTime.now());
      refresh();
    });
  }

  void refresh() {
    final at = now.value;
    runInAction(() {
      week.value = _semester.currentWeek;
      todayCourses
        ..clear()
        ..addAll(
          _courses.forDay(week.value, at.weekday).map((c) => c),
        );
      focusMinutesToday.value = _focus.minutesOn(at);
    });
  }

  /// 正在上的课（没有则返回 null）。
  Course? get currentCourse {
    for (final c in todayCourses) {
      if (c.isNow(now.value)) return c;
    }
    return null;
  }

  Course? get nextCourse {
    final minute = now.value.hour * 60 + now.value.minute;
    for (final c in todayCourses) {
      if (Period.byIndex(c.startPeriod).startMinute > minute) return c;
    }
    return null;
  }

  void dispose() {
    _clock?.cancel();
    _clock = null;
  }
}
