import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 网络图：圆角 + 磁盘缓存 + 模糊占位 + 失败占位。
class NetworkImageLayer extends StatelessWidget {
  const NetworkImageLayer({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.image_not_supported_outlined,
  });

  final String url;
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxFit fit;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(borderRadius);

    Widget placeholder(BuildContext _) => Container(
          width: width,
          height: height,
          color: scheme.surfaceContainerHighest,
        );

    if (url.isEmpty) {
      return _fallback(scheme, radius);
    }

    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, _) => placeholder(context),
        errorWidget: (_, _, _) => _fallback(scheme, radius),
        fadeInDuration: const Duration(milliseconds: 180),
      ),
    );
  }

  Widget _fallback(ColorScheme scheme, BorderRadius radius) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: radius,
        ),
        alignment: Alignment.center,
        child: Icon(
          fallbackIcon,
          size: 22,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      );
}
