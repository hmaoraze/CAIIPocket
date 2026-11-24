import 'package:flutter/material.dart';

/// 区块标题：左标题 + 右「更多」。
class ContentSection extends StatelessWidget {
  const ContentSection({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 24, 16, 8),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: padding,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (onAction != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(actionLabel ?? '更多'),
                ),
            ],
          ),
        ),
        ?child,
      ],
    );
  }
}
