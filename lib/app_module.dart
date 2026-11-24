import 'package:flutter_modular/flutter_modular.dart';

import 'features/about/about_route.dart';
import 'features/appearance/appearance_route.dart';
import 'features/course_edit/course_edit_route.dart';
import 'features/debug/debug_route.dart';
import 'features/diag/diag_route.dart';
import 'features/index/index_page.dart';
import 'features/kbimport/kb_capture_route.dart';
import 'features/jwxt/import_route.dart';
import 'features/login/login_route.dart';
import 'features/more/cookie_route.dart';
import 'features/profile/profile_route.dart';
import 'features/scan/scan_route.dart';
import 'features/webview/webview_route.dart';
import 'features/ykt/ykt_route.dart';

/// 根模块：一张表看清"这个 App 有哪些页面"。
final appModule = createModule(
  register: (c) {
    c
      ..route('/', child: (ctx, state) => const IndexPage())
      ..module(loginModule)
      ..module(courseEditModule)
      ..module(appearanceModule)
      ..module(cookieModule)
      ..module(debugModule)
      ..module(aboutModule)
      ..module(webViewModule)
      ..module(scanModule)
      ..module(yktModule)
      ..module(importModule)
      ..module(diagModule)
      ..module(kbCaptureModule)
      ..module(profileModule);
  },
);
