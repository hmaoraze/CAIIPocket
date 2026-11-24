import 'package:flutter_modular/flutter_modular.dart';

import 'debug_page.dart';

final debugModule = createModule(
  path: '/debug',
  register: (c) {
    c.route('/', child: (ctx, state) => const DebugPage());
  },
);
