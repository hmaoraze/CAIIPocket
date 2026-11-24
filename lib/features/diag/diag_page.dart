import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../core/graph.dart';
import '../../core/log/log_buffer.dart';
import '../../core/strings.dart';
import '../../features/auth/auth_controller.dart';
import '../../services/jwxt/jwxt_service.dart';
import '../../ui/appbar/sys_app_bar.dart';
import '../../ui/card/tonal_card.dart';
import '../../ui/widget/content_section.dart';

/// 诊断：把"会话到底通没通"这件事摊开给人看。
///
/// 没带调试线的场景下，这里是唯一的自证页面：会话可用性、两份 Cookie 账本、
/// 教务接口探测结果、最近日志，全在一屏。
class DiagPage extends StatefulWidget {
  const DiagPage({super.key});

  @override
  State<DiagPage> createState() => _DiagPageState();
}

class _DiagPageState extends State<DiagPage> {
  final _graph = AppGraph.instance;

  bool _busy = false;
  bool? _alive;
  List<JwxtProbe> _probes = const [];

  Future<void> _checkSession() async {
    setState(() => _busy = true);
    try {
      final alive = await _graph.auth.verifyNow();
      if (mounted) setState(() => _alive = alive);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 本机已经有能用的 Cookie，但会话记录丢了：直接按 Cookie 接管。
  Future<void> _adoptLocal() async {
    setState(() => _busy = true);
    try {
      final result =
          await _graph.auth.adoptRawCookies(_graph.rawCookies.all());
      if (!mounted) return;
      setState(() => _alive = result == AdoptResult.ok);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              switch (result) {
                AdoptResult.ok => S.sessionSynced,
                AdoptResult.cookieOnly => S.sessionNotAccepted,
                AdoptResult.empty => S.noCookie,
              },
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _probeJwxt() async {    setState(() => _busy = true);
    try {
      final probes = await _graph.jwxt.probe(
        _graph.settings.read('jw_base_url') ?? JwxtService.defaultBase,
      );
      if (mounted) setState(() => _probes = probes);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: SysAppBar(
        title: S.diagTitle,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            onPressed: () {
              LogBuffer.instance.clear();
              setState(() {});
            },
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: Observer(
        builder: (_) {
          final auth = _graph.auth;
          final summary = _graph.rawCookies.summary();
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const ContentSection(title: S.diagSession),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TonalCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            auth.loggedIn
                                ? Icons.verified_user_outlined
                                : Icons.person_off_outlined,
                            size: 18,
                            color: auth.loggedIn ? scheme.primary : scheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              auth.loggedIn
                                  ? '${auth.session.value?.username ?? ""} · 本机已记录会话'
                                  : '本机没有会话记录',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _alive == null
                            ? '还没探测'
                            : '服务端探测：${_alive! ? S.diagAlive : S.diagDead}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _alive == null
                              ? scheme.onSurfaceVariant
                              : (_alive! ? scheme.primary : scheme.error),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: _busy ? null : _checkSession,
                            child: const Text(S.diagCheck),
                          ),
                          OutlinedButton(
                            onPressed: _busy ? null : _adoptLocal,
                            child: const Text('用本机 Cookie 接管'),
                          ),
                          OutlinedButton(
                            onPressed: _busy ? null : _probeJwxt,
                            child: const Text('探测教务'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const ContentSection(title: S.diagCookies),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TonalCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${S.diagRaw}：${_graph.rawCookies.count} 条',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in summary.entries)
                            Chip(
                              label: Text('${entry.key} × ${entry.value}'),
                            ),
                          if (summary.isEmpty)
                            Text(
                              '原始账本是空的',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'cookie jar 计数：${auth.cookieCount.value}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_probes.isNotEmpty) ...[
                const ContentSection(title: S.importProbe),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TonalCard(
                    child: Column(
                      children: [
                        for (final probe in _probes)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${probe.status}  ${probe.label}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: probe.looksAlive
                                        ? scheme.primary
                                        : scheme.onSurface,
                                  ),
                                ),
                                Text(
                                  '${probe.note}  ${probe.url}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const ContentSection(title: S.diagLogs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TonalCard(
                  child: SelectableText(
                    LogBuffer.instance.lines.take(60).join('\n'),
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      fontFamily: 'monospace',
                    ),
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
