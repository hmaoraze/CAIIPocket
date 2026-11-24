import 'package:flutter/material.dart';

/// 断点统一入口：任何地方判断宽窄都走这里，不要散落 MediaQuery。
class Breakpoints {
  const Breakpoints._();

  /// 手机 < 600 ≤ 平板/桌面
  static const double wide = 600;

  /// 是否需要侧边导航栏
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wide;

  static double pagePadding(BuildContext context) => isWide(context) ? 24 : 16;

  /// 列表最大内容宽度，避免平板上文字拉成一整行。
  static double contentMaxWidth(BuildContext context) =>
      isWide(context) ? 780 : double.infinity;
}
