import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../log/app_logger.dart';
import 'raw_cookie_interceptor.dart';
import 'raw_cookie_store.dart';

/// 伪装成移动端浏览器的 UA：学校侧对 UA 有白名单的情况并不少见。
const kUserAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

/// 全应用唯一的 dio 工厂。
///
/// 四个刻意的选择：
/// 1. `followRedirects: false` —— CAS 的每一跳都要把 Set-Cookie 落进 cookie jar，
///    交给 dio 自动跳转会丢中间跳的响应头。
/// 2. `validateStatus` 放到 500 以下 —— 401/403/302 都是我们要读的业务信号，不是异常。
/// 3. 响应默认按纯文本返回 —— 门户大量返回 HTML，解析层自己做。
/// 4. 挂一个 RawCookieInterceptor —— cookie_jar 有字符校验，丢掉的那些由原始账本补回来。
Dio buildDio(
  CookieJar jar, {
  RawCookieStore? rawCookies,
  String name = 'portal',
}) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {
        'User-Agent': kUserAgent,
        'Accept-Language': 'zh-CN,zh;q=0.9',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      },
      followRedirects: false,
      validateStatus: (status) => status != null && status < 500,
      responseType: ResponseType.plain,
    ),
  );

  dio.interceptors.add(CookieManager(jar));
  if (rawCookies != null) {
    dio.interceptors.add(RawCookieInterceptor(rawCookies));
  }
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        AppLog.d('[${options.method}] ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        AppLog.d('[${response.statusCode}] ${response.requestOptions.uri}');
        handler.next(response);
      },
    ),
  );

  return dio;
}
