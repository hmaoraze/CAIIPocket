import 'dart:math';

/// 本地实体 id：时间戳 + 随机后缀，够用且不引依赖。
String newId() {
  final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final rand = Random().nextInt(1 << 20).toRadixString(36);
  return '$ts-$rand';
}
