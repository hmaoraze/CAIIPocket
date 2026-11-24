import 'package:dio/dio.dart';

import '../strings.dart';

/// 把任何异常翻成一句人话。UI 层不允许直接展示原始异常。
String mapError(Object? error) {
  if (error is CasException) return error.message;
  if (error is ApiException) return error.message;
  if (error is DioException) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        S.errTimeout,
      DioExceptionType.connectionError => S.errNetwork,
      DioExceptionType.badCertificate => S.errNetwork,
      DioExceptionType.cancel => S.errUnknown,
      DioExceptionType.badResponse => _byStatus(error.response?.statusCode),
      _ => S.errNetwork,
    };
  }
  return S.errUnknown;
}

String _byStatus(int? status) {
  if (status == null) return S.errUnknown;
  if (status == 401 || status == 403) return S.errUnauthorized;
  if (status >= 500) return S.errServer;
  return S.errUnknown;
}

/// 业务层异常：自带可读文案。
class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 认证层异常。
class CasException implements Exception {
  const CasException(this.message, {this.needCaptcha = false, this.needManual = false});

  final String message;
  final bool needCaptcha;
  final bool needManual;

  @override
  String toString() => message;
}
