import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../core/graph.dart';
import '../../core/strings.dart';
import '../../services/portal/portal_endpoints.dart';
import '../../ui/card/tonal_card.dart';
import '../../ui/dialog/adaptive_sheet.dart';
import '../../ui/widget/content_section.dart';
import '../../ui/widget/settings_list.dart';
import '../../ui/widget/split_list_row.dart';

/// 校园：校园卡、电费、图书馆、门户入口。
class CampusPage extends StatefulWidget {
  const CampusPage({super.key});

  @override
  State<CampusPage> createState() => _CampusPageState();
}

class _CampusPageState extends State<CampusPage> {
  final _graph = AppGraph.instance;

  void _openWeb(String url, String title) {
    _graph.navArgs.openUrl(url, title);
    context.pushNamed('/webview');
  }

  Future<void> _showNotCalibrated(String title) {
    return showAdaptiveSheet<void>(
      context: context,
      title: title,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.apiNotCalibratedBody,
              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                context.pushNamed('/debug');
              },
              child: const Text(S.openDebugConsole),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Observer(
          builder: (_) {
            final loggedIn = _graph.auth.loggedIn;
            return ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    S.campusTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!loggedIn)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: TonalCard(
                      color: theme.colorScheme.primaryContainer,
                      onTap: () => context.pushNamed('/login'),
                      child: Row(
                        children: [
                          Icon(
                            Icons.key_rounded,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              S.loginRequiredBody,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const ContentSection(title: S.campusCard),
                SettingsList(
                  children: [
                    SplitListRow(
                      title: S.campusCardBalance,
                      subtitle: S.apiNotCalibrated,
                      value: S.balanceUnknown,
                      leading: const Icon(Icons.credit_card_outlined),
                      onTap: () => _showNotCalibrated(S.campusCardBalance),
                    ),
                    SplitListRow(
                      title: S.campusCardDetail,
                      subtitle: '按日 / 周 / 月汇总消费',
                      leading: const Icon(Icons.receipt_long_outlined),
                      onTap: () => _showNotCalibrated(S.campusCardDetail),
                    ),
                  ],
                ),
                const ContentSection(title: S.electricity),
                SettingsList(
                  children: [
                    SplitListRow(
                      title: S.electricityBalance,
                      subtitle: S.apiNotCalibrated,
                      value: S.balanceUnknown,
                      leading: const Icon(Icons.bolt_outlined),
                      onTap: () => _showNotCalibrated(S.electricityBalance),
                    ),
                  ],
                ),
                const ContentSection(title: '图书馆与门户'),
                SettingsList(
                  children: [
                    SplitListRow(
                      title: S.librarySeat,
                      subtitle: PortalEndpoints.libraryUrl.isEmpty
                          ? S.libraryNotConfigured
                          : '用已登录的会话直接打开',
                      leading: const Icon(Icons.event_seat_outlined),
                      onTap: () {
                        if (PortalEndpoints.libraryUrl.isEmpty) {
                          _showNotCalibrated(S.librarySeat);
                          return;
                        }
                        _openWeb(PortalEndpoints.libraryUrl, S.librarySeat);
                      },
                    ),
                    SplitListRow(
                      title: S.portalEntry,
                      subtitle: S.portalEntryTip,
                      leading: const Icon(Icons.public_rounded),
                      onTap: () =>
                          _openWeb(PortalEndpoints.portalHomeUrl, S.portalEntry),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}
