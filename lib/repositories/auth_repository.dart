import '../core/network/cookie_store.dart';
import '../core/storage/settings_keys.dart';
import '../models/auth/portal_session.dart';
import '../services/cas/cas_auth_service.dart';
import 'settings_repository.dart';

/// 认证仓储：把 CAS 调用与本机会话记录缝在一起。
class AuthRepository {
  AuthRepository(this._cas, this._settings, this.cookies);

  final CasAuthService _cas;
  final SettingsRepository _settings;
  final CookieStore cookies;

  PortalSession? get stored =>
      PortalSession.tryParse(_settings.read(SettingsKeys.sessionJson));

  Future<CasLoginResult> login({
    required String username,
    required String password,
    String? captcha,
  }) async {
    final result = await _cas.login(
      username: username,
      password: password,
      captcha: captcha,
    );
    if (result.success) {
      await saveSession(
        PortalSession(
          username: username,
          displayName: username,
          loggedInAt: DateTime.now(),
        ),
      );
      await _settings.setLastUsername(username);
    }
    return result;
  }

  Future<bool> checkSession() => _cas.check();

  Future<bool> renew() => _cas.renew();

  Future<void> saveSession(PortalSession session) =>
      _settings.write(SettingsKeys.sessionJson, session.encode());

  Future<void> logout() async {
    await _cas.logout();
    await _settings.remove(SettingsKeys.sessionJson);
  }
}
