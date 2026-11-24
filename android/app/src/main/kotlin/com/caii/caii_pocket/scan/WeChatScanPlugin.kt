package com.caii.caii_pocket.scan

import android.app.Activity
import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * 微信引擎的 MethodChannel + PlatformView 注册入口。
 * Channel 名 "wechat_scan"，viewType "wechat_scan_view"。
 */
class WeChatScanPlugin private constructor(
    private val channel: MethodChannel,
    private val appContext: Context,
) : MethodChannel.MethodCallHandler {

    private val mainHandler = Handler(Looper.getMainLooper())

    /** 当前活跃的扫码视图（一般同一时刻只有一个） */
    private var view: WeChatScanView? = null

    companion object {
        const val CHANNEL_NAME = "wechat_scan"
        const val VIEW_TYPE = "wechat_scan_view"

        /** 在 MainActivity.configureFlutterEngine 里调用 */
        fun register(activity: Activity, engine: FlutterEngine) {
            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            val plugin = WeChatScanPlugin(channel, activity.applicationContext)
            channel.setMethodCallHandler(plugin)
            engine.platformViewsController.registry
                .registerViewFactory(VIEW_TYPE, WeChatScanViewFactory(plugin))
        }
    }

    // ---------- MethodChannel ----------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> initAsync(result)
            "lensInfo" -> result.success(queryLensInfo())
            "setLens" -> {
                view?.setPhysicalLens(call.argument<String>("physicalId"))
                result.success(null)
            }
            "setZoom" -> {
                view?.setZoom(call.argument<Double>("ratio") ?: 1.0)
                result.success(null)
            }
            "setTorch" -> {
                view?.setTorch(call.argument<Boolean>("on") == true)
                result.success(null)
            }
            "resume" -> {
                view?.resumeScan()
                result.success(null)
            }
            "disposeView" -> {
                view?.releaseCamera()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** 模型加载比较耗时，放后台线程跑，结果回主线程。 */
    private fun initAsync(result: MethodChannel.Result) {
        Thread {
            try {
                WeChatScanEngine.init(appContext)
                mainHandler.post { result.success("ok") }
            } catch (e: Throwable) {
                mainHandler.post {
                    result.error("init_failed", e.message ?: "微信引擎初始化失败", null)
                }
            }
        }.start()
    }

    // ---------- 事件回传（WeChatScanView 调用） ----------

    fun sendResult(text: String) {
        channel.invokeMethod("onResult", text)
    }

    fun sendError(message: String) {
        channel.invokeMethod("onError", message)
    }

    fun attachView(v: WeChatScanView) {
        view = v
    }

    fun detachView(v: WeChatScanView) {
        if (view === v) view = null
    }

    // ---------- 长焦枚举 ----------

    /** 物理镜头信息（逻辑多摄拆出来的那几颗） */
    private data class PhysicalLens(val id: String, val focals: List<Float>)

    /**
     * 枚举后置逻辑多摄里的物理相机，返回：
     * { cameras: [{id, focalLengths, isTelephoto}], telephotoId: 推荐长焦或 null }
     * 物理相机枚举要 API 30+（getPhysicalCameraIds），低版本直接返回空。
     */
    private fun queryLensInfo(): Map<String, Any?> {
        val cameras = ArrayList<Map<String, Any?>>()
        var telephotoId: String? = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val manager = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val physicals = ArrayList<PhysicalLens>()
            for (logicId in manager.cameraIdList) {
                val chars = manager.getCameraCharacteristics(logicId)
                if (chars.get(CameraCharacteristics.LENS_FACING) !=
                    CameraCharacteristics.LENS_FACING_BACK
                ) {
                    continue
                }
                val caps = chars.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)
                    ?: continue
                if (!caps.contains(
                        CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA
                    )
                ) {
                    continue
                }
                for (pid in chars.physicalCameraIds) {
                    try {
                        val pchars = manager.getCameraCharacteristics(pid)
                        val focals = pchars.get(
                            CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS,
                        )?.toList()
                        if (!focals.isNullOrEmpty()) {
                            physicals.add(PhysicalLens(pid, focals))
                        }
                    } catch (e: Exception) {
                        // 个别物理相机可能查不到参数，跳过
                    }
                }
            }
            // 同一物理相机可能挂在多个逻辑相机下，去重
            val seen = HashSet<String>()
            val unique = physicals.filter { seen.add(it.id) }
            val widest = unique.maxOfOrNull { it.focals.max() } ?: 0f
            val narrowest = unique.minOfOrNull { it.focals.min() } ?: 0f
            // 比主摄焦距明显更长的那颗当长焦（主摄约 4mm，2x 长焦约 6mm+）
            if (unique.isNotEmpty() && widest > narrowest * 1.25f) {
                telephotoId = unique.maxByOrNull { it.focals.max() }?.id
            }
            for (p in unique) {
                cameras.add(
                    mapOf(
                        "id" to p.id,
                        "focalLengths" to p.focals.map { it.toDouble() },
                        "isTelephoto" to (p.id == telephotoId),
                    ),
                )
            }
        }
        return mapOf("cameras" to cameras, "telephotoId" to telephotoId)
    }
}

/** PlatformView 工厂。 */
class WeChatScanViewFactory(
    private val plugin: WeChatScanPlugin,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return WeChatScanView(context, plugin)
    }
}
