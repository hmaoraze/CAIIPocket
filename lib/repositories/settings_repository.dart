import 'package:hive_ce_flutter/hive_flutter.dart';

import '../core/storage/hive_boxes.dart';
import '../core/storage/settings_keys.dart';

/// 纯键值偏好（按周/主题等）。
class SettingsRepository {
  Box<String> get _box => HiveBoxes.settingsBox;

  String? read(String key) => _box.get(key);

  Future<void> write(String key, String value) => _box.put(key, value);

  Future<void> remove(String key) => _box.delete(key);

  String? get lastUsername => read(SettingsKeys.lastUsername);

  Future<void> setLastUsername(String value) =>
      write(SettingsKeys.lastUsername, value);

  DateTime? get semesterStart {
    final raw = read(SettingsKeys.semesterStart);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setSemesterStart(DateTime value) =>
      write(SettingsKeys.semesterStart, value.toIso8601String());
}
