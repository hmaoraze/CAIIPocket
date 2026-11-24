import 'package:flutter_modular/flutter_modular.dart';

import 'login_page.dart';

final loginModule = createModule(
  path: '/login',
  register: (c) {
    c.route('/', child: (ctx, state) => const LoginPage());
  },
);
