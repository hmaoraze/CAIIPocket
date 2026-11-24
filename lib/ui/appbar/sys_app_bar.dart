import 'package:flutter/material.dart';

/// 页面顶栏：大标题 + 可选副标题 + 右侧动作。
class SysAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SysAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  static const double _height = 64;

  @override
  Size get preferredSize => Size.fromHeight(
        _height + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      toolbarHeight: _height,
      leading: leading,
      automaticallyImplyLeading: leading != null,
      actions: actions,
      actionsPadding: const EdgeInsets.only(right: 8),
      bottom: bottom,
      titleSpacing: leading == null ? 16 : 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
