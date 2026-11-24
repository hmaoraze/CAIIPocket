import 'package:flutter_modular/flutter_modular.dart';

import 'course_edit_page.dart';

final courseEditModule = createModule(
  path: '/course-edit',
  register: (c) {
    c.route('/', child: (ctx, state) => const CourseEditPage());
  },
);
