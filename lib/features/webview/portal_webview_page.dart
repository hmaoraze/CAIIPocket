import 'dart:io' show Cookie;

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/graph.dart';
import '../../core/log/app_logger.dart';
import '../../core/network/raw_cookie_store.dart';
import '../../core/strings.dart';
import '../../features/auth/auth_controller.dart';
import '../../services/portal/portal_endpoints.dart';
import '../../ui/appbar/sys_app_bar.dart';

/// 带会话的网页容器：门户、图书馆、扫码结果、以及"网页登录"兜底。
///
/// 三个方向都要同步：
///  * 进来之前，把本机 Cookie 写进 WebView，省得再登录一次；
///  * 页面落到「已登录」的校内域名时，**自动**把 WebView 的 Cookie 收回本机；
///  * 收回来立刻向服务端核实一次，成功才算登录成功——不然只是"抓到了字符串"。
class PortalWebViewPage extends StatefulWidget {
  const PortalWebViewPage({super.key});

  @override
  State<PortalWebViewPage> createState() => _PortalWebViewPageState();
}

class _PortalWebViewPageState extends State<PortalWebViewPage> {
  final _graph = AppGraph.instance;
  late final WebViewController _controller;

  double _progress = 0;
  String _title = '';
  bool _busy = false;
  bool _autoSynced = false;
  String _lastHost = '';

  /// 这次打开是「网页登录」还是「只是看看网页」。
  /// 浏览模式下绝不接管登录态——不然点一下门户就会冒"登录成功"。
  late final bool _adoptMode = _graph.navArgs.adoptSession;

  @override
  void initState() {
    super.initState();
    _title = _graph.navArgs.title;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (!mounted) return;
            setState(() => _progress = value / 100);
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url != null && url.isNotEmpty) _trackHost(url);
          },
          onPageFinished: (url) async {
            final title = await _controller.getTitle();
            if (!mounted) return;
            setState(() {
              _progress = 1;
              if (title != null && title.trim().isNotEmpty) _title = title;
            });
            _trackHost(url);
            await _maybeAutoSync(url);
          },
          onWebResourceError: (error) {
            AppLog.e('webview error: ${error.description} (${error.errorCode})');
          },
        ),
      );
    _load();
  }

  bool _isSchoolHost(String host) {
    final h = host.toLowerCase();
    return h.endsWith('caii.edu.cn') || h.endsWith('cctua.edu.cn');
  }

  bool _isAuthHost(String host) => host.toLowerCase().startsWith('authserver');

  void _trackHost(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.isNotEmpty) _lastHost = host;
  }

  Future<void> _load() async {
    final url = _graph.navArgs.url;
    if (url.isEmpty) return;
    await _injectCookies(url);
    await _controller.loadRequest(Uri.parse(url));
  }

  /// 把本机两份账（jar + 原始账本）里跟目标域名相关的 Cookie 灌进 WebView。
  Future<void> _injectCookies(String url) async {
    final uri = Uri.parse(url);
    final manager = WebViewCookieManager();
    final merged = <String, String>{};

    for (final cookie in await _graph.cookies.raw(
      '${uri.scheme}://${uri.host}',
    )) {
      merged[cookie.name] = cookie.value;
    }
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
    AppLog.d('向 WebView 注入 ${merged.length} 条 Cookie (${uri.host})');
  }

  /// 页面落到校内域名、且不是认证页时，自动同步一次。
  Future<void> _maybeAutoSync(String url) async {
    if (!_adoptMode || _autoSynced || _busy) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!_isSchoolHost(uri.host) || _isAuthHost(uri.host)) return;
    _autoSynced = true;
    final result = await _syncFromWebView(silent: true);
    if (result == AdoptResult.ok) {
      _autoSynced = true;
    } else {
      // 允许用户手动重试
      _autoSynced = false;
    }
  }

  /// 从 WebView 抓 Cookie → 写本机 → 向服务端核实。
  Future<AdoptResult> _syncFromWebView({bool silent = false}) async {
    if (!_adoptMode) return AdoptResult.empty;
    if (!mounted) return AdoptResult.empty;
    setState(() => _busy = true);

    final manager = WebViewCookieManager();
    final origins = <String>{
      PortalEndpoints.casOrigin,
      PortalEndpoints.portalOrigin,
      PortalEndpoints.jwOrigin,
      if (_lastHost.isNotEmpty) 'https://$_lastHost',
    };

    final collected = <RawCookie>[];
    for (final origin in origins) {
      final uri = Uri.parse(origin);
      try {
        final cookies = await manager.getCookies(domain: uri);
        if (cookies.isEmpty) continue;
        AppLog.d('WebView ${uri.host} 有 ${cookies.length} 条 Cookie');
        for (final cookie in cookies) {
          if (cookie.name.isEmpty) continue;
          collected.add(
            RawCookie(
              name: cookie.name,
              value: cookie.value,
              domain: cookie.domain.isEmpty ? uri.host : cookie.domain,
              path: cookie.path.isEmpty ? '/' : cookie.path,
            ),
          );
        }
        await _tryWriteJar(uri, cookies);
      } catch (e) {
        AppLog.e('读取 WebView Cookie 失败: ${uri.host}', e);
      }
    }

    // 同名的以 WebView 为准
    final dedup = <String, RawCookie>{};
    for (final cookie in collected) {
      dedup['${cookie.domain}|${cookie.name}'] = cookie;
    }

    final result = await _graph.auth.adoptRawCookies(dedup.values.toList());

    if (!mounted) return result;
    setState(() => _busy = false);

    switch (result) {
      case AdoptResult.ok:
        _graph.home.refresh();
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(const SnackBar(content: Text(S.sessionSynced)));
          context.pop();
        }
      case AdoptResult.cookieOnly:
        if (!silent) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(const SnackBar(content: Text(S.sessionNotAccepted)));
        }
      case AdoptResult.empty:
        if (!silent) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(const SnackBar(content: Text(S.noCookie)));
        }
    }
    return result;
  }

  /// 顺手往 cookie jar 里也塞一份：cookie_jar 校验不过的会自动跳过，
  /// 反正原始账本已经兜住了。
  Future<void> _tryWriteJar(Uri uri, List<WebViewCookie> cookies) async {
    final ioCookies = <Cookie>[];
    for (final cookie in cookies) {
      try {
        ioCookies.add(
          Cookie(cookie.name, cookie.value)
            ..domain = cookie.domain.isEmpty ? uri.host : cookie.domain
            ..path = '/',
        );
      } catch (_) {
        continue;
      }
    }
    if (ioCookies.isEmpty) return;
    try {
      await _graph.jar.saveFromResponse(uri, ioCookies);
    } catch (e) {
      AppLog.e('写 cookie jar 失败', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: SysAppBar(
        title: _title.isEmpty ? S.portalEntry : _title,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          if (_adoptMode)
            IconButton(
              onPressed: _busy ? null : () => _syncFromWebView(),
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            tooltip: S.syncSession,
          ),
          IconButton(
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
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
          if (_adoptMode)
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
                      S.webSyncHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _busy ? null : () => _syncFromWebView(),
                    child: Text(_busy ? S.syncing : S.syncSession),
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
