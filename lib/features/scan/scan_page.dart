import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/graph.dart';
import '../../core/strings.dart';
import '../../ui/appbar/sys_app_bar.dart';
import '../../ui/card/tonal_card.dart';
import '../../services/portal/portal_endpoints.dart';
import 'wechat_scan_view.dart';

/// 扫码引擎：MLKit（mobile_scanner）是默认主引擎，微信开源引擎是备用。
enum ScanEngine { mlkit, wechat }

/// 扫一扫：扫到校内链接就用已登录的会话直接打开（签到页就是这么用的）。
/// 双引擎：默认智能引擎（MLKit），10 秒没扫到自动切微信引擎（OpenCV），
/// 微信引擎额外支持变焦和 OPPO 等机型逻辑多摄里的物理长焦（远距离二维码）。
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _graph = AppGraph.instance;
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoStart: false,
  );
  final _manual = TextEditingController();
  final _wechat = WeChatScanChannel();

  String? _value;
  bool _handled = false;
  bool _torch = false;
  bool _permissionGranted = false;

  ScanEngine _engine = ScanEngine.mlkit;
  bool _switching = false;
  String? _telephotoId;
  bool _usingTele = false;
  double _zoom = 1.0;

  Timer? _autoTimer;
  StreamSubscription<String>? _resultSub;
  StreamSubscription<String>? _errorSub;

  @override
  void initState() {
    super.initState();
    _resultSub = _wechat.onResult.listen(_onWeChatResult);
    _errorSub = _wechat.onError.listen(_onWeChatError);
    _askCamera();
  }

  Future<void> _askCamera() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() => _permissionGranted = false);
      return;
    }
    setState(() => _permissionGranted = true);
    await _controller.start();
    _startAutoSwitchTimer();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _resultSub?.cancel();
    _errorSub?.cancel();
    _wechat.dispose();
    _controller.dispose();
    _manual.dispose();
    super.dispose();
  }

  // ---------- 智能引擎（MLKit，默认） ----------

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;
      _handled = true;
      _autoTimer?.cancel();
      _controller.stop();
      if (mounted) setState(() => _value = raw);
      _handle(raw);
      return;
    }
  }

  /// MLKit 起扫 10 秒没结果，自动切微信引擎（防重复：只在前台未扫到时触发一次）。
  void _startAutoSwitchTimer() {
    _autoTimer?.cancel();
    _autoTimer = Timer(const Duration(seconds: 10), () async {
      if (!mounted || _handled || _engine != ScanEngine.mlkit) return;
      _showSnack(S.scanSlowSwitch);
      await _switchEngine(ScanEngine.wechat);
    });
  }

  // ---------- 微信引擎 ----------

  void _onWeChatResult(String raw) {
    if (_handled || raw.trim().isEmpty) return;
    _handled = true;
    if (mounted) setState(() => _value = raw.trim());
    _handle(raw.trim());
  }

  void _onWeChatError(String message) {
    if (!mounted || _engine != ScanEngine.wechat) return;
    _showSnack('$message，已回退智能引擎');
    _switchEngine(ScanEngine.mlkit);
  }

  Future<void> _loadLensInfo() async {
    try {
      final catalog = await _wechat.lensInfo();
      if (!mounted) return;
      setState(() => _telephotoId = catalog.telephotoId);
    } catch (_) {
      // 查不到镜头信息就不显示长焦按钮
    }
  }

  Future<void> _setZoom(double zoom) async {
    final wasTele = _usingTele;
    setState(() {
      _zoom = zoom;
      _usingTele = false;
    });
    if (wasTele) await _wechat.setLens(null);
    await _wechat.setZoom(zoom);
  }

  Future<void> _toggleTele() async {
    final on = !_usingTele;
    setState(() => _usingTele = on);
    await _wechat.setLens(on ? _telephotoId : null);
    if (!on) await _wechat.setZoom(_zoom);
  }

  // ---------- 引擎切换 ----------

  Future<void> _switchEngine(ScanEngine engine) async {
    if (_engine == engine || _switching) return;
    _autoTimer?.cancel();
    if (engine == ScanEngine.wechat) {
      _switching = true;
      final ok = await _wechat.ensureInitialized();
      if (!mounted) {
        _switching = false;
        return;
      }
      if (!ok) {
        _switching = false;
        _showSnack(S.scanWeChatInitFailed);
        return;
      }
      // 相机同时只能被一边占用：先停 MLKit 再上原生预览
      await _controller.stop();
      setState(() {
        _engine = engine;
        _switching = false;
        _usingTele = false;
        _zoom = 1.0;
        _telephotoId = null;
      });
      _loadLensInfo();
    } else {
      await _wechat.disposeView();
      setState(() => _engine = engine);
      await _controller.start();
      _startAutoSwitchTimer();
    }
  }

  // ---------- 结果处理（两个引擎共用） ----------

  Future<void> _handle(String raw) async {
    final uri = Uri.tryParse(raw.trim());
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final school = PortalEndpoints.isSchoolHost(uri.host);
      _graph.navArgs.openUrl(raw.trim(), school ? '签到 / 校内页面' : uri.host);
      await context.pushNamed('/webview');
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('扫到的不是链接，已复制')));
    await Clipboard.setData(ClipboardData(text: raw.trim()));
  }

  void _rescan() {
    setState(() {
      _handled = false;
      _value = null;
    });
    if (_engine == ScanEngine.wechat) {
      _wechat.resume();
    } else {
      _controller.start();
      _startAutoSwitchTimer();
    }
  }

  Future<void> _toggleTorch() async {
    if (_engine == ScanEngine.wechat) {
      await _wechat.setTorch(!_torch);
    } else {
      await _controller.toggleTorch();
    }
    setState(() => _torch = !_torch);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 微信引擎激活时的变焦 / 长焦控制。
  List<Widget> _wechatControls(ThemeData theme) {
    return [
      TonalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.scanEngineWeChat, style: theme.textTheme.labelLarge),
            if (_telephotoId != null) ...[
              const SizedBox(height: 4),
              Text(
                S.scanWeChatTeleHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final z in const [1.0, 2.0, 5.0])
                  ChoiceChip(
                    label: Text('${z.toInt()}x'),
                    selected: _zoom == z && !_usingTele,
                    onSelected: (_) => _setZoom(z),
                  ),
                if (_telephotoId != null)
                  ChoiceChip(
                    label: const Text('长焦'),
                    selected: _usingTele,
                    onSelected: (_) => _toggleTele(),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: SysAppBar(
        title: S.scanTitle,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: SegmentedButton<ScanEngine>(
              segments: const [
                ButtonSegment(
                  value: ScanEngine.mlkit,
                  label: Text(S.scanEngineSmart),
                ),
                ButtonSegment(
                  value: ScanEngine.wechat,
                  label: Text(S.scanEngineWeChat),
                ),
              ],
              selected: {_engine},
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onSelectionChanged: (selection) => _switchEngine(selection.first),
            ),
          ),
          IconButton(
            onPressed: _toggleTorch,
            icon: Icon(
              _torch ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!_permissionGranted)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.no_photography_outlined,
                            size: 40,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            S.scanCameraDenied,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.tonal(
                            onPressed: () async {
                              await openAppSettings();
                            },
                            child: const Text('去系统设置'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_engine == ScanEngine.wechat)
                  const WeChatScanNativeView()
                else
                  MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.no_photography_outlined,
                            size: 40,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            S.scanCameraDenied,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // 取景框
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                if (_engine == ScanEngine.wechat) ..._wechatControls(theme),
                Text(
                  S.scanHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                if (_value != null) ...[
                  TonalCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('扫到的内容', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 6),
                        SelectableText(
                          _value!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            FilledButton.tonal(
                              onPressed: () => _handle(_value!),
                              child: const Text(S.scanOpen),
                            ),
                            const SizedBox(width: 10),
                            TextButton(
                              onPressed: _rescan,
                              child: const Text(S.scanRescan),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else
                  TonalCard(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: Text(
                        S.scanEmpty,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _manual,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: S.scanManual,
                    hintText: S.scanManualHint,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final text = _manual.text.trim();
                      if (text.isEmpty) return;
                      setState(() => _value = text);
                      _handle(text);
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text(S.scanOpen),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
