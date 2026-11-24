import 'package:flutter/material.dart';

import '../breakpoints.dart';

/// 一套代码两形态：手机弹底部 Sheet，宽屏弹居中 Dialog。
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  bool dismissible = true,
  EdgeInsets padding = const EdgeInsets.fromLTRB(0, 4, 0, 20),
}) {
  final content = Navigator.of(context, rootNavigator: false).context;

  if (Breakpoints.isWide(content)) {
    return showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHeader(title: title),
              Flexible(child: builder(dialogContext)),
            ],
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHeader(title: title),
          Flexible(child: builder(sheetContext)),
        ],
      ),
    ),
  );
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }
}
