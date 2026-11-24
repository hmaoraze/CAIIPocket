import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 长焦/物理镜头信息（来自原生 lensInfo）。
class WeChatLensInfo {
  const WeChatLensInfo({
    required this.id,
    required this.focalLengths,
    required this.isTelephoto,
  });

  final String id;
  final List<double> focalLengths;
  final bool isTelephoto;

  factory WeChatLensInfo.fromMap(Map<Object?, Object?> map) {
    final focals = (map['focalLengths'] as List? ?? const [])
        .map((e) => (e as num).toDouble())
        .toList();
    return WeChatLensInfo(
      id: map['id']?.toString() ?? '',
      focalLengths: focals,
      isTelephoto: map['isTelephoto'] == true,
    );
  }
}

/// lensInfo 的整体返回：物理镜头列表 + 推荐长焦 id。
class WeChatLensCatalog {
  const WeChatLensCatalog({required this.cameras, this.telephotoId});

  final List<WeChatLensInfo> cameras;
  final String? telephotoId;

  factory WeChatLensCatalog.fromMap(Map<Object?, Object?> map) {
    final cameras = (map['cameras'] as List? ?? const [])
        .map((e) => WeChatLensInfo.fromMap(Map<Object?, Object?>.from(e as Map)))
        .toList();
    return WeChatLensCatalog(
      cameras: cameras,
      telephotoId: map['telephotoId']?.toString(),
    );
  }
}

/// 微信引擎（OpenCV wechat_qrcode）的 Dart 侧封装：
/// MethodChannel("wechat_scan") 调用 + onResult/onError 事件流。
class WeChatScanChannel {
  static const MethodChannel _channel = MethodChannel('wechat_scan');

  final _onResult = StreamController<String>.broadcast();
  final _onError = StreamController<String>.broadcast();
  Future<bool>? _initFuture;

  /// 识别结果事件流（原生侧已做 3 秒去重）。
  Stream<String> get onResult => _onResult.stream;

  /// 相机/引擎错误事件流。
  Stream<String> get onError => _onError.stream;

  WeChatScanChannel() {
    _channel.setMethodCallHandler(_onMethodCall);
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onResult':
        _onResult.add(call.arguments?.toString() ?? '');
      case 'onError':
        _onError.add(call.arguments?.toString() ?? '微信引擎出错');
    }
    return null;
  }

  /// 初始化原生引擎（加载 OpenCV + 模型）。失败返回 false，可重试。
  Future<bool> ensureInitialized() {
    return _initFuture ??= _doInit();
  }

  Future<bool> _doInit() async {
    try {
      final result = await _channel.invokeMethod<String>('init');
      return result == 'ok';
    } catch (_) {
      _initFuture = null; // 允许下次重试
      return false;
    }
  }

  /// 查询物理镜头（长焦）信息。
  Future<WeChatLensCatalog> lensInfo() async {
    final data = await _channel.invokeMapMethod<String, Object?>('lensInfo');
    return WeChatLensCatalog.fromMap(data ?? const {});
  }

  /// 切换物理镜头；null = 逻辑主摄。
  Future<void> setLens(String? physicalId) =>
      _channel.invokeMethod('setLens', {'physicalId': physicalId});

  Future<void> setZoom(double ratio) =>
      _channel.invokeMethod('setZoom', {'ratio': ratio});

  Future<void> setTorch(bool on) => _channel.invokeMethod('setTorch', {'on': on});

  /// 原生识别成功后会自动暂停分析；重新扫之前调用恢复。
  Future<void> resume() => _channel.invokeMethod('resume');

  Future<void> disposeView() => _channel.invokeMethod('disposeView');

  void dispose() {
    disposeView();
    _onResult.close();
    _onError.close();
    _channel.setMethodCallHandler(null);
  }
}

/// 原生相机预览（PlatformView），viewType 由 WeChatScanPlugin 注册。
class WeChatScanNativeView extends StatelessWidget {
  const WeChatScanNativeView({super.key});

  @override
  Widget build(BuildContext context) {
    return const AndroidView(viewType: 'wechat_scan_view');
  }
}
