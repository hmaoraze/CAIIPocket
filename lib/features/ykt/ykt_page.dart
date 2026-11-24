import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../core/graph.dart';
import '../../services/ykt/ykt_service.dart';
import '../../ui/appbar/sys_app_bar.dart';
import '../../ui/card/tonal_card.dart';

/// 一卡通：浴池水控「使用码」查询与领取。
///
/// 平台认证即 UUID（抓包结论，见水控浴池使用码获取流程分析文档），
/// 首次使用需在小程序打开过使用码页面后，把 UUID 填进来。
class YktPage extends StatefulWidget {
  const YktPage({super.key});

  @override
  State<YktPage> createState() => _YktPageState();
}

class _YktPageState extends State<YktPage> {
  final _graph = AppGraph.instance;
  final _service = YktService();
  final _uuidCtrl = TextEditingController();

  YktUser? _user;
  bool _loading = false;
  bool _reissuing = false;
  bool _showFull = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _uuidCtrl.text = _graph.settings.read(SettingsKeysExt.yktUuid) ?? '';
    if (_uuidCtrl.text.isNotEmpty) _refresh();
  }

  @override
  void dispose() {
    _uuidCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveUuid() async {
    final uuid = _uuidCtrl.text.trim();
    if (uuid.isEmpty) return;
    await _graph.settings.write(SettingsKeysExt.yktUuid, uuid);
    await _refresh();
  }

  Future<void> _refresh() async {
    final uuid = _uuidCtrl.text.trim();
    if (uuid.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _service.getUser(uuid);
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _reissue() async {
    final uuid = _uuidCtrl.text.trim();
    setState(() => _reissuing = true);
    try {
      final user = await _service.reissueUseKey(uuid);
      if (!mounted) return;
      setState(() {
        _user = user;
        _reissuing = false;
      });
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('已领取新使用码')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _reissuing = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('领取失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uuid = _uuidCtrl.text.trim();

    return Scaffold(
      appBar: SysAppBar(
        title: '一卡通',
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            onPressed: uuid.isEmpty ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _uuidCard(theme),
          const SizedBox(height: 16),
          if (uuid.isNotEmpty) ...[
            if (_loading)
              const TonalCard(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              TonalCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('查询失败', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Text(_error!, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: _refresh, child: const Text('重试')),
                  ],
                ),
              )
            else if (_user != null) ...[
              _keyCard(theme),
              const SizedBox(height: 16),
              _userCard(theme),
            ],
          ],
        ],
      ),
    );
  }

  Widget _uuidCard(ThemeData theme) {
    return TonalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('平台 UUID', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            '认证即 UUID。可先用小程序打开一次「使用码」页面后从抓包获取，'
            '填入后即可在 APP 内查询与领取。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _uuidCtrl,
            decoration: const InputDecoration(
              labelText: 'UUID',
              hintText: '形如 8E4E60B1-F59C-4B89-...',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _uuidCtrl.text.trim().isEmpty ? null : _saveUuid,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('保存并查询'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _keyCard(ThemeData theme) {
    final user = _user!;
    return TonalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('使用码', style: theme.textTheme.labelLarge),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: user.enabled
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  user.enabled ? '已开启，可使用' : '已关闭',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: user.enabled
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: GestureDetector(
              onTap: () => setState(() => _showFull = !_showFull),
              child: Column(
                children: [
                  Text(
                    _showFull ? user.displayKey : '✱✱✱✱✱✱✱✱',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _showFull ? '点击隐藏（完整码 ${user.currentKey}）' : '点击查看',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _reissuing ? null : _reissue,
              icon: _reissuing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.autorenew_rounded, size: 18),
              label: const Text('重新领取使用码'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _userCard(ThemeData theme) {
    final user = _user!;
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 88,
                child: Text(
                  k,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: SelectableText(
                  v,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        );
    return TonalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('账户信息', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          row('姓名', user.name),
          row('账号', user.accountNo),
          row('卡号', user.cardNo),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: user.currentKey));
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(const SnackBar(content: Text('使用码已复制')));
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('复制使用码'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 设置键：与全局 SettingsKeys 解耦，避免并发开发冲突。
class SettingsKeysExt {
  const SettingsKeysExt._();
  static const String yktUuid = 'ykt_uuid';
}
