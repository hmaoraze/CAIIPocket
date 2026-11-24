import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/log/app_logger.dart';
import '../../models/course/course.dart';
import '../cas/cas_auth_service.dart';

/// 一个候选课表接口。
class JwxtEndpoint {
  const JwxtEndpoint(this.label, this.path, {this.method = 'GET'});

  final String label;
  final String path;
  final String method;
}

/// 探测结果：状态码 + 一句话结论，直接显示给用户。
class JwxtProbe {
  const JwxtProbe({
    required this.label,
    required this.url,
    required this.status,
    required this.note,
  });

  final String label;
  final String url;
  final int status;
  final String note;

  bool get looksAlive => status == 200;
}

class JwxtImportResult {
  const JwxtImportResult({
    required this.courses,
    this.raw = '',
    this.message,
    this.probes = const [],
  });

  final List<Course> courses;
  final String raw;
  final String? message;
  final List<JwxtProbe> probes;

  bool get ok => courses.isNotEmpty;
}

/// 教务（金智）导入。
///
/// 已知事实（实测）：本校教务门户在 `https://jw.caii.edu.cn`，是金智 `jwfw`
/// 产品，选课应用挂在 `/xsxkapp`，CAS 入口是
/// `/xsxkapp/sys/xsxkapp/caiiXsxkLogin/casLogin.do`。
/// 但**课表接口不在这个域名下**（`/jwglxt/...` 一律 404），所以这里不写死，
/// 而是按候选清单逐个探测，把每一步的状态码摊给用户看，能对上的那个直接导入。
class JwxtService {
  JwxtService(this._dio, this._cas);

  final Dio _dio;
  final CasAuthService _cas;

  static const String defaultBase = 'https://jw.caii.edu.cn';

  static const String xsxkLoginPath =
      '/xsxkapp/sys/xsxkapp/caiiXsxkLogin/casLogin.do';

  static const List<JwxtEndpoint> endpoints = [
    JwxtEndpoint(
      '金智 jwglxt 课表（旧版教务）',
      '/jwglxt/kbcx/xskbcx_cxXsKb.html',
      method: 'POST',
    ),
    JwxtEndpoint(
      '金智 jwfw 课表（新版教务）',
      '/jwapp/sys/jwapp/kbcx/xskbcx_cxXsKb.do',
      method: 'POST',
    ),
    JwxtEndpoint(
      '新版教务首页（会话探测）',
      '/xsxkapp/sys/xsxkapp/*default/index.do',
    ),
  ];

  /// 先对教务做一次 CAS 单点登录，再逐个探接口。
  Future<List<JwxtProbe>> probe(String base) async {
    final origin = _normalize(base);
    await _cas.ssoTo('$origin$xsxkLoginPath');

    final probes = <JwxtProbe>[];
    for (final endpoint in endpoints) {
      final url = '$origin${endpoint.path}';
      final status = await _cas.probe(url);
      probes.add(
        JwxtProbe(
          label: endpoint.label,
          url: url,
          status: status,
          note: switch (status) {
            200 => '可访问，继续看返回内容',
            302 || 301 => '被重定向（会话没带过去）',
            401 || 403 => '没有权限（需要登录）',
            404 => '这个路径不存在',
            -1 => '连不上',
            _ => '状态码 $status',
          },
        ),
      );
    }
    return probes;
  }

  /// 按候选顺序试着把课表拿回来。全部失败时把最后一次返回原文带回去，方便贴给开发者。
  Future<JwxtImportResult> importCourses({
    required String base,
    String academicYear = '',
    String term = '',
    List<JwxtEndpoint>? only,
  }) async {
    final origin = _normalize(base);
    await _cas.ssoTo('$origin$xsxkLoginPath');

    final probes = <JwxtProbe>[];
    String lastRaw = '';

    for (final endpoint in only ?? endpoints) {
      final url = '$origin${endpoint.path}';
      try {
        final response = await _dio.request<String>(
          url,
          data: endpoint.method == 'POST'
              ? {
                  if (academicYear.isNotEmpty) 'xnm': academicYear,
                  if (term.isNotEmpty) 'xqm': term,
                  'gnmkdm': 'N2151',
                }
              : null,
          options: Options(
            method: endpoint.method,
            responseType: ResponseType.plain,
            contentType: endpoint.method == 'POST'
                ? Headers.formUrlEncodedContentType
                : null,
            headers: {'X-Requested-With': 'XMLHttpRequest'},
          ),
        );
        final status = response.statusCode ?? 0;
        final body = response.data ?? '';
        lastRaw = body;
        probes.add(
          JwxtProbe(
            label: endpoint.label,
            url: url,
            status: status,
            note: '返回 ${body.length} 字符',
          ),
        );

        if (status == 200 && body.trim().isNotEmpty) {
          final courses = JwxtParser.parse(body);
          if (courses.isNotEmpty) {
            AppLog.d('教务导入成功：${courses.length} 门课（${endpoint.label}）');
            return JwxtImportResult(
              courses: courses,
              raw: body,
              probes: probes,
            );
          }
        }
      } on DioException catch (e) {
        probes.add(
          JwxtProbe(
            label: endpoint.label,
            url: url,
            status: -1,
            note: '请求失败：${e.type.name}',
          ),
        );
      }
    }

    return JwxtImportResult(
      courses: const [],
      raw: lastRaw,
      message: '没认出课表数据。把下面的返回内容发我，或者改用「粘贴 JSON 导入」。',
      probes: probes,
    );
  }

  /// 直接解析一段 JSON（用户从调试台复制过来的那种）。
  List<Course> parseRaw(String raw) => JwxtParser.parse(raw);

  static String _normalize(String base) {
    var origin = base.trim();
    if (origin.isEmpty) origin = defaultBase;
    if (!origin.startsWith('http')) origin = 'https://$origin';
    while (origin.endsWith('/')) {
      origin = origin.substring(0, origin.length - 1);
    }
    // 用户可能把整个登录页地址贴进来，只保留 origin + 已有路径前缀
    final uri = Uri.tryParse(origin);
    if (uri == null) return defaultBase;
    return '${uri.scheme}://${uri.host}';
  }
}

/// 金智课表返回的解析。字段名在两代产品里不一样，这里逐个别名兜底。
class JwxtParser {
  const JwxtParser._();

  static List<Course> parse(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const [];
    }

    final rows = _findRows(decoded);
    final courses = <Course>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final name = _pick(row, ['kcmc', 'kcmcStr', 'courseName', 'kcmcstr']);
      if (name == null || name.isEmpty) continue;

      final weekday = _toInt(_pick(row, ['xqj', 'xingqi', 'weekDay', 'xq']));
      final periods = _parsePeriods(_pick(row, ['jcs', 'jc', 'jcsStr', 'jcor']));
      if (weekday == null || weekday < 1 || weekday > 7) continue;
      if (periods == null) continue;

      final weeks = _parseWeeks(_pick(row, ['zcd', 'zc', 'weeks', 'zcdStr']));

      courses.add(
        Course(
          id: 'jwxt-$weekday-${periods.$1}-${_pick(row, ['kch', 'kchId']) ?? i}',
          name: name,
          teacher: _pick(row, ['xm', 'jsxm', 'teacher', 'jsmc']) ?? '',
          location: _pick(row, ['cdmc', 'jxdd', 'location', 'cdmcStr']) ?? '',
          weekday: weekday,
          startPeriod: periods.$1,
          endPeriod: periods.$2,
          startWeek: weeks.$1,
          endWeek: weeks.$2,
          colorSeed: i % 7,
          custom: false,
        ),
      );
    }
    return courses;
  }

  /// 在任意嵌套结构里找"课程数组"。
  ///
  /// 金智两代产品的包裹层不一样（`kbList` / `xskcb.kbList` / `data.rows`…），
  /// 与其一个个对齐，不如按"数组元素里有没有 kcmc"来判断。
  static List<Map<String, dynamic>> _findRows(Object? decoded, [int depth = 0]) {
    if (depth > 4) return const [];

    if (decoded is List) {
      final maps = decoded.whereType<Map<String, dynamic>>().toList();
      if (maps.isEmpty) return const [];
      if (maps.any((row) => row.containsKey('kcmc') || row.containsKey('kcbm'))) {
        return maps;
      }
      for (final row in maps) {
        final nested = _findRows(row, depth + 1);
        if (nested.isNotEmpty) return nested;
      }
      return const [];
    }

    if (decoded is Map<String, dynamic>) {
      const preferred = ['kbList', 'kbListVo', 'xskcb', 'xkxx', 'rows', 'data', 'items', 'list'];
      for (final key in preferred) {
        final value = decoded[key];
        if (value == null) continue;
        final nested = _findRows(value, depth + 1);
        if (nested.isNotEmpty) return nested;
      }
      for (final value in decoded.values) {
        if (value is! Map<String, dynamic> && value is! List) continue;
        final nested = _findRows(value, depth + 1);
        if (nested.isNotEmpty) return nested;
      }
    }

    return const [];
  }

  static String? _pick(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isEmpty || text == 'null') continue;
      return text;
    }
    return null;
  }

  static int? _toInt(String? value) {
    if (value == null) return null;
    final match = RegExp(r'\d+').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  /// "1-2节" / "3-4" / "5" → (start, end)
  static (int, int)? _parsePeriods(String? value) {
    if (value == null) return null;
    final numbers = RegExp(r'\d+')
        .allMatches(value)
        .map((m) => int.tryParse(m.group(0)!))
        .whereType<int>()
        .toList();
    if (numbers.isEmpty) return null;
    final start = numbers.first.clamp(1, 12);
    final end = (numbers.length >= 2 ? numbers[1] : numbers.first).clamp(start, 12);
    return (start, end);
  }

  /// "1-16周" / "1-16周(单)" / "1,3,5周" → (1, 16)
  static (int, int) _parseWeeks(String? value) {
    if (value == null) return (1, 18);
    final numbers = RegExp(r'\d+')
        .allMatches(value)
        .map((m) => int.tryParse(m.group(0)!))
        .whereType<int>()
        .toList();
    if (numbers.isEmpty) return (1, 18);
    final start = numbers.first.clamp(1, 30);
    final end = (numbers.length >= 2 ? numbers[1] : numbers.first).clamp(start, 30);
    return (start, end);
  }
}
