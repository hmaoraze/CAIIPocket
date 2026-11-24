import 'package:hive_ce_flutter/hive_flutter.dart';

/// 所有本地箱子的唯一入口。
///
/// 数据落盘策略：业务实体以 JSON 字符串存进 `Box<String>`，避免引入
/// TypeAdapter 代码生成；需要强类型 adapter 时替换本层即可，上层无感。
class HiveBoxes {
  const HiveBoxes._();

  static const settings = 'settings';
  static const courses = 'courses';
  static const focus = 'focus';
  static const cache = 'cache';
  static const rawCookies = 'raw_cookies';

  static const _all = [settings, courses, focus, cache, rawCookies];

  static Future<void> init() async {
    await Hive.initFlutter();
    for (final name in _all) {
      await Hive.openBox<String>(name);
    }
  }

  static Box<String> get settingsBox => Hive.box<String>(settings);

  static Box<String> get coursesBox => Hive.box<String>(courses);

  static Box<String> get focusBox => Hive.box<String>(focus);

  static Box<String> get cacheBox => Hive.box<String>(cache);

  static Box<String> get rawCookieBox => Hive.box<String>(rawCookies);
}
