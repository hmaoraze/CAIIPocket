import 'package:flutter_modular/flutter_modular.dart';

import 'ykt_page.dart';

final yktModule = createModule(
  path: '/ykt',
  register: (c) {
    c.route('/', child: (ctx, state) => const YktPage());
  },
);
