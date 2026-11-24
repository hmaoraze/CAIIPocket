import 'package:mobx/mobx.dart';

import '../../models/course/course.dart';
import '../../repositories/course_repository.dart';
import '../../services/schedule/semester_service.dart';

/// 课表：周切换 + 本周课程 + 增删。
class ScheduleController {
  ScheduleController(this._repo, this._semester);

  final CourseRepository _repo;
  final SemesterService _semester;

  final week = Observable(1);
  final courses = ObservableList<Course>();

  static const int maxWeek = SemesterService.totalWeeks;

  DateTime get semesterStart => _semester.start;

  int get currentWeek => _semester.currentWeek;

  bool get isCurrentWeek => week.value == currentWeek;

  void load() {
    runInAction(() {
      week.value = currentWeek.clamp(1, maxWeek);
      _refresh();
    });
  }

  void goToWeek(int value) {
    runInAction(() {
      week.value = value.clamp(1, maxWeek);
      _refresh();
    });
  }

  void shift(int delta) => goToWeek(week.value + delta);

  List<Course> dayCourses(int weekday) =>
      courses.where((c) => c.weekday == weekday).toList();

  DateTime dateOfDay(int weekday) => _semester.dayOf(week.value, weekday);

  Future<void> save(Course course) async {
    await _repo.save(course);
    runInAction(_refresh);
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    runInAction(_refresh);
  }

  Future<void> setSemesterStart(DateTime date) async {
    await _semester.setStart(date);
    load();
  }

  void _refresh() {
    courses
      ..clear()
      ..addAll(_repo.forWeek(week.value));
  }
}
