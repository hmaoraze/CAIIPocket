/// 门户与统一认证的地址总表。改学校只改这一个文件。
class PortalEndpoints {
  const PortalEndpoints._();

  static const String portalOrigin = 'https://portal.caii.edu.cn';
  static const String casOrigin = 'https://authservernew.caii.edu.cn';

  /// 门户首页路径。同时作为 CAS 的 service 参数（登录成功后回到这里）。
  static const String portalHomePath =
      '/ywtb-portal/standard/index.html?browser=no';

  static String get portalHomeUrl => '$portalOrigin$portalHomePath';

  static String get serviceParam => Uri.encodeComponent(portalHomeUrl);

  static String get loginUrl =>
      '$casOrigin/authserver/login?service=$serviceParam';

  static String get logoutUrl => '$casOrigin/authserver/logout';

  static String get captchaUrl => '$casOrigin/authserver/getCaptcha.htl';

  /// 统一认证会话 Cookie 名（金智 CAS）。存在它就意味着"还能静默换票"。
  static const String casSessionCookie = 'CASTGC';

  // ---------------------------------------------------------------------------
  // 教务（金智 jwfw）实测结论：
  //   * 门户域名 https://jw.caii.edu.cn，选课应用挂在 /xsxkapp
  //   * CAS 入口 /xsxkapp/sys/xsxkapp/caiiXsxkLogin/casLogin.do
  //   * /jwglxt/... 在该域名下一律 404，所以课表接口要单独校准
  // ---------------------------------------------------------------------------
  /// 统一认证里的「个人信息」页（需要 CAS 会话）
  static const String personalInfoUrl =
      'https://authservernew.caii.edu.cn/personalInfo/personalMobile/index.html#/home';

  static const String jwOrigin = 'https://jw.caii.edu.cn';
  static const String jwXsxkLoginPath =
      '/xsxkapp/sys/xsxkapp/caiiXsxkLogin/casLogin.do';

  /// 校内域：凡是这些后缀的页面都值得带着会话打开。
  static const List<String> schoolDomains = ['caii.edu.cn', 'cctua.edu.cn'];

  static bool isSchoolHost(String host) {
    final h = host.toLowerCase();
    return schoolDomains.any((d) => h == d || h.endsWith('.$d'));
  }

  // ---------------------------------------------------------------------------
  // 门户业务接口：需要在真机登录后抓一次包把路径/字段对上。
  // 空字符串 = 未校准，UI 会显示「接口待校准」而不是假装有数据。
  // ---------------------------------------------------------------------------
  static const String apiUserInfo = '/ywtb-portal/openplatform/api/getUserInfo';
  static const String apiCardBalance = '';
  static const String apiCardBills = '';
  static const String apiElectricity = '';
  static const String apiSchedule = '';

  /// 图书馆（座位预约）系统地址，未配置时页面给出明确提示。
  static const String libraryUrl = '';

  static bool isCalibrated(String path) => path.isNotEmpty;

  static String absolute(String path) =>
      path.startsWith('http') ? path : '$portalOrigin$path';
}
