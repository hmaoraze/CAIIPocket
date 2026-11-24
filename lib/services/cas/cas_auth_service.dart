import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/log/app_logger.dart';
import '../../core/network/cookie_store.dart';
import '../../core/network/error_mapper.dart';
import '../../core/strings.dart';
import '../portal/portal_endpoints.dart';
import 'cas_crypto.dart';
import 'cas_login_form.dart';

class CasLoginResult {
  const CasLoginResult({
    required this.success,
    this.message,
    this.needCaptcha = false,
    this.needManual = false,
  });

  const CasLoginResult.ok()
      : success = true,
        message = null,
        needCaptcha = false,
        needManual = false;

  final bool success;
  final String? message;
  final bool needCaptcha;
  final bool needManual;
}

/// 金智统一身份认证客户端。
///
/// 四条能力：
///  * login   —— 抓登录页 → 取 salt/execution → AES 加密密码 → POST → 跟随票据回门户
///  * check   —— 用现有 Cookie 探一次门户，判断会话是否还活着
///  * renew   —— 拿着 CASTGC 静默换一张新票据（会话过期后无感恢复）
///  * captcha —— 拉验证码图片
class CasAuthService {
  CasAuthService(this._dio, this._cookies);

  final Dio _dio;
  final CookieStore _cookies;

  Future<CasLoginResult> login({
    required String username,
    required String password,
    String? captcha,
  }) async {
    final form = await _loadLoginForm();
    if (!form.valid) {
      return const CasLoginResult(success: false, message: S.errCasUnknown);
    }

    final body = <String, String>{
      'username': username,
      'password': CasCrypto.encryptPassword(password, form.salt!),
      'captcha': captcha ?? '',
      '_eventId': 'submit',
      'cllt': 'userNameLogin',
      'dllt': 'generalLogin',
      'lt': form.lt,
      'execution': form.execution,
      'rmShown': '1',
    };

    final response = await _dio.post<String>(
      PortalEndpoints.loginUrl,
      data: body,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.plain,
        headers: {'Referer': PortalEndpoints.loginUrl},
      ),
    );

    final status = response.statusCode ?? 0;
    if (status == 301 || status == 302 || status == 303) {
      final location = response.headers.value('location');
      final landed = await _follow(location);
      if (landed) return const CasLoginResult.ok();
      return const CasLoginResult(success: false, message: S.errCasUnknown);
    }

    final html = response.data ?? '';
    if (CasLoginForm.needsManualStep(html)) {
      return const CasLoginResult(
        success: false,
        message: S.errCasNeedManual,
        needManual: true,
      );
    }

    final tip = CasLoginForm.parseError(html);
    if (CasLoginForm.needCaptcha(html)) {
      return CasLoginResult(
        success: false,
        message: tip ?? S.errCasCaptcha,
        needCaptcha: true,
      );
    }

    AppLog.e('CAS login failed: status=$status tip=$tip');
    return CasLoginResult(
      success: false,
      message: tip ?? (status == 401 ? S.errCasPassword : S.errCasUnknown),
    );
  }

  /// 当前 Cookie 还能不能用。
  Future<bool> check() async {
    try {
      final response = await _dio.get<String>(
        PortalEndpoints.portalHomeUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final status = response.statusCode ?? 0;
      AppLog.d('CAS check portal → $status');
      if (status == 200) return true;
      final location = response.headers.value('location') ?? '';
      if (location.contains('authserver')) return await renew(location);
      return false;
    } on DioException catch (e) {
      AppLog.e('CAS check failed', e);
      return false;
    }
  }

  /// 用现有会话给任意校内系统换一张票。
  ///
  /// 门户、教务、图书馆是三个独立系统，但只要都挂在同一个 CAS 后面，
  /// 拿着 CASTGC 请求 `login?service=<目标>` 就能免密进去，会话 Cookie 落进同一个 jar。
  Future<bool> ssoTo(String serviceUrl) async {
    final url = '${PortalEndpoints.casOrigin}/authserver/login'
        '?service=${Uri.encodeComponent(serviceUrl)}';
    final ok = await _follow(url);
    AppLog.d('SSO → $serviceUrl ${ok ? 'ok' : 'fail'}');
    return ok;
  }

  /// 探一次任意地址，返回状态码（诊断用）。
  Future<int> probe(String url) async {
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      return response.statusCode ?? 0;
    } on DioException catch (e) {
      AppLog.e('probe failed: $url', e);
      return -1;
    }
  }

  /// 用 CASTGC 静默换票。会话过期后自动恢复靠的就是它。
  Future<bool> renew([String? location]) async {
    if (!await _cookies.hasCookie(
      PortalEndpoints.casOrigin,
      PortalEndpoints.casSessionCookie,
    )) {
      AppLog.d('renew skipped: 没有 CASTGC');
      return false;
    }
    final target = location ?? PortalEndpoints.loginUrl;
    final ok = await _follow(target);
    AppLog.d('renew → ${ok ? 'ok' : 'fail'}');
    return ok;
  }

  Future<Uint8List?> captchaImage() async {
    try {
      final response = await _dio.get<List<int>>(
        PortalEndpoints.captchaUrl,
        queryParameters: {'ts': DateTime.now().millisecondsSinceEpoch},
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null || data.isEmpty) return null;
      return Uint8List.fromList(data);
    } on DioException catch (e) {
      AppLog.e('captcha fetch failed', e);
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _dio.get<String>(
        PortalEndpoints.logoutUrl,
        options: Options(responseType: ResponseType.plain),
      );
    } on DioException catch (e) {
      AppLog.e('CAS logout request failed', e);
    }
    await _cookies.clear();
  }

  Future<CasLoginForm> _loadLoginForm() async {
    final response = await _dio.get<String>(
      PortalEndpoints.loginUrl,
      options: Options(
        responseType: ResponseType.plain,
        headers: {'Referer': PortalEndpoints.portalOrigin},
      ),
    );
    return CasLoginForm.parse(response.data ?? '');
  }

  /// 手动逐跳跟随重定向：每一跳的 Set-Cookie 都要落进 jar。
  Future<bool> _follow(String? firstLocation) async {
    var location = firstLocation;
    var guard = 0;
    while (location != null && location.isNotEmpty && guard < 8) {
      guard++;
      final absolute = Uri.parse(location).hasScheme
          ? location
          : '${PortalEndpoints.casOrigin}$location';
      final response = await _dio.get<String>(
        absolute,
        options: Options(responseType: ResponseType.plain),
      );
      final status = response.statusCode ?? 0;
      if (status == 301 || status == 302 || status == 303) {
        location = response.headers.value('location');
        continue;
      }
      return status == 200;
    }
    return false;
  }
}

/// 供调试台复用：把异常翻成人话。
String describe(Object error) => mapError(error);
