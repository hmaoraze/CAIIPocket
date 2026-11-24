import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:mobx/mobx.dart';

import 'app.dart';
import 'app_module.dart';
import 'core/graph.dart';
import 'core/log/app_logger.dart';
import 'core/storage/hive_boxes.dart';

Future<void> main() async {
  // MobX 2.7 起默认 writePolicy = observed：写"被观察的" Observable 必须在 action 里，
  // 否则 debug 构建直接抛断言（release 里断言被裁掉，于是"真机没事、调试崩"）。
  // 本项目的 store 都是显式 Observable、写入点分散在异步回调里，统一放开这条策略。
  mainContext.config = mainContext.config.clone(
    writePolicy: ReactiveWritePolicy.never,
  );

  WidgetsFlutterBinding.ensureInitialized();
  await HiveBoxes.init();
  await AppGraph.instance.bootstrap();
  AppLog.d('bootstrap done');
  runApp(ModularApp(module: appModule, child: const AppRoot()));
}
