import 'package:flutter_modular/flutter_modular.dart';

import 'scan_page.dart';

final scanModule = createModule(
  path: '/scan',
  register: (c) {
    c.route('/', child: (ctx, state) => const ScanPage());
  },
);
