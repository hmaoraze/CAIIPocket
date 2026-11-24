import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../core/graph.dart';
import '../../core/strings.dart';
import '../../ui/widget/avatar_view.dart';
import '../../core/theme/color_type.dart';
import '../../ui/card/tonal_card.dart';
import '../../ui/widget/content_section.dart';
import '../../ui/widget/settings_list.dart';
import '../../ui/widget/split_list_row.dart';
import '../../utils/date_x.dart';

/// 更多：账号、外观、数据与网络、关于。
class MorePage extends StatelessWidget {
  const MorePage({super.key, this.onOpenTab});

  final ValueChanged<int>? onOpenTab;

  @override
  Widget build(BuildContext context) {
    final graph = AppGraph.instance;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Observer(
          builder: (_) {
            final session = graph.auth.session.value;
            final loggedIn = session != null;
            return ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    S.moreTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: TonalCard(
                    onTap: loggedIn
                        ? () => context.pushNamed('/profile')
                        : () => context.pushNamed('/login'),
                    child: Row(
                      children: [
                        AvatarView(
                          size: 48,
                          name: session?.displayName ?? '',
                          avatar: session?.avatarUrl ?? '',
                          cookieHeader: session == null ||
                                  !session.avatarUrl.startsWith('http')
                              ? ''
                              : graph.rawCookies
                                  .headerFor(Uri.parse(session.avatarUrl).host),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loggedIn
                                    ? (session.department.isEmpty
                                        ? session.displayName
                                        : '${session.displayName} · ${session.department}')
                                    : S.notLoggedIn,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                loggedIn
                                    ? '${session.username} · 登录于 '
                                        '${DateX.monthDay(session.loggedInAt)} '
                                        '${DateX.hhmm(session.loggedInAt)}'
                                    : S.appSlogan,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!loggedIn)
                          FilledButton.tonal(
                            onPressed: () =>
                                context.pushNamed('/login'),
                            child: const Text(S.loginAction),
                          ),
                      ],
                    ),
                  ),
                ),
                const ContentSection(title: S.sectionAppearance),
                SettingsList(
                  children: [
                    SplitListRow(
                      title: S.appearance,
                      subtitle: '${_modeLabel(graph)} · ${graph.theme.colorType.value.label}',
                      leading: const Icon(Icons.palette_outlined),
                      onTap: () => context.pushNamed('/appearance'),
                    ),
                  ],
                ),
                const ContentSection(title: '工具'),
                SettingsList(
                  children: [
                    SplitListRow(
                      title: S.scanTitle,
                      subtitle: '扫码签到 / 校内链接带着会话直接打开',
                      leading: const Icon(Icons.qr_code_scanner_rounded),
                      onTap: () => context.pushNamed('/scan'),
                    ),
                    SplitListRow(
                      title: '一卡通',
                      subtitle: '浴池使用码查询 / 重新领取',
                      leading: const Icon(Icons.badge_outlined),
                      onTap: () => context.pushNamed('/ykt'),
                    ),
                    SplitListRow(
                      title: S.importTitle,
                      subtitle: '单点登录教务，自动抓课表',
                      leading: const Icon(Icons.download_rounded),
                      onTap: () => context.pushNamed('/import'),
                    ),
                    SplitListRow(
                      title: S.diagTitle,
                      subtitle: '会话、Cookie、日志一屏看全',
                      leading: const Icon(Icons.monitor_heart_outlined),
                      onTap: () => context.pushNamed('/diag'),
                    ),
                  ],
                ),
                const ContentSection(title: S.sectionData),
                SettingsList(
                  children: [
                    SplitListRow(
                      title: S.cookieManager,
                      subtitle: '本机已保存 ${graph.auth.cookieCount.value} 条',
                      leading: const Icon(Icons.cookie_outlined),
                      onTap: () => context.pushNamed('/cookies'),
                    ),
                    SplitListRow(
                      title: S.apiDebug,
                      subtitle: '带会话发一次 GET，看看门户回了什么',
                      leading: const Icon(Icons.terminal_rounded),
                      onTap: () => context.pushNamed('/debug'),
                    ),
                  ],
                ),
                if (loggedIn) ...[
                  const ContentSection(title: S.sectionAccount),
                  SettingsList(
                    children: [
                      SplitListRow(
                        title: '同步头像与姓名',
                        subtitle: '从统一认证的个人信息页取一次',
                        leading: const Icon(Icons.badge_outlined),
                        onTap: () => context.pushNamed('/profile'),
                      ),
                      SplitListRow(
                        title: S.logout,
                        leading: Icon(Icons.logout_rounded, color: scheme.error),
                        showChevron: false,
                        onTap: () => _confirmLogout(context, graph),
                      ),
                    ],
                  ),
                ],
                const ContentSection(title: S.sectionAbout),
                SettingsList(
                  children: [
                    SplitListRow(
                      title: S.about,
                      subtitle: S.privacyBody,
                      leading: const Icon(Icons.info_outline_rounded),
                      onTap: () => context.pushNamed('/about'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    '${S.appName} · ${S.appSlogan}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _modeLabel(AppGraph graph) => switch (graph.theme.mode.value) {
        ThemeMode.light => S.themeLight,
        ThemeMode.dark => S.themeDark,
        ThemeMode.system => S.themeSystem,
      };

  static Future<void> _confirmLogout(BuildContext context, AppGraph graph) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(S.logoutConfirmTitle),
        content: const Text(S.logoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(S.logout),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await graph.auth.logout();
    graph.home.refresh();
  }
}
