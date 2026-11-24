import 'package:flutter_modular/flutter_modular.dart';

import 'portal_webview_page.dart';

final webViewModule = createModule(
  path: '/webview',
  register: (c) {
    c.route('/', child: (ctx, state) => const PortalWebViewPage());
  },
);
