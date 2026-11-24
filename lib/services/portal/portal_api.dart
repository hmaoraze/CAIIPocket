import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/log/app_logger.dart';
import '../../core/network/error_mapper.dart';
import '../../core/strings.dart';
import '../cas/cas_auth_service.dart';
import 'portal_endpoints.dart';

/// 带会话的门户访问层。
///
/// 每个请求都做同一件事：如果被 302 到 authserver，就用 CASTGC 静默续期再重试一次。
/// 这样"登录过期"不会变成用户可见的错误，而是自己消失。
class PortalApi {
  PortalApi(this._dio, this._cas);

  final Dio _dio;
  final CasAuthService _cas;

  Future<String> getHtml(String path) async {
    final response = await _dio.get<String>(
      PortalEndpoints.absolute(path),
      options: Options(responseType: ResponseType.plain),
    );
    await _ensureSession(response);
    final status = response.statusCode ?? 0;
    if (status != 200) throw ApiException(S.errServer);
    return response.data ?? '';
  }

  /// 门户开放接口。返回结构未知时用 [getRaw] 拿原文。
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final raw = await getRaw(path, query: query);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      throw ApiException(S.errParse);
    } on FormatException {
      throw ApiException(S.errParse);
    }
  }

  Future<String> getRaw(String path, {Map<String, dynamic>? query}) async {
    final response = await _dio.get<String>(
      PortalEndpoints.absolute(path),
      queryParameters: query,
      options: Options(responseType: ResponseType.plain),
    );
    await _ensureSession(response);
    return response.data ?? '';
  }

  /// 门户的用户信息（`/jsonp/userInfo.json`，实测可用）。
  ///
  /// 返回 `userName`(姓名) / `userId`(学号) / `userDepartment`(院系)。
  Future<Map<String, dynamic>?> fetchUserInfo() async {
    try {
      final raw = await getRaw(
        '/jsonp/userInfo.json',
        query: {'amp_jsonp_callback': 'amp_jsonp_callback'},
      );
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      AppLog.e('userInfo 拉取失败', e);
    }
    return null;
  }

  Future<void> _ensureSession(Response<dynamic> response) async {
    final status = response.statusCode ?? 0;
    if (status != 301 && status != 302 && status != 303) return;
    final location = response.headers.value('location') ?? '';
    if (!location.contains('authserver')) return;
    final renewed = await _cas.renew(location);
    if (!renewed) throw ApiException(S.errUnauthorized);
  }
}
