import 'package:cookie_jar/cookie_jar.dart';

import '../../services/portal/portal_endpoints.dart';

/// 会话 Cookie 的唯一读写口。
class CookieStore {
  CookieStore(this._jar);

  final PersistCookieJar _jar;

  List<String> get origins => const [
        PortalEndpoints.casOrigin,
        PortalEndpoints.portalOrigin,
      ];

  Future<Map<String, String>> forUrl(String url) async {
    final cookies = await _jar.loadForRequest(Uri.parse(url));
    return {for (final c in cookies) c.name: c.value};
  }

  /// 供 WebView 同步用：把本机 cookie jar 里的会话写进系统 WebView。
  Future<List<Cookie>> raw(String origin) =>
      _jar.loadForRequest(Uri.parse(origin));

  Future<List<String>> dump() async {
    final lines = <String>[];
    for (final origin in origins) {
      final cookies = await _jar.loadForRequest(Uri.parse(origin));
      for (final c in cookies) {
        final expires = c.expires;
        final left = expires == null
            ? '会话级'
            : '${expires.toLocal().toString().split('.').first} 过期';
        lines.add('${c.name}=${_ellipsis(c.value)}    ($origin · $left)');
      }
    }
    return lines;
  }

  Future<int> count() async {
    var n = 0;
    for (final origin in origins) {
      n += (await _jar.loadForRequest(Uri.parse(origin))).length;
    }
    return n;
  }

  Future<bool> hasCookie(String origin, String name) async {
    final cookies = await _jar.loadForRequest(Uri.parse(origin));
    return cookies.any((c) => c.name == name);
  }

  Future<void> clear() async {
    await _jar.deleteAll();
  }

  static String _ellipsis(String value) => value.length <= 28
      ? value
      : '${value.substring(0, 12)}…${value.substring(value.length - 8)}';
}
