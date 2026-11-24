import 'package:flutter_modular/flutter_modular.dart';

import 'import_page.dart';

final importModule = createModule(
  path: '/import',
  register: (c) {
    c.route('/', child: (ctx, state) => const ImportPage());
  },
);
