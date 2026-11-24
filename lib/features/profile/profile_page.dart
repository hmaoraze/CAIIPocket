import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/graph.dart';
import '../../core/log/app_logger.dart';
import '../../core/network/raw_cookie_store.dart';
import '../../core/strings.dart';
import '../../services/portal/portal_endpoints.dart';
import '../../ui/appbar/sys_app_bar.dart';
import '../../ui/widget/avatar_view.dart';

/// 个人信息页：把统一认证里的头像和姓名带到 App 里。
///
/// 个人信息应用（`/personalInfo/personalMobile/`）只有 CAS 会话能进，
/// 而且字段结构随学校定制，所以不写死解析——打开页面、抓页面渲染出来的
/// 头像 src 与姓名字符串，让用户确认一次再写入。
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _graph = AppGraph.instance;
  late final WebViewController _controller;

  double _progress = 0;
  String _title = '个人信息';
  bool _busy = false;
  String _currentUrl = '';
  String _lastStat = '';

  /// 页面停在 CAS 登录页时不能抓，先让用户登进去。
  bool get _onLoginPage => _currentUrl.contains('/authserver/login');

  /// 抓个人信息页上的头像与姓名。
  ///
  /// 实测这页的头像是 **base64 内联**：`<img class="p_card_personal_img" src="data:image/png;base64,...">`，
  /// 不是链接。所以既取 data URI 也兼容 http 图，并优先按页面里的类名定位，
  /// 避免抓到 logo 之类的小图标。
  static const _extractScript = r'''
(function () {
  function srcOf(el) {
    if (!el) return '';
    var src = el.currentSrc || el.src || '';
    if (!src) return '';
    if (src.indexOf('data:image') === 0) return src;
    if (src.indexOf('http') === 0) return src;
    return '';
  }
  function looksLikeIcon(el, src) {
    var cls = (el.className || '') + ' ' + (el.parentElement ? (el.parentElement.className || '') : '');
    if (/logo|icon|avatar_bg|background|bg_/i.test(cls)) return true;
    if (/logo|icon|sprite/i.test(src)) return true;
    var w = el.naturalWidth || 0;
    var h = el.naturalHeight || 0;
    if (w && w < 40) return true;
    if (w && h && (w / h > 1.8 || h / w > 1.8)) return true;
    return false;
  }

  var STOP = ['个人中心', '个人信息', '账号', '我的', '首页', '退出登录', '设置',
              '安全中心', '编辑', '保存', '手机号', '邮箱', '登录密码', '登录别名',
              '关联账号', '三方账号', '安全令牌', '偏好设置', '语言设置'];

  // 1) 先按类名找姓名元素
  var nameEl = document.querySelector(
    '[class*=personal_name], [class*=personalName], [class*=userName], [class*=user-name]'
  );

  // 2) 头像：页面上就是 <div class="personal_img"><img src="data:image/png;base64,..."></div>
  //    直接取这个元素，别绕。
  var avatar = '';
  var avatarEl = document.querySelector('.personal_img img, div.personal_img img');
  if (avatarEl) avatar = avatarEl.currentSrc || avatarEl.src || '';

  // 兜底：万一改版换了类名，就取页面里第一张够大的 base64 图
  if (!avatar) {
    var all = document.querySelectorAll('img');
    for (var i = 0; i < all.length; i++) {
      var src = all[i].currentSrc || all[i].src || '';
      if (src.indexOf('data:image') !== 0) continue;
      var w = all[i].width || all[i].naturalWidth || 0;
      if (w >= 56) { avatar = src; break; }
    }
  }
  var stat = 'avatarEl=' + (avatarEl ? 'yes' : 'no') + ' len=' + avatar.length;

  // 4) 姓名：取「杨宏茂 · 120262836」的第一段中文
  function pickName(text) {
    if (!text) return '';
    var parts = String(text).split(/[\s·|\/]+/);
    for (var p = 0; p < parts.length; p++) {
      var seg = parts[p].trim();
      if (!seg || seg.length < 2 || seg.length > 6) continue;
      if (STOP.indexOf(seg) >= 0) continue;
      if (!/^[\u4e00-\u9fa5]+$/.test(seg)) continue;
      return seg;
    }
    return '';
  }
  var name = pickName(nameEl ? nameEl.innerText : '');
  if (!name) {
    var card = document.querySelector('[class*=personal], .p_card');
    if (card) name = pickName(card.innerText);
  }

  return JSON.stringify({ avatar: avatar, name: name, stat: stat });
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
          onUrlChange: (change) {
            final url = change.url;
            if (url != null && url.isNotEmpty) _currentUrl = url;
          },
          onPageFinished: (url) async {
            _currentUrl = url;
            final title = await _controller.getTitle();
            if (!mounted) return;
            setState(() {
              _progress = 1;
              if (title != null && title.trim().isNotEmpty) _title = title;
            });
            // 个人信息页需要 CAS 会话：登录发生的这一跳要把 Cookie 收回来，
            // 之后再进就不用重复登录，也顺带补上了 CASTGC。
            if (url.contains('authservernew') && !url.contains('/login')) {
              await _syncCasCookies();
            }
          },
        ),
      );
    _load();
  }

  Future<void> _load() async {
    final uri = Uri.parse(PortalEndpoints.personalInfoUrl);
    final manager = WebViewCookieManager();
    for (final cookie in _graph.rawCookies.all()) {
      if (!cookie.matchesHost(uri.host)) continue;
      try {
        await manager.setCookie(
          WebViewCookie(
            name: cookie.name,
            value: cookie.value,
            domain: uri.host,
            path: '/',
          ),
        );
      } catch (_) {
        continue;
      }
    }
    await _controller.loadRequest(uri);
  }

  Future<void> _syncCasCookies() async {
    final manager = WebViewCookieManager();
    final collected = <RawCookie>[];
    for (final origin in _graph.cookies.origins) {
      final uri = Uri.parse(origin);
      try {
        final cookies = await manager.getCookies(domain: uri);
        for (final cookie in cookies) {
          if (cookie.name.isEmpty) continue;
          collected.add(
            RawCookie(
              name: cookie.name,
              value: cookie.value,
              domain: cookie.domain.isEmpty ? uri.host : cookie.domain,
            ),
          );
        }
      } catch (_) {
        continue;
      }
    }
    if (collected.isEmpty) return;
    await _graph.rawCookies.merge(collected);
    AppLog.d('个人信息页补齐 ${collected.length} 条 Cookie');
  }

  Future<void> _grab() async {
    if (_onLoginPage) {
      _toast('先在这个页面登录，登录完成后再点同步');
      return;
    }
    setState(() => _busy = true);
    try {
      final raw = await _controller.runJavaScriptReturningResult(_extractScript);
      final text = raw.toString().replaceAll(RegExp(r'^"|"$'), '');
      final decoded = jsonDecode(text.replaceAll(r'\"', '"'));
      var avatar = '';
      var name = '';
      if (decoded is Map) {
        avatar = (decoded['avatar'] as String? ?? '').trim();
        name = (decoded['name'] as String? ?? '').trim();
        _lastStat = (decoded['stat'] as String? ?? '').trim();
      }
      AppLog.d('个人信息抓取: name=$name avatarLen=${avatar.length} '
          'isData=${avatar.startsWith('data:image')} $_lastStat');
      if (avatar.isEmpty) {
        // 抓不到就把这块 DOM 打出来，下次照着真实类名改，不再靠猜
        try {
          final snippet = await _controller.runJavaScriptReturningResult(
            '(function(){var e=document.querySelector(".personal_img")||'
            'document.querySelector("[class*=personal]")||document.body;'
            'return (e.parentElement||e).outerHTML.slice(0,600);})()',
          );
          AppLog.d('头像 DOM 片段: $snippet');
        } catch (e) {
          AppLog.e('DOM 片段抓取失败', e);
        }
      }
      if (avatar.isEmpty && name.isEmpty) {
        _toast('没抓到头像或姓名：等页面加载完再点一次');
        return;
      }
      if (avatar.startsWith('data:image') && avatar.length > 120000) {
        final before = avatar.length;
        avatar = await AvatarSource.shrinkDataUri(avatar);
        AppLog.d('头像压缩: $before → ${avatar.length}');
      }
      await _graph.auth.updateProfile(displayName: name, avatarUrl: avatar);
      if (!mounted) return;
      _toast(
        '已更新：${name.isEmpty ? '姓名不变' : name}'
        '${avatar.isEmpty ? '（头像没抓到）' : '（头像 ${avatar.length} 字节）'}',
      );
      context.pop();
    } catch (e) {
      AppLog.e('抓取个人信息失败', e);
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
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                border: Border(
                  top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '页面加载出来后点右边，把这里的头像和姓名同步到「更多」',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _busy ? null : _grab,
                    child: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('同步头像'),
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
