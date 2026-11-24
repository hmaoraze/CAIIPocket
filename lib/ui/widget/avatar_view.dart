import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 头像解析：三种来源都支持 —— http 链接、`data:image/...;base64,...`、空。
///
/// 学校个人信息页的头像是 **base64 内联**（`<img src="data:image/png;base64,...">`），
/// 不是 URL，所以既不能丢给 `Image.network` 也不能只存字符串不管渲染。
class AvatarSource {
  const AvatarSource._();

  static bool isDataUri(String value) =>
      value.startsWith('data:image') && value.contains(',');

  static bool isRemote(String value) =>
      value.startsWith('http://') || value.startsWith('https://');

  /// 把大尺寸 base64 头像缩到 [maxSide] 再重新编码，避免几 MB 的字符串塞进本地库。
  ///
  /// 实测个人信息页的头像 base64 有 738KB（约 550KB 二进制），原样存会让会话 JSON
  /// 变得很臃肿；缩到 160px 后一般 30–60KB。
  static Future<String> shrinkDataUri(
    String value, {
    int maxSide = 160,
    int skipBelow = 120 * 1024,
  }) async {
    if (!isDataUri(value)) return value;
    final bytes = decodeDataUri(value, maxBytes: 8 * 1024 * 1024);
    if (bytes == null) return value;
    if (bytes.length <= skipBelow) return value;

    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: maxSide,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      if (data == null) return value;
      final encoded = base64Encode(data.buffer.asUint8List());
      return 'data:image/png;base64,$encoded';
    } catch (_) {
      return value;
    }
  }

  /// 解码 base64 头像；不是 data URI 或解码失败返回 null。
  static Uint8List? decodeDataUri(String value, {int maxBytes = 512 * 1024}) {
    if (!isDataUri(value)) return null;
    final comma = value.indexOf(',');
    final payload = value.substring(comma + 1);
    if (payload.length > maxBytes * 2) return null;
    try {
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }
}

/// 统一头像组件：有图用图（base64 或网络图），没图用姓名首字。
class AvatarView extends StatelessWidget {
  const AvatarView({
    super.key,
    required this.name,
    this.avatar = '',
    this.cookieHeader = '',
    this.size = 48,
  });

  final String name;

  /// http(s) 链接或 `data:image/...` base64
  final String avatar;

  /// 个人信息页的图不一定公开，带上会话 Cookie
  final String cookieHeader;

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final initial = name.trim().isEmpty ? '?' : name.trim().substring(0, 1);

    Widget fallback = Text(
      initial,
      style: theme.textTheme.titleMedium?.copyWith(
        fontSize: size * 0.42,
        color: scheme.onSecondaryContainer,
        fontWeight: FontWeight.w600,
      ),
    );

    Widget? image;
    final bytes = AvatarSource.decodeDataUri(avatar);
    if (bytes != null) {
      image = Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => Center(child: fallback),
      );
    } else if (AvatarSource.isRemote(avatar)) {
      image = Image.network(
        avatar,
        width: size,
        height: size,
        fit: BoxFit.cover,
        headers: cookieHeader.isEmpty ? null : {'Cookie': cookieHeader},
        errorBuilder: (_, _, _) => Center(child: fallback),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Container(
          color: scheme.secondaryContainer,
          alignment: Alignment.center,
          child: image ?? fallback,
        ),
      ),
    );
  }
}
