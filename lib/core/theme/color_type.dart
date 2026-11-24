import 'package:flutter/material.dart';

/// 配色方案（对应 Kazumi 实测的四个枚举名）。
enum ColorType { tonalSpot, fidelity, monochrome, content }

extension ColorTypeX on ColorType {
  String get label => switch (this) {
        ColorType.tonalSpot => '柔和',
        ColorType.fidelity => '忠实',
        ColorType.monochrome => '单色',
        ColorType.content => '内容',
      };

  DynamicSchemeVariant get variant => switch (this) {
        ColorType.tonalSpot => DynamicSchemeVariant.tonalSpot,
        ColorType.fidelity => DynamicSchemeVariant.fidelity,
        ColorType.monochrome => DynamicSchemeVariant.monochrome,
        ColorType.content => DynamicSchemeVariant.content,
      };
}

/// 种子色预设：主色只用在主按钮、选中态、强调数字。
class SeedPalette {
  const SeedPalette._();

  static const List<Color> values = [
    Color(0xFF2F6BFF), // 校徽蓝
    Color(0xFF3B82F6),
    Color(0xFF0EA5A4), // 青
    Color(0xFF6750A4), // M3 默认紫
    Color(0xFFB45309), // 琥珀
    Color(0xFF15803D), // 松绿
    Color(0xFFB91C1C), // 砖红
  ];
}
