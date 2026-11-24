import 'dart:developer' as developer;

import 'log_buffer.dart';

/// 统一日志出口：禁止在业务里 print。
///
/// 同时写两份：`dart:developer`（连电脑看 logcat / DevTools）与内存环形缓冲
/// （手机上直接进「诊断」页看），后者是没有调试线时唯一的线索。
class AppLog {
  const AppLog._();

  static const _name = 'caii_pocket';

  static void d(String message) {
    developer.log(message, name: _name);
    LogBuffer.instance.add(message);
  }

  static void e(String message, [Object? error, StackTrace? stack]) {
    final text = error == null ? message : '$message · $error';
    developer.log(text, name: _name, error: error, stackTrace: stack);
    LogBuffer.instance.add('E $text');
  }
}
