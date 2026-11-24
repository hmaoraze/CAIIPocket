import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'core/graph.dart';
import 'core/strings.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppGraph.instance.theme;
    return Observer(
      builder: (_) {
        Widget app(Color? lightSeed, Color? darkSeed) {
          return MaterialApp.router(
            title: S.appName,
            debugShowCheckedModeBanner: false,
            routerConfig: ModularApp.routerConfigOf(context),
            theme: theme.light(lightSeed),
            darkTheme: theme.dark(darkSeed),
            themeMode: theme.mode.value,
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [
              Locale('zh', 'CN'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  textScaler: TextScaler.linear(theme.textScale.value),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        }

        if (!theme.useDynamicColor.value) return app(null, null);

        return DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) => app(
            lightDynamic?.primary,
            darkDynamic?.primary,
          ),
        );
      },
    );
  }
}
