import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../core/graph.dart';
import '../../core/strings.dart';
import '../../core/theme/color_type.dart';
import '../../ui/appbar/sys_app_bar.dart';
import '../../ui/card/tonal_card.dart';
import '../../ui/widget/content_section.dart';
import '../../ui/widget/settings_list.dart';
import '../../ui/widget/split_list_row.dart';

/// 外观：主题三态、纯黑、动态取色、种子色、配色方案、字体大小。
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppGraph.instance.theme;
    return Scaffold(
      appBar: SysAppBar(
        title: S.appearance,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Observer(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const ContentSection(title: S.themeMode),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text(S.themeSystem),
                      icon: Icon(Icons.brightness_auto_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(S.themeLight),
                      icon: Icon(Icons.light_mode_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(S.themeDark),
                      icon: Icon(Icons.dark_mode_outlined, size: 18),
                    ),
                  ],
                  selected: {theme.mode.value},
                  onSelectionChanged: (value) => theme.setMode(value.first),
                ),
              ),
              const SizedBox(height: 16),
              SettingsList(
                children: [
                  SplitListRow(
                    title: S.dynamicColor,
                    subtitle: S.dynamicColorTip,
                    leading: const Icon(Icons.wallpaper_outlined),
                    showChevron: false,
                    trailing: Switch(
                      value: theme.useDynamicColor.value,
                      onChanged: theme.setUseDynamicColor,
                    ),
                  ),
                  SplitListRow(
                    title: S.pureBlack,
                    subtitle: 'OLED 屏更省电，深色模式下生效',
                    leading: const Icon(Icons.contrast_outlined),
                    showChevron: false,
                    trailing: Switch(
                      value: theme.pureBlack.value,
                      onChanged: theme.setPureBlack,
                    ),
                  ),
                ],
              ),
              const ContentSection(title: S.seedColor),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TonalCard(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final color in SeedPalette.values)
                        GestureDetector(
                          onTap: () => theme.setSeed(color),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.seed.value.toARGB32() ==
                                        color.toARGB32()
                                    ? scheme.onSurface
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: theme.seed.value.toARGB32() ==
                                    color.toARGB32()
                                ? const Icon(Icons.check_rounded,
                                    size: 18, color: Colors.white)
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const ContentSection(title: S.colorType),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final type in ColorType.values)
                      ChoiceChip(
                        label: Text(type.label),
                        selected: theme.colorType.value == type,
                        onSelected: (_) => theme.setColorType(type),
                      ),
                  ],
                ),
              ),
              const ContentSection(title: S.textScale),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TonalCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('A', style: TextStyle(fontSize: 12)),
                          Expanded(
                            child: Slider(
                              value: theme.textScale.value,
                              min: 0.9,
                              max: 1.3,
                              divisions: 8,
                              label:
                                  '${(theme.textScale.value * 100).round()}%',
                              onChanged: theme.setTextScale,
                            ),
                          ),
                          const Text('A', style: TextStyle(fontSize: 20)),
                        ],
                      ),
                      Text(
                        '调大后全局文字都会跟着放大，列表和卡片高度自适应。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
