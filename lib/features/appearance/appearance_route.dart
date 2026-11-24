import 'package:flutter_modular/flutter_modular.dart';

import 'appearance_page.dart';

final appearanceModule = createModule(
  path: '/appearance',
  register: (c) {
    c.route('/', child: (ctx, state) => const AppearancePage());
  },
);
