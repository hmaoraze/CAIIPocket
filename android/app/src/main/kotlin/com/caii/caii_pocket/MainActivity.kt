package com.caii.caii_pocket

import com.caii.caii_pocket.scan.WeChatScanPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 注册微信扫码引擎：MethodChannel "wechat_scan" + PlatformView "wechat_scan_view"
        WeChatScanPlugin.register(this, flutterEngine)
    }
}
