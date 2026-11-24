import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../core/graph.dart';
import '../../core/network/error_mapper.dart';
import '../../core/strings.dart';
import '../../services/portal/portal_endpoints.dart';
import '../../ui/appbar/sys_app_bar.dart';
import '../../ui/card/tonal_card.dart';

/// 接口调试台：带会话发一次 GET，把原始返回打出来。
///
/// 这是给"接了新接口还没校准"用的工作台——把路径填进去、把返回贴出来，
/// 下一版就能直接接到 UI 上，不用在电脑上折腾抓包。
class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  final _graph = AppGraph.instance;
  final _path = TextEditingController(
    text: PortalEndpoints.portalHomePath,
  );

  bool _busy = false;
  String? _result;
  String? _error;

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final path = _path.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final raw = await _graph.portal.getRaw(path);
      if (!mounted) return;
      setState(() {
        _result = raw.length > 20000
            ? '${raw.substring(0, 20000)}\n\n…（${S.debugTooLong}）'
            : raw;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mapError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SysAppBar(
        title: S.debugTitle,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TonalCard(
            child: Column(
              children: [
                TextField(
                  controller: _path,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '路径',
                    hintText: S.debugPathHint,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _send,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: const Text(S.debugSend),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            TonalCard(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          if (_result == null && _error == null)
            const TonalCard(child: Text(S.debugEmpty))
          else if (_result != null)
            TonalCard(
              child: SelectableText(
                _result!,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.5,
                  fontFamily: 'monospace',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
