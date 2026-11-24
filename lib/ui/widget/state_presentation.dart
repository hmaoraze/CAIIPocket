import 'package:flutter/material.dart';

import '../../core/strings.dart';
import 'error_state_widget.dart';
import 'loading_skeleton.dart';

enum ViewState { loading, empty, error, data }

/// 内容区四态统一入口。
class StatePresentation extends StatelessWidget {
  const StatePresentation({
    super.key,
    required this.state,
    required this.child,
    this.skeleton,
    this.emptyWidget,
    this.errorMessage,
    this.onRetry,
  });

  final ViewState state;
  final Widget child;
  final Widget? skeleton;
  final Widget? emptyWidget;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      ViewState.loading => skeleton ?? const LoadingSkeleton(),
      ViewState.empty => emptyWidget ?? const SizedBox.shrink(),
      ViewState.error => ErrorStateWidget(
          message: errorMessage ?? S.errUnknown,
          onRetry: onRetry,
        ),
      ViewState.data => child,
    };
  }
}
