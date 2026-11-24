import 'dart:typed_data';

import 'package:mobx/mobx.dart';

import '../../core/log/app_logger.dart';
import '../../core/network/cookie_store.dart';
import '../../core/network/error_mapper.dart';
import '../../core/network/raw_cookie_store.dart';
import '../../models/auth/portal_session.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../services/cas/cas_auth_service.dart';
import '../../services/portal/portal_api.dart';
import '../../services/portal/portal_endpoints.dart';

/// 从网页登录同步会话的结果，给 UI 决定提示语。
enum AdoptResult {
  /// 会话可用，已写入登录态
  ok,

  /// 抓到了 Cookie，但服务端不认（多半是没真正登进去）
  cookieOnly,

  /// 一条 Cookie 都没抓到
  empty,
}

/// 登录态的唯一真相源。任何页面判断"有没有登录"都看这里。
class AuthController {
  AuthController(
    this._repo,
    this._cas,
    this._cookies,
    this._settings,
    this._raw,
    this._portal,
  ) {
    session.value = _repo.stored;
    lastUsername = _settings.lastUsername ?? '';
  }

  final AuthRepository _repo;
  final CasAuthService _cas;
  final CookieStore _cookies;
  final SettingsRepository _settings;
  final RawCookieStore _raw;
  final PortalApi _portal;

  final session = Observable<PortalSession?>(null);
  final checking = Observable(false);
  final loggingIn = Observable(false);
  final error = Observable<String?>(null);
  final needCaptcha = Observable(false);
  final captcha = Observable<Uint8List?>(null);

  /// jar 与原始账本里较多的那个数——只报 jar 会出现"明明有会话却显示 0 条"。
  final cookieCount = Observable(0);

  String lastUsername = '';

  /// 这些是页面标题，不是人名——抓取时万一取到，不能当姓名写进去。
  static const _nonNameTexts = {
    '个人中心', '个人信息', '账号', '我的', '首页', '退出登录', '设置', '安全中心',
  };

  bool get loggedIn => session.value != null;

  Future<void> _refreshCookieCount() async {
    final jarCount = await _cookies.count();
    final rawCount = _raw.count;
    cookieCount.value = jarCount > rawCount ? jarCount : rawCount;
    AppLog.d('cookie 统计: jar=$jarCount raw=$rawCount');
  }

  /// 冷启动：先用本机记录点亮界面，再向服务器核实一次。
  ///
  /// 还有个自愈分支：本机存着能用的 Cookie，但会话记录丢了（重装、清数据、
  /// 上次同步中途失败都会这样）——这时直接按现有 Cookie 接管登录态，
  /// 用户不必再登一次。
  Future<void> bootstrap() async {
    checking.value = true;
    try {
      await _refreshCookieCount();

      if (session.value == null) {
        if (cookieCount.value > 0) {
          final alive = await _repo.checkSession();
          AppLog.d('冷启动用现有 Cookie 核实: ${alive ? '有效' : '失效'}');
          if (alive) {
            await _adopt(
              lastUsername.isEmpty ? '统一认证用户' : lastUsername,
            );
          }
        }
        return;
      }

      final alive = await _repo.checkSession();
      AppLog.d('启动核实会话: ${alive ? '有效' : '失效'}');
      if (!alive) {
        runInAction(() => session.value = null);
        return;
      }
      // 老会话只存了占位名/页面标题，顺手补一次真实姓名与院系。
      final current = session.value;
      if (current != null &&
          (current.department.isEmpty ||
              _nonNameTexts.contains(current.displayName))) {
        await refreshProfile();
      }
    } finally {
      checking.value = false;
    }
  }

  Future<void> refreshSession() async {
    checking.value = true;
    try {
      final alive = await _repo.checkSession();
      if (!alive) runInAction(() => session.value = null);
      await _refreshCookieCount();
    } finally {
      checking.value = false;
    }
  }

  Future<bool> login({
    required String username,
    required String password,
    String? captchaCode,
  }) async {
    if (loggingIn.value) return false;
    loggingIn.value = true;
    runInAction(() => error.value = null);
    try {
      final result = await _repo.login(
        username: username,
        password: password,
        captcha: captchaCode,
      );
      if (result.success) {
        lastUsername = username;
        runInAction(() {
          session.value = _repo.stored;
          needCaptcha.value = false;
          captcha.value = null;
          error.value = null;
        });
        await _refreshCookieCount();
        return true;
      }

      runInAction(() {
        error.value = result.message;
        needCaptcha.value = result.needCaptcha;
      });
      if (result.needCaptcha) {
        captcha.value = await _cas.captchaImage();
      }
      return false;
    } catch (e) {
      runInAction(() => error.value = mapError(e));
      return false;
    } finally {
      loggingIn.value = false;
    }
  }

  /// 网页登录回来后：把抓到的 Cookie 收进本机，再向服务端确认一次。
  ///
  /// 顺序很重要——先落盘再验证，验证失败也留着 Cookie（下次续期还能用）。
  Future<AdoptResult> adoptRawCookies(List<RawCookie> imported) async {
    if (imported.isEmpty) {
      await _refreshCookieCount();
      return AdoptResult.empty;
    }

    await _raw.merge(imported);
    AppLog.d('从网页同步 ${imported.length} 条 Cookie: '
        '${imported.map((c) => c.name).join(",")}');
    await _refreshCookieCount();

    var alive = await _repo.checkSession();
    if (!alive) {
      AppLog.d('直接验证没过，尝试用 CASTGC 续期');
      alive = await _repo.renew();
    }

    if (!alive) {
      runInAction(() => error.value = '抓到了 Cookie，但服务端不认这次会话，请重登一次');
      return AdoptResult.cookieOnly;
    }

    final username = lastUsername.isEmpty ? '统一认证用户' : lastUsername;
    await _adopt(username);
    return AdoptResult.ok;
  }

  /// 兼容旧入口：只按用户名校准一次。
  Future<bool> adoptWebSession(String username) async {
    final alive = await _repo.checkSession();
    if (!alive) return false;
    await _adopt(username);
    return true;
  }

  Future<void> _adopt(String fallbackName) async {
    var username = fallbackName;
    var displayName = fallbackName;
    var avatarUrl = '';
    var department = '';

    // 会话已经通了，顺手把真名和学号捞出来——比"统一认证用户"有用得多。
    final info = await _portal.fetchUserInfo();
    if (info != null) {
      final name = info['userName'];
      final id = info['userId'];
      final photo = info['userPhoto'];
      final dept = info['userDepartment'];
      if (id is String && id.trim().isNotEmpty) username = id.trim();
      if (name is String && name.trim().isNotEmpty) displayName = name.trim();
      if (photo is String && photo.trim().isNotEmpty) {
        avatarUrl = _absoluteAvatar(photo.trim());
      }
      if (dept is String && dept.trim().isNotEmpty) department = dept.trim();
    }

    final restored = PortalSession(
      username: username,
      displayName: displayName,
      loggedInAt: DateTime.now(),
      avatarUrl: avatarUrl,
      department: department,
    );
    await _repo.saveSession(restored);
    runInAction(() {
      session.value = restored;
      error.value = null;
    });
    await _refreshCookieCount();
    AppLog.d('会话已接管: $displayName($username)');
  }

  Future<void> logout() async {
    loggingIn.value = true;
    try {
      await _repo.logout();
      await _raw.clear();
      runInAction(() {
        session.value = null;
        error.value = null;
        needCaptcha.value = false;
        captcha.value = null;
      });
      await _refreshCookieCount();
    } finally {
      loggingIn.value = false;
    }
  }

  /// 诊断用：现在这一刻，dio 到底还能不能进门户。
  Future<bool> verifyNow() async {
    final ok = await _cas.check();
    AppLog.d('诊断: 会话 ${ok ? '可用' : '不可用'}');
    return ok;
  }

  /// 从门户拉一次真实资料（姓名/学号/头像/院系）。
  Future<void> refreshProfile() async {
    final current = session.value;
    if (current == null) return;
    final info = await _portal.fetchUserInfo();
    if (info == null) return;

    final name = (info['userName'] as String?)?.trim() ?? '';
    final id = (info['userId'] as String?)?.trim() ?? '';
    final photo = _absoluteAvatar((info['userPhoto'] as String?)?.trim() ?? '');
    final dept = (info['userDepartment'] as String?)?.trim() ?? '';

    final next = PortalSession(
      username: id.isEmpty ? current.username : id,
      displayName: name.isEmpty ? current.displayName : name,
      loggedInAt: current.loggedInAt,
      avatarUrl: photo.isEmpty ? current.avatarUrl : photo,
      department: dept.isEmpty ? current.department : dept,
    );
    if (next.displayName == current.displayName &&
        next.department == current.department &&
        next.avatarUrl == current.avatarUrl &&
        next.username == current.username) {
      return;
    }
    await _repo.saveSession(next);
    runInAction(() => session.value = next);
    AppLog.d('资料已刷新: ${next.displayName} · ${next.department}');
  }

  /// 手动更正姓名/头像（个人信息页抓回来后调用）。
  Future<void> updateProfile({String? displayName, String? avatarUrl}) async {
    final current = session.value;
    if (current == null) return;
    final wanted = (displayName ?? '').trim();
    final safeName = wanted.isEmpty || _nonNameTexts.contains(wanted)
        ? current.displayName
        : wanted;

    final next = PortalSession(
      username: current.username,
      displayName: safeName,
      loggedInAt: current.loggedInAt,
      avatarUrl: (avatarUrl ?? '').trim().isEmpty
          ? current.avatarUrl
          : avatarUrl!.trim(),
      department: current.department,
    );
    await _repo.saveSession(next);
    runInAction(() => session.value = next);
    AppLog.d('资料已更新: ${next.displayName}');
  }

  /// 门户头像有时给相对路径，补成绝对地址才渲染得出来。
  String _absoluteAvatar(String value) {
    if (value.isEmpty) return value;
    if (value.startsWith('data:image')) return value;
    if (value.startsWith('http')) return value;
    if (value.startsWith('/')) return '${PortalEndpoints.portalOrigin}$value';
    return value;
  }

  void clearError() => runInAction(() => error.value = null);
}
