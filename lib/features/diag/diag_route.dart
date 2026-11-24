import 'package:flutter_modular/flutter_modular.dart';

import 'diag_page.dart';

final diagModule = createModule(
  path: '/diag',
  register: (c) {
    c.route('/', child: (ctx, state) => const DiagPage());
  },
);
