/// 统一认证登录页的表单字段解析。
///
/// 只做字符串解析，不引 HTML 解析库——页面结构稳定，正则足够，
/// 且所有取值都做了"取不到就用保守默认值"的兜底。
class CasLoginForm {
  const CasLoginForm({
    required this.salt,
    required this.execution,
    required this.lt,
    required this.captchaRequired,
  });

  final String? salt;
  final String execution;
  final String lt;
  final bool captchaRequired;

  bool get valid => salt != null && salt!.isNotEmpty;

  static CasLoginForm parse(String html) {
    final salt = _valueOfTagContaining(html, 'pwdEncryptSalt') ??
        _valueOfTagContaining(html, 'pwdDefaultEncryptSalt');
    return CasLoginForm(
      salt: salt,
      execution: _valueOfTagContaining(html, 'name="execution"') ?? 'e1s1',
      lt: _valueOfTagContaining(html, 'id="lt"') ?? '',
      captchaRequired: needCaptcha(html),
    );
  }

  /// 服务端在页面顶部用 <span id="showErrorTip"> 回写错误原因。
  static String? parseError(String html) {
    final match = RegExp(
      r'id="showErrorTip"[^>]*>([\s\S]{0,200}?)</span>',
    ).firstMatch(html);
    if (match == null) return null;
    final raw = match.group(1) ?? '';
    final text = raw
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.isEmpty ? null : text;
  }

  static bool needCaptcha(String html) {
    final match =
        RegExp(r'var\s+needCaptcha\s*=\s*"([^"]*)"').firstMatch(html);
    return match?.group(1) == 'true';
  }

  /// 命中需要人工完成的步骤（短信验证码 / 设备绑定 / MFA）。
  static bool needsManualStep(String html) {
    const keywords = ['二次验证', '短信验证', '绑定设备', 'mfa', 'Mfa', 'MFA', 'otp'];
    return keywords.any(html.contains);
  }

  /// 在包含 [marker] 的那个标签里取 value 属性。
  static String? _valueOfTagContaining(String html, String marker) {
    final index = html.indexOf(marker);
    if (index < 0) return null;
    final start = html.lastIndexOf('<', index);
    final end = html.indexOf('>', index);
    if (start < 0 || end < 0 || end <= start) return null;
    final tag = html.substring(start, end + 1);
    final match = RegExp(r'value="([^"]*)"').firstMatch(tag);
    return match?.group(1);
  }
}
