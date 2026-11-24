import 'package:dio/dio.dart';

import 'raw_cookie_store.dart';

/// 把 [RawCookieStore] 里的会话拼进请求头。
///
/// 必须挂在 `CookieManager` **之后**：先让 jar 写它那份，这里再补齐/覆盖，
/// 这样即使 cookie_jar 因为字符校验丢了某条，请求也仍然带得出去。
class RawCookieInterceptor extends Interceptor {
  RawCookieInterceptor(this._store);

  final RawCookieStore _store;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra['skipRawCookie'] == true) {
      handler.next(options);
      return;
    }

    final extra = _store.headerFor(options.uri.host);
    if (extra.isEmpty) {
      handler.next(options);
      return;
    }

    final existing = options.headers['Cookie'] ?? options.headers['cookie'];
    final merged = <String, String>{};
    if (existing is String && existing.isNotEmpty) {
      for (final part in existing.split(';')) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        final index = trimmed.indexOf('=');
        if (index <= 0) continue;
        merged[trimmed.substring(0, index)] = trimmed.substring(index + 1);
      }
    }
    for (final part in extra.split(';')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final index = trimmed.indexOf('=');
      if (index <= 0) continue;
      merged[trimmed.substring(0, index)] = trimmed.substring(index + 1);
    }

    options.headers['Cookie'] =
        merged.entries.map((e) => '${e.key}=${e.value}').join('; ');
    handler.next(options);
  }
}
