import 'dart:async';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../core/network/cookie_store.dart';
import '../core/network/dio_factory.dart';
import '../core/network/raw_cookie_store.dart';
import '../core/storage/hive_boxes.dart';
import '../core/theme/theme_provider.dart';
import '../features/auth/auth_controller.dart';
import '../features/focus/focus_controller.dart';
import '../features/home/home_controller.dart';
import '../features/schedule/schedule_controller.dart';
import '../repositories/auth_repository.dart';
import '../repositories/course_repository.dart';
import '../repositories/focus_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/cas/cas_auth_service.dart';
import '../services/jwxt/jwxt_service.dart';
import '../services/portal/portal_api.dart';
import '../services/schedule/semester_service.dart';

/// 跨页传递的临时参数（避免依赖路由参数解析）。
class NavArgs {
  String url = '';
  String title = '';
  String courseId = '';

  /// 扫码得到的原始内容（可能是 URL，也可能是一串文本）。
  String scanResult = '';

  /// true = 这次打开 WebView 的目的是「网页登录，登录完把会话收回来」；
  /// false = 只是浏览（门户/图书馆/签到页），不碰登录态。
  bool adoptSession = false;

  void openUrl(String url, String title, {bool adopt = false}) {
    this.url = url;
    this.title = title;
    adoptSession = adopt;
  }

  void editCourse(String id) {
    courseId = id;
  }

  void setScanResult(String value) {
    scanResult = value;
  }
}

/// 组合根：全应用唯一的依赖装配点。
///
/// 显式 new 出每个服务，比运行期反射式注入更容易读懂、也不会在改版本时
/// 因为容器 API 变了整片编译不过；路由与模块仍然交给 flutter_modular。
class AppGraph {
  AppGraph._();

  static final AppGraph instance = AppGraph._();

  late final PersistCookieJar jar;
  late final CookieStore cookies;
  late final RawCookieStore rawCookies;
  late final Dio dio;
  late final CasAuthService cas;
  late final PortalApi portal;
  late final JwxtService jwxt;

  late final SettingsRepository settings;
  late final AuthRepository authRepository;
  late final CourseRepository courseRepository;
  late final FocusRepository focusRepository;
  late final SemesterService semester;

  late final ThemeController theme;
  late final AuthController auth;
  late final HomeController home;
  late final ScheduleController schedule;
  late final FocusController focus;

  final navArgs = NavArgs();

  bool _ready = false;

  Future<void> bootstrap() async {
    if (_ready) return;

    final dir = await getApplicationSupportDirectory();
    final cookieDir = Directory('${dir.path}/cookies');
    if (!cookieDir.existsSync()) cookieDir.createSync(recursive: true);

    jar = PersistCookieJar(
      storage: FileStorage(cookieDir.path),
      ignoreExpires: false,
    );
    cookies = CookieStore(jar);
    rawCookies = RawCookieStore(HiveBoxes.rawCookieBox);
    dio = buildDio(jar, rawCookies: rawCookies);
    cas = CasAuthService(dio, cookies);
    portal = PortalApi(dio, cas);
    jwxt = JwxtService(dio, cas);

    settings = SettingsRepository();
    authRepository = AuthRepository(cas, settings, cookies);
    courseRepository = CourseRepository();
    focusRepository = FocusRepository();
    semester = SemesterService(settings);

    theme = ThemeController();
    auth = AuthController(
      authRepository,
      cas,
      cookies,
      settings,
      rawCookies,
      portal,
    );
    home = HomeController(courseRepository, focusRepository, semester, auth)
      ..start();
    schedule = ScheduleController(courseRepository, semester)..load();
    focus = FocusController(focusRepository)..restore();

    _ready = true;
    // 会话核实要联网，不能挡住首帧：先渲染，界面自己跟着 Observable 变。
    unawaited(auth.bootstrap());
  }
}
