import 'package:flutter_modular/flutter_modular.dart';

import 'about_page.dart';

final aboutModule = createModule(
  path: '/about',
  register: (c) {
    c.route('/', child: (ctx, state) => const AboutPage());
  },
);
