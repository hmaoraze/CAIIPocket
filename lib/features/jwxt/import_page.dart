import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../core/graph.dart';
import '../../core/strings.dart';
import '../../services/jwxt/jwxt_service.dart';
import '../../ui/appbar/sys_app_bar.dart';
import '../../ui/card/tonal_card.dart';
import '../../ui/widget/content_section.dart';

/// 从教务导入课表：先单点登录，再按候选接口逐个探测，能对上的直接导入。
class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final _graph = AppGraph.instance;

  late final TextEditingController _base = TextEditingController(
    text: _graph.settings.read('jw_base_url') ?? JwxtService.defaultBase,
  );
  late final TextEditingController _year = TextEditingController(
    text: '${DateTime.now().month >= 9 ? DateTime.now().year : DateTime.now().year - 1}',
  );
  late final TextEditingController _term =
      TextEditingController(text: DateTime.now().month >= 2 && DateTime.now().month <= 8 ? '12' : '3');
  final _paste = TextEditingController();

  bool _busy = false;
  String? _message;
  String _raw = '';
  List<JwxtProbe> _probes = const [];

  @override
  void dispose() {
    _base.dispose();
    _year.dispose();
    _term.dispose();
    _paste.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _message = null;
      _raw = '';
      _probes = const [];
    });
    try {
      final result = await _graph.jwxt.importCourses(
        base: _base.text,
        academicYear: _year.text.trim(),
        term: _term.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _probes = result.probes;
        _raw = result.raw.length > 4000
            ? '${result.raw.substring(0, 4000)}\n…（已截断）'
            : result.raw;
        _message = result.ok ? null : result.message;
      });
      if (result.ok) {
        await _commit(result.courses);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importPasted() async {
    final text = _paste.text.trim();
    if (text.isEmpty) return;
    final courses = _graph.jwxt.parseRaw(text);
    if (courses.isEmpty) {
      setState(() => _message = S.importEmpty);
      return;
    }
    await _commit(courses);
  }

  Future<void> _commit(List<dynamic> courses) async {
    final count = await _graph.courseRepository.replaceImported(
      courses.cast(),
    );
    await _graph.settings.write('jw_base_url', _base.text.trim());
    _graph.schedule.load();
    _graph.home.refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text('${S.importDone} · $count 门课')));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: SysAppBar(
        title: S.importTitle,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Observer(
        builder: (_) {
          final loggedIn = _graph.auth.loggedIn;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              TonalCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loggedIn ? S.importIntro : S.loginRequiredBody,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (!loggedIn) ...[
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () =>
                            context.pushNamed('/login'),
                        child: const Text(S.loginAction),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TonalCard(
                child: Column(
                  children: [
                    TextField(
                      controller: _base,
                      decoration: const InputDecoration(
                        labelText: S.importBase,
                        hintText: 'https://jw.caii.edu.cn',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _year,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: S.importYear),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _term,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: S.importTerm),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                S.importOverwrite,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: loggedIn ? () => context.pushNamed('/kb-capture') : null,
                  icon: const Icon(Icons.travel_explore_rounded, size: 18),
                  label: const Text('在网页里抓课表（推荐）'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '课表在门户的「我的课表」里，需要一次性令牌才能进。用网页打开、你点进课表，\n'
                'App 会把页面自己拉到的课表数据截下来——学校改版也不受影响。',
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy || !loggedIn ? null : _run,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_busy ? S.importRunning : S.importRun),
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                TonalCard(
                  color: theme.colorScheme.errorContainer,
                  child: Text(
                    _message!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ],
              if (_probes.isNotEmpty) ...[
                const ContentSection(
                  title: S.importProbe,
                  padding: EdgeInsets.fromLTRB(0, 20, 0, 8),
                ),
                TonalCard(
                  child: Column(
                    children: [
                      for (final probe in _probes)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    probe.looksAlive
                                        ? Icons.check_circle_rounded
                                        : Icons.cancel_outlined,
                                    size: 16,
                                    color: probe.looksAlive
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${probe.label} · ${probe.status}',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 24, top: 2),
                                child: Text(
                                  '${probe.note}  ${probe.url}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (_raw.isNotEmpty) ...[
                const ContentSection(
                  title: '返回内容',
                  padding: EdgeInsets.fromLTRB(0, 20, 0, 8),
                ),
                TonalCard(
                  child: SelectableText(
                    _raw,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
              const ContentSection(
                title: S.importPaste,
                padding: EdgeInsets.fromLTRB(0, 24, 0, 8),
              ),
              TonalCard(
                child: Column(
                  children: [
                    TextField(
                      controller: _paste,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        hintText: S.importPasteHint,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _importPasted,
                        child: const Text(S.importPasteAction),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
