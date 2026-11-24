import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../core/graph.dart';
import '../../core/strings.dart';
import '../../ui/appbar/sys_app_bar.dart';
import '../../ui/card/tonal_card.dart';
import '../../ui/widget/empty_state_widget.dart';

/// Cookie 管理：看清本机到底存了什么，也能一键清空。
class CookiePage extends StatefulWidget {
  const CookiePage({super.key});

  @override
  State<CookiePage> createState() => _CookiePageState();
}

class _CookiePageState extends State<CookiePage> {
  final _graph = AppGraph.instance;
  late Future<List<String>> _future;

  @override
  void initState() {
    super.initState();
    _future = _graph.cookies.dump();
  }

  void _reload() {
    setState(() => _future = _graph.cookies.dump());
  }

  Future<void> _copyAll(List<String> lines) async {
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text(S.copied)));
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(S.clearCookies),
        content: const Text(S.clearCookiesBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(S.clearCookies),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _graph.auth.logout();
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text(S.cookiesCleared)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SysAppBar(
        title: S.cookieManager,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: S.retry,
          ),
          IconButton(
            onPressed: _clear,
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: S.clearCookies,
          ),
        ],
      ),
      body: FutureBuilder<List<String>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final lines = snapshot.data ?? const <String>[];
          if (lines.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.cookie_outlined,
              message: S.noCookie,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              TonalCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in lines)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: SelectableText(
                          line,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _copyAll(lines),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text(S.copy),
              ),
            ],
          );
        },
      ),
    );
  }
}
