import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../card/tonal_card.dart';

/// 首屏骨架：把真实布局形状画成灰块，比白屏有用得多。
class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({
    super.key,
    this.child,
    this.itemCount = 4,
    this.enabled = true,
  });

  final Widget? child;
  final int itemCount;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: enabled,
      child: child ??
          ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (_, _) => const _SkeletonCard(),
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemCount: itemCount,
          ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        );

    return TonalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(120, 16),
          const SizedBox(height: 10),
          bar(220, 12),
          const SizedBox(height: 6),
          bar(160, 12),
        ],
      ),
    );
  }
}
