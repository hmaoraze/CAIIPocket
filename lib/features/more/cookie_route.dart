import 'package:flutter_modular/flutter_modular.dart';

import 'cookie_page.dart';

final cookieModule = createModule(
  path: '/cookies',
  register: (c) {
    c.route('/', child: (ctx, state) => const CookiePage());
  },
);
