import 'package:flutter_modular/flutter_modular.dart';

import 'profile_page.dart';

final profileModule = createModule(
  path: '/profile',
  register: (c) {
    c.route('/', child: (ctx, state) => const ProfilePage());
  },
);
