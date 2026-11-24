import 'package:flutter/material.dart';

import '../card/tonal_card.dart';

/// 设置分组：一张卡片里多行 + 缩进分隔线。
class SettingsList extends StatelessWidget {
  const SettingsList({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(
          const Divider(indent: 16, endIndent: 16),
        );
      }
    }
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
      child: TonalCard(
        padding: EdgeInsets.zero,
        child: Column(children: rows),
      ),
    );
  }
}
