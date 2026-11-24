import 'package:flutter_modular/flutter_modular.dart';

import 'kb_capture_page.dart';

final kbCaptureModule = createModule(
  path: '/kb-capture',
  register: (c) {
    c.route('/', child: (ctx, state) => const KbCapturePage());
  },
);
