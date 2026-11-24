import 'dart:collection';

/// 内存里的最近日志：诊断页直接展示，不用连电脑看 logcat。
class LogBuffer {
  LogBuffer._();

  static final LogBuffer instance = LogBuffer._();

  static const int _capacity = 200;

  final ListQueue<String> _lines = ListQueue<String>();

  List<String> get lines => _lines.toList().reversed.toList();

  void add(String message) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    _lines.addLast('$ts  $message');
    while (_lines.length > _capacity) {
      _lines.removeFirst();
    }
  }

  void clear() => _lines.clear();
}
