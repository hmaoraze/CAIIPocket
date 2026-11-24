import 'dart:async';

import 'package:mobx/mobx.dart';

import '../../models/focus/focus_session.dart';
import '../../repositories/focus_repository.dart';
import '../../utils/date_x.dart';
import '../../utils/id_x.dart';

/// 番茄钟：计时引擎 + 落盘 + 统计。
///
/// 计时不靠"每秒累加"，靠 startedAt 时间戳推算——进程被杀、切后台、锁屏
/// 回来都对得上；这也是 ZZUPocket 专注引擎的口径。
class FocusController {
  FocusController(this._repo);

  final FocusRepository _repo;

  final running = Observable(false);
  final paused = Observable(false);
  final elapsedSeconds = Observable(0);
  final targetMinutes = Observable(25);
  final tag = Observable('学习');

  final todayMinutes = Observable(0);
  final weekMinutes = Observable(0);
  final last7 = ObservableList<int>();
  final sessions = ObservableList<FocusSession>();

  /// 每完成一次 +1，页面用它触发一次提示。
  final finishTick = Observable(0);

  Timer? _timer;
  ActiveFocus? _active;
  DateTime? _pauseStart;

  static const List<int> presetMinutes = [15, 25, 45, 60];
  static const List<String> tags = ['学习', '工作', '阅读'];

  double get progress {
    final total = targetMinutes.value * 60;
    if (total <= 0) return 0;
    return (elapsedSeconds.value / total).clamp(0.0, 1.0);
  }

  int get remainingSeconds {
    final left = targetMinutes.value * 60 - elapsedSeconds.value;
    return left < 0 ? 0 : left;
  }

  void restore() {
    sessions
      ..clear()
      ..addAll(_repo.sessions());
    _active = _repo.active();
    if (_active != null) {
      targetMinutes.value = _active!.targetMinutes;
      tag.value = _active!.tag;
      running.value = true;
      paused.value = false;
      _tick();
      _startTimer();
    }
    _refreshStats();
  }

  Future<void> start() async {
    if (running.value) return;
    _active = ActiveFocus(
      startedAt: DateTime.now(),
      targetMinutes: targetMinutes.value,
      tag: tag.value,
      pausedSeconds: 0,
    );
    await _repo.saveActive(_active!);
    runInAction(() {
      running.value = true;
      paused.value = false;
      elapsedSeconds.value = 0;
    });
    _startTimer();
  }

  Future<void> pause() async {
    if (!running.value || paused.value) return;
    _pauseStart = DateTime.now();
    runInAction(() => paused.value = true);
  }

  Future<void> resume() async {
    if (!running.value || !paused.value) return;
    final start = _pauseStart;
    final extra = start == null ? 0 : DateTime.now().difference(start).inSeconds;
    _pauseStart = null;
    final current = _active;
    if (current != null) {
      _active = ActiveFocus(
        startedAt: current.startedAt,
        targetMinutes: current.targetMinutes,
        tag: current.tag,
        pausedSeconds: current.pausedSeconds + extra,
      );
      await _repo.saveActive(_active!);
    }
    runInAction(() => paused.value = false);
    _tick();
  }

  Future<void> stop({bool completed = false}) async {
    final seconds = elapsedSeconds.value;
    final minutes = completed
        ? targetMinutes.value
        : (seconds / 60).round().clamp(0, 24 * 60);
    if (minutes > 0) {
      await _repo.add(
        FocusSession(
          id: newId(),
          tag: tag.value,
          startedAt: _active?.startedAt ?? DateTime.now(),
          minutes: minutes,
          completed: completed,
        ),
      );
    }
    await _reset();
    if (completed) runInAction(() => finishTick.value++);
  }

  Future<void> setTarget(int minutes) async {
    if (running.value) return;
    runInAction(() => targetMinutes.value = minutes);
  }

  void setTag(String value) {
    if (running.value) return;
    runInAction(() => tag.value = value);
  }

  Future<void> removeSession(String id) async {
    await _repo.delete(id);
    runInAction(() {
      sessions.removeWhere((s) => s.id == id);
    });
    _refreshStats();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!running.value) return;
    final active = _active;
    if (active == null) return;
    var seconds = DateTime.now().difference(active.startedAt).inSeconds -
        active.pausedSeconds;
    final pauseStart = _pauseStart;
    if (paused.value && pauseStart != null) {
      seconds -= DateTime.now().difference(pauseStart).inSeconds;
    }
    final normalized = seconds < 0 ? 0 : seconds;
    runInAction(() => elapsedSeconds.value = normalized);
    if (normalized >= active.targetMinutes * 60) {
      unawaited(stop(completed: true));
    }
  }

  Future<void> _reset() async {
    _timer?.cancel();
    _timer = null;
    _pauseStart = null;
    _active = null;
    await _repo.clearActive();
    runInAction(() {
      running.value = false;
      paused.value = false;
      elapsedSeconds.value = 0;
    });
    _refreshStats();
  }

  void _refreshStats() {
    final now = DateTime.now();
    final list = _repo.sessions();
    runInAction(() {
      sessions
        ..clear()
        ..addAll(list);
      todayMinutes.value = _repo.minutesOn(now);
      weekMinutes.value = _repo.minutesBetween(
        DateX.startOfWeek(now),
        DateX.addDays(now, 1),
      );
      last7
        ..clear()
        ..addAll(_repo.last7Days(now));
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
