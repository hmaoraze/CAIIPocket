import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../log/app_logger.dart';

/// 一条从 WebView 里抓回来的原始 Cookie。
///
/// 不用 dart:io 的 `Cookie` 来承载：那个类对 value 字符集校验严格，
/// 学校下发的 CASTGC / JSESSIONID 里带 `= + /` 时会被直接抛异常，
/// 于是"同步了但没同步上"。这里只存 name/value/domain/path，原样用。
class RawCookie {
  const RawCookie({
    required this.name,
    required this.value,
    this.domain = '',
    this.path = '/',
  });

  final String name;
  final String value;
  final String domain;
  final String path;

  bool matchesHost(String host) {
    if (name.isEmpty) return false;
    final d = normalizeDomain(domain);
    if (d.isEmpty) return true;
    final h = normalizeDomain(host);
    return h == d || h.endsWith('.$d');
  }

  RawCookie copyWith({String? value, String? domain, String? path}) => RawCookie(
        name: name,
        value: value ?? this.value,
        domain: domain ?? this.domain,
        path: path ?? this.path,
      );

  Map<String, dynamic> toJson() => {
        'n': name,
        'v': value,
        'd': domain,
        'p': path,
      };

  factory RawCookie.fromJson(Map<String, dynamic> json) => RawCookie(
        name: json['n'] as String? ?? '',
        value: json['v'] as String? ?? '',
        domain: json['d'] as String? ?? '',
        path: json['p'] as String? ?? '/',
      );

  /// 把各种写法的 domain 收敛成纯主机名。
  ///
  /// 实测 webview_flutter 在 Android 上返回的 domain 可能是
  /// `https://portal.caii.edu.cn`（带协议），也可能是 `.caii.edu.cn`。
  /// 不收敛就会"Cookie 抓到了但一条也匹配不上"，症状正是"网页已登录、App 说没登录"。
  static String normalizeDomain(String value) {
    var d = value.trim().toLowerCase();
    if (d.isEmpty) return '';
    if (d.contains('://')) {
      final parsed = Uri.tryParse(d);
      if (parsed != null && parsed.host.isNotEmpty) {
        d = parsed.host;
      } else {
        d = d.substring(d.indexOf('://') + 3);
      }
    }
    final slash = d.indexOf('/');
    if (slash >= 0) d = d.substring(0, slash);
    final colon = d.indexOf(':');
    if (colon > 0) d = d.substring(0, colon);
    while (d.startsWith('.')) {
      d = d.substring(1);
    }
    return d;
  }
}

/// 本机手动维护的 Cookie 表：按 domain 匹配，给 dio 拼 Cookie 头。
///
/// 存在的意义：cookie_jar 依赖 dart:io 的 Cookie 校验，遇到不合规字符会整条丢；
/// 这里保一份"原始账本"，即使 jar 里没写进去，请求也能带着会话出去。
class RawCookieStore {
  RawCookieStore(this._box);

  static const _key = 'raw_cookies_v1';

  final Box<String> _box;

  List<RawCookie> all() {
    final raw = _box.get(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(RawCookie.fromJson)
          .where((c) => c.name.isNotEmpty)
          .toList();
    } catch (e) {
      AppLog.e('raw cookies decode failed', e);
      return const [];
    }
  }

  int get count => all().length;

  /// 同 name + 同 domain 视为同一条，新值覆盖旧值。
  Future<void> merge(Iterable<RawCookie> incoming) async {
    final map = <String, RawCookie>{};
    for (final c in all()) {
      map['${c.domain}|${c.name}'] = c;
    }
    for (final c in incoming) {
      map['${c.domain}|${c.name}'] = c;
    }
    await _write(map.values.toList());
  }

  Future<void> replaceAll(Iterable<RawCookie> cookies) =>
      _write(cookies.toList());

  Future<void> removeHost(String host) async {
    final kept = all().where((c) => !c.matchesHost(host)).toList();
    await _write(kept);
  }

  Future<void> clear() => _box.delete(_key);

  /// 给某个 host 拼 `a=1; b=2`，同名以后写入的为准。
  String headerFor(String host) {
    final map = <String, String>{};
    for (final c in all()) {
      if (c.matchesHost(host)) map[c.name] = c.value;
    }
    return map.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  /// 诊断用：按域名分组。
  Map<String, int> summary() {
    final map = <String, int>{};
    for (final c in all()) {
      final key = c.domain.isEmpty ? '(any)' : c.domain;
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  Future<void> _write(List<RawCookie> cookies) =>
      _box.put(_key, jsonEncode(cookies.map((c) => c.toJson()).toList()));
}
