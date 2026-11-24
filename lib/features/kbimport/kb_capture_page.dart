import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/graph.dart';
import '../../core/log/app_logger.dart';
import '../../core/strings.dart';
import '../../services/portal/portal_endpoints.dart';
import '../../ui/appbar/sys_app_bar.dart';

/// 在网页里抓课表。
///
/// 为什么不用写死接口：金智「我的课表」是在门户里用一次性 `gid_` 令牌打开的，
/// 直接请求 `/jwapp/sys/wdkb/...` 会 403；就算绕过令牌，学校升级一次路径就废。
/// 这里换个思路——用户正常点进课表，我们在页面里给 XHR 打个补丁，
/// 把页面自己拉到的课表 JSON 截下来。接口怎么变都不影响。
class KbCapturePage extends StatefulWidget {
  const KbCapturePage({super.key});

  @override
  State<KbCapturePage> createState() => _KbCapturePageState();
}

class _KbCapturePageState extends State<KbCapturePage> {
  final _graph = AppGraph.instance;
  late final WebViewController _controller;

  double _progress = 0;
  String _title = '我的课表';
  bool _busy = false;
  bool _patched = false;

  /// 打补丁：拦 XHR 与 fetch，凡是像课表的响应就存进 window.__caiiKb。
  static const _patchScript = r'''
(function () {
  if (window.__caiiPatched) return 'already';
  window.__caiiPatched = true;
  window.__caiiKb = [];
  function looksLikeKb(text) {
    if (!text || text.length < 80) return false;
    return (text.indexOf('kcmc') >= 0 || text.indexOf('kbList') >= 0 ||
            text.indexOf('xskcb') >= 0 || text.indexOf('jcs') >= 0);
  }
  function stash(url, text) {
    try { if (looksLikeKb(text)) window.__caiiKb.push({ u: String(url || ''), t: String(text) }); } catch (e) {}
  }
  var open = XMLHttpRequest.prototype.open;
  var send = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function (m, u) { this.__caiiUrl = u; return open.apply(this, arguments); };
  XMLHttpRequest.prototype.send = function () {
    this.addEventListener('load', function () {
      try { stash(this.__caiiUrl, this.responseText); } catch (e) {}
    });
    return send.apply(this, arguments);
  };
  if (window.fetch) {
    var origFetch = window.fetch;
    window.fetch = function (input, init) {
      var url = (typeof input === 'string') ? input : (input && input.url);
      return origFetch.apply(this, arguments).then(function (res) {
        try { res.clone().text().then(function (t) { stash(url, t); }); } catch (e) {}
        return res;
      });
    };
  }
  return 'patched';
})();
''';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (!mounted) return;
            setState(() => _progress = value / 100);
          },
          onPageStarted: (_) {
            _patched = false;
          },
          onPageFinished: (url) async {
            final title = await _controller.getTitle();
            if (!mounted) return;
            setState(() {
              _progress = 1;
              if (title != null && title.trim().isNotEmpty) _title = title;
            });
            // 每页都补一次：单页应用切路由不会触发新页面加载
            await _injectPatch();
          },
          onUrlChange: (_) => _injectPatch(),
        ),
      );
    _load();
  }

  Future<void> _injectPatch() async {
    if (_patched) return;
    try {
      final result = await _controller.runJavaScriptReturningResult('true');
      AppLog.d('webview js ready: $result');
      await _controller.runJavaScript(_patchScript);
      _patched = true;
    } catch (e) {
      AppLog.e('注入课表监听失败', e);
    }
  }

  Future<void> _load() async {
    final url = PortalEndpoints.portalHomeUrl;
    await _injectCookies(url);
    await _controller.loadRequest(Uri.parse(url));
  }

  Future<void> _injectCookies(String url) async {
    final uri = Uri.parse(url);
    final manager = WebViewCookieManager();
    final merged = <String, String>{};
    for (final cookie in _graph.rawCookies.all()) {
      if (cookie.matchesHost(uri.host)) merged[cookie.name] = cookie.value;
    }
    for (final entry in merged.entries) {
      try {
        await manager.setCookie(
          WebViewCookie(
            name: entry.key,
            value: entry.value,
            domain: uri.host,
            path: '/',
          ),
        );
      } catch (_) {
        continue;
      }
    }
  }

  Future<void> _capture() async {
    setState(() => _busy = true);
    try {
      await _injectPatch();
      final raw = await _controller.runJavaScriptReturningResult(
        'JSON.stringify(window.__caiiKb || [])',
      );
      final text = raw.toString().replaceAll(RegExp(r'^"|"$'), '');
      final decoded = jsonDecode(
        text.startsWith('[') ? text : text.replaceAll(r'\"', '"'),
      );
      if (decoded is! List || decoded.isEmpty) {
        _toast('还没抓到课表数据：先在网页里点进「我的课表」，看到课表格子后再点这里');
        return;
      }

      // 取返回里信息量最大的那一段
      String best = '';
      for (final item in decoded) {
        if (item is Map && item['t'] is String) {
          final candidate = item['t'] as String;
          final count = 'kcmc'.allMatches(candidate).length;
          if (count > 'kcmc'.allMatches(best).length) best = candidate;
        }
      }
      if (best.isEmpty) {
        _toast('抓到的内容不像课表，换个学期再试');
        return;
      }

      final courses = _graph.jwxt.parseRaw(best);
      if (courses.isEmpty) {
        AppLog.e('课表 JSON 解析为空: ${best.substring(0, best.length > 300 ? 300 : best.length)}');
        _toast('抓到了数据但没认出课程字段，把日志发我');
        return;
      }

      await _graph.courseRepository.replaceImported(courses);
      _graph.schedule.load();
      _graph.home.refresh();
      if (!mounted) return;
      _toast('已导入 ${courses.length} 门课');
      context.pop();
    } catch (e) {
      AppLog.e('抓取课表失败', e);
      _toast(S.errUnknown);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: SysAppBar(
        title: _title,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _progress > 0 && _progress < 1
              ? LinearProgressIndicator(value: _progress, minHeight: 2)
              : const SizedBox(height: 2),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: WebViewWidget(controller: _controller)),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '在网页里进到「我的课表」看到课表后，点右边抓取',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _busy ? null : _capture,
                    child: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('抓取课表'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
