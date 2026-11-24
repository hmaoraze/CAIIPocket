import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mobx/mobx.dart';

import '../storage/hive_boxes.dart';
import '../storage/settings_keys.dart';
import 'color_type.dart';

/// 主题状态：跟随系统 / 浅色 / 深色 + 纯黑 + 动态取色 + 种子色 + 字体大小。
class ThemeController {
  ThemeController() {
    _load();
  }

  final mode = Observable(ThemeMode.system);
  final pureBlack = Observable(false);
  final useDynamicColor = Observable(true);
  final colorType = Observable(ColorType.tonalSpot);
  final seed = Observable(SeedPalette.values.first);
  final textScale = Observable(1.0);

  Box<String> get _box => HiveBoxes.settingsBox;

  void _load() {
    final b = _box;
    mode.value = _modeFrom(b.get(SettingsKeys.themeMode));
    pureBlack.value = b.get(SettingsKeys.pureBlack) == 'true';
    useDynamicColor.value = b.get(SettingsKeys.dynamicColor) != 'false';
    colorType.value = _colorTypeFrom(b.get(SettingsKeys.colorType));
    final seedValue = int.tryParse(b.get(SettingsKeys.seedColor) ?? '');
    if (seedValue != null) seed.value = Color(seedValue);
    textScale.value =
        double.tryParse(b.get(SettingsKeys.textScale) ?? '') ?? 1.0;
  }

  void setMode(ThemeMode value) {
    runInAction(() => mode.value = value);
    _box.put(SettingsKeys.themeMode, value.name);
  }

  void setPureBlack(bool value) {
    runInAction(() => pureBlack.value = value);
    _box.put(SettingsKeys.pureBlack, '$value');
  }

  void setUseDynamicColor(bool value) {
    runInAction(() => useDynamicColor.value = value);
    _box.put(SettingsKeys.dynamicColor, '$value');
  }

  void setColorType(ColorType value) {
    runInAction(() => colorType.value = value);
    _box.put(SettingsKeys.colorType, value.name);
  }

  void setSeed(Color value) {
    runInAction(() => seed.value = value);
    _box.put(SettingsKeys.seedColor, '${value.toARGB32()}');
  }

  void setTextScale(double value) {
    runInAction(() => textScale.value = value);
    _box.put(SettingsKeys.textScale, '$value');
  }

  ThemeData light(Color? dynamicSeed) => _build(Brightness.light, dynamicSeed);

  ThemeData dark(Color? dynamicSeed) => _build(Brightness.dark, dynamicSeed);

  ThemeData _build(Brightness brightness, Color? dynamicSeed) {
    final base = ColorScheme.fromSeed(
      seedColor: dynamicSeed ?? seed.value,
      brightness: brightness,
      dynamicSchemeVariant: colorType.value.variant,
    );

    final scheme = (brightness == Brightness.dark && pureBlack.value)
        ? base.copyWith(
            surface: Colors.black,
            surfaceContainerLowest: Colors.black,
            surfaceContainerLow: const Color(0xFF0C0C0C),
            surfaceContainer: const Color(0xFF121212),
            surfaceContainerHigh: const Color(0xFF1A1A1A),
            surfaceContainerHighest: const Color(0xFF232323),
          )
        : base;

    final radius = BorderRadius.circular(14);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHigh,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 0.6,
        space: 0.6,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 12,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.secondaryContainer,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
        selectedLabelTextStyle: TextStyle(color: scheme.onSurface),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outlineVariant),
          ),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 13)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        side: BorderSide.none,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static ThemeMode _modeFrom(String? value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static ColorType _colorTypeFrom(String? value) {
    for (final t in ColorType.values) {
      if (t.name == value) return t;
    }
    return ColorType.tonalSpot;
  }
}
